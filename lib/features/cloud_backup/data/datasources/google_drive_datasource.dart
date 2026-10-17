// lib/features/cloud_backup/data/datasources/google_drive_datasource.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:googleapis/drive/v3.dart' as drive;

import '../../../../core/error/exceptions.dart';
import 'google_auth_datasource.dart';

/// Name every uploaded backup file uses in Drive's `appDataFolder`.
/// Fixed (not timestamped) since there's only ever one cloud backup at
/// a time — a new backup replaces this one rather than creating a
/// second file with a different name.
const String _kCloudBackupFileName = 'bubimo_cloud_backup.bubimo';

/// How much room the signed-in Google account has left in Drive.
/// Storage is shared with Gmail and Google Photos, and files in
/// `appDataFolder` count toward it too.
class DriveStorageQuota {
  final int limitBytes;
  final int usageBytes;

  const DriveStorageQuota({
    required this.limitBytes,
    required this.usageBytes,
  });

  int get freeBytes => limitBytes - usageBytes;
}

/// Raw Google Drive `appDataFolder` access for cloud backup.
///
/// Much simpler than a general-purpose Drive integration would be,
/// because there is exactly ONE file this app ever reads or writes:
/// the single `.bubimo` archive `CloudBackupRepositoryImpl` builds via
/// `BackupLocalDataSource.buildBackupArchive()`.
///
/// No error-wrapping here beyond mapping Drive's own error shape into
/// this app's exception types — `CloudBackupRepositoryImpl` converts
/// those into `Failure`s, matching every other data source in this
/// app.
class GoogleDriveDataSource {
  final GoogleAuthDataSource authDataSource;
  const GoogleDriveDataSource(this.authDataSource);

  static const String _appDataFolder = 'appDataFolder';

  Future<drive.DriveApi> _api() async {
    final client = await authDataSource.authClient();
    return drive.DriveApi(client);
  }

  /// Every backup file currently in `appDataFolder`, newest first.
  /// Normally zero or one; more than one only if an earlier upload
  /// left a stray copy behind.
  Future<List<drive.File>> listBackupFiles() {
    return _run(() async {
      final api = await _api();
      final result = await api.files.list(
        spaces: _appDataFolder,
        q: "name = '$_kCloudBackupFileName'",
        orderBy: 'createdTime desc',
        $fields: 'files(id,name,size,createdTime,appProperties)',
        pageSize: 10,
      );
      return result.files ?? const <drive.File>[];
    });
  }

  /// Finds the current cloud backup file, if one exists. Returns null
  /// if none is present (first backup ever, or previously deleted).
  Future<drive.File?> findCurrentBackupFile() async {
    final files = await listBackupFiles();
    return files.isEmpty ? null : files.first;
  }

  /// Free space left on the signed-in account, or `null` when it can't
  /// be determined or the account has no storage limit (some Google
  /// Workspace accounts). Never throws for a plain Drive error — this
  /// is only a courtesy pre-check, and the upload itself reports a
  /// full Drive as [CloudStorageFullException] if the check was wrong
  /// or unavailable.
  Future<DriveStorageQuota?> getStorageQuota() async {
    try {
      return await _run(() async {
        final api = await _api();
        final about = await api.about.get($fields: 'storageQuota');
        final quota = about.storageQuota;
        if (quota == null) return null;

        final limit = int.tryParse(quota.limit ?? '');
        if (limit == null) return null; // unlimited
        final usage = int.tryParse(quota.usage ?? '') ?? 0;
        return DriveStorageQuota(limitBytes: limit, usageBytes: usage);
      });
    } on CloudBackupException {
      return null;
    }
  }

  /// Uploads [bytes] as the cloud backup file, tagging it with
  /// [appProperties] (createdAt/entryCount) so the caller can show
  /// metadata without downloading and unzipping the whole archive.
  ///
  /// When [existingFileId] is given, that file's content is REPLACED in
  /// place instead of deleting it and creating a new one. This matters
  /// when the upload fails (Drive full, connection drops): the
  /// previous backup is still there, untouched, instead of having been
  /// deleted first and lost.
  Future<drive.File> uploadBackup({
    required Uint8List bytes,
    required Map<String, String> appProperties,
    String? existingFileId,
  }) {
    return _run(() async {
      final api = await _api();
      final media = drive.Media(
        Stream.value(bytes),
        bytes.length,
        contentType: 'application/zip',
      );

      if (existingFileId != null) {
        final update = drive.File()..appProperties = appProperties;
        return api.files.update(
          update,
          existingFileId,
          uploadMedia: media,
          $fields: 'id,name,size,createdTime,appProperties',
        );
      }

      final fileMeta = drive.File()
        ..name = _kCloudBackupFileName
        ..parents = [_appDataFolder]
        ..appProperties = appProperties;

      return api.files.create(
        fileMeta,
        uploadMedia: media,
        $fields: 'id,name,size,createdTime,appProperties',
      );
    });
  }

  Future<Uint8List> downloadBackup(String driveFileId) {
    return _run(() async {
      final api = await _api();
      final media =
          await api.files.get(
                driveFileId,
                downloadOptions: drive.DownloadOptions.fullMedia,
              )
              as drive.Media;

      final chunks = <int>[];
      await for (final chunk in media.stream) {
        chunks.addAll(chunk);
      }
      return Uint8List.fromList(chunks);
    });
  }

  Future<void> deleteFile(String driveFileId) {
    return _run(() async {
      final api = await _api();
      await api.files.delete(driveFileId);
    });
  }

  // ── Error handling ────────────────────────────────────────────────

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on drive.DetailedApiRequestError catch (e) {
      throw _mapDriveError(e);
    } on AuthExpiredException {
      rethrow;
    } on AuthException {
      rethrow;
    } on AuthCancelledException {
      rethrow;
    } on SocketException {
      throw const CloudBackupException(
        message: 'No internet connection.',
      );
    } on TimeoutException {
      throw const CloudBackupException(
        message: 'The request to Google Drive timed out.',
      );
    } catch (e) {
      throw CloudBackupException(message: 'Unexpected Drive error: $e');
    }
  }

  Exception _mapDriveError(drive.DetailedApiRequestError e) {
    final status = e.status;
    final reason = (e.errors.isNotEmpty ? e.errors.first.reason : null) ?? '';
    final message = (e.message ?? '').toLowerCase();

    if (status == 401) {
      return const AuthExpiredException(message: 'Drive session expired.');
    }
    if (status == 403) {
      if (reason == 'storageQuotaExceeded' ||
          message.contains('storage quota')) {
        return const CloudStorageFullException(
          message:
              'There isn\'t enough free space in this Google Drive. Free '
              'up space in Google Drive, or use a different Google '
              'account.',
        );
      }
      switch (reason) {
        case 'rateLimitExceeded':
        case 'userRateLimitExceeded':
          return const CloudBackupException(
            message: 'Too many requests. Please try again shortly.',
          );
        case 'domainPolicy':
          return const CloudBackupException(
            message: 'Your organization has blocked Drive access.',
          );
        default:
          return CloudBackupException(
            message: 'Drive denied the request: $reason',
          );
      }
    }
    if (status != null && status >= 500) {
      return CloudBackupException(message: 'Drive server error ($status).');
    }
    return CloudBackupException(message: 'Drive error ($status): ${e.message}');
  }
}