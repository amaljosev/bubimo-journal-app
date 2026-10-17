// lib/features/cloud_backup/data/repositories/cloud_backup_repository_impl.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../../backup/data/datasources/backup_local_data_source.dart';
import '../../domain/entities/cloud_backup_metadata.dart';
import '../../domain/repositories/cloud_backup_repository.dart';
import '../datasources/cloud_backup_local_datasource.dart';
import '../datasources/google_auth_datasource.dart';
import '../datasources/google_drive_datasource.dart';
import '../models/cloud_backup_manifest_model.dart';

/// Implements [CloudBackupRepository] on top of Google Drive.
///
/// Deliberately reuses [BackupLocalDataSource] — the SAME code that
/// builds and applies local `.bubimo` files — for every bit of entry/
/// media serialization: [BackupLocalDataSource.buildBackupArchive] to
/// build the zip bytes uploaded to Drive, and
/// [BackupLocalDataSource.importBackupFromBytes] to apply a downloaded
/// one. This is a deliberate departure from a from-scratch cloud
/// implementation: every hard-won detail of that logic (rewriting
/// picked/downloaded media paths into the bundle, resolving them back
/// into this device's real `MediaStorageService` folders on restore,
/// per-record fault isolation) only needs to exist once, regardless of
/// whether the resulting bytes end up in the Downloads folder or in
/// Drive's `appDataFolder`.
///
/// SINGLE-SNAPSHOT POLICY: there is only ever one cloud backup at a
/// time. [backUpToCloud] deletes whatever was there before uploading a
/// fresh one — this app never accumulates a history of cloud backups,
/// matching the same policy the local export screen already
/// communicates to the user for `.bubimo` files ("this file is only
/// for restoring your diary, not a version history").
class CloudBackupRepositoryImpl implements CloudBackupRepository {
  final GoogleAuthDataSource authDataSource;
  final GoogleDriveDataSource driveDataSource;
  final BackupLocalDataSource backupLocalDataSource;
  final CloudBackupLocalDataSource localDataSource;
  final NetworkInfo networkInfo;

  const CloudBackupRepositoryImpl({
    required this.authDataSource,
    required this.driveDataSource,
    required this.backupLocalDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  /// Throws [NoInternetException] if there's no real internet access
  /// right now. Called at the top of every method here that talks to
  /// Google (sign-in, Drive reads/writes) — NOT [restoreSession],
  /// which must stay reachable offline so a previously-linked account
  /// still shows as signed in while offline (see its own doc comment).
  ///
  /// This exists as defense-in-depth alongside the presentation-layer
  /// gate ([CloudBackupGate]/`no_internet_page.dart`) that keeps the
  /// user from reaching this screen at all while offline: that gate
  /// only checks once, on navigation, so it can't catch the connection
  /// dropping mid-operation (e.g. mid-upload) — this check catches
  /// that case and produces the same [NoInternetFailure] either way.
  Future<void> _requireInternet() async {
    if (!await networkInfo.isConnected) {
      throw const NoInternetException();
    }
  }

  // ── Auth ──────────────────────────────────────────────────────────

  /// "12.4 MB", "830 KB", "1.2 GB" — for the not-enough-space message.
  String _formatBytes(int bytes) {
    if (bytes < 1024 * 1024) {
      final kb = bytes <= 0 ? 0 : (bytes / 1024).ceil();
      return '$kb KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  @override
  Future<Either<Failure, String>> signIn() async {
    try {
      await _requireInternet();
      await authDataSource.signIn();
      final email = authDataSource.currentAccountEmail;
      if (email != null) {
        await localDataSource.saveEmail(email);
      }
      return Right(email ?? '');
    } on NoInternetException catch (e) {
      return Left(NoInternetFailure(e.message));
    } on AuthCancelledException catch (e) {
      return Left(AuthCancelledFailure(e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(AuthFailure('Sign-in failed: $e'));
    }
  }

  @override
  Future<Either<Failure, String?>> restoreSession() async {
    final savedEmail = await localDataSource.getSavedEmail();
    if (savedEmail == null) {
      // Nothing was ever linked (or the user explicitly signed out) —
      // deliberately never touches the native Google sign-in APIs in
      // this case, which is what stops the app from attempting a
      // sign-in on every single visit to the Cloud Backup screen.
      return const Right(null);
    }

    try {
      final wasSignedIn = await authDataSource.signInSilently();
      if (!wasSignedIn) {
        // The saved marker is stale — Google no longer recognizes an
        // active session (e.g. access was revoked elsewhere). Clear it
        // so future visits go straight to the sign-in button instead
        // of repeating this failed check.
        await localDataSource.clear();
        return const Right(null);
      }
      return Right(savedEmail);
    } catch (_) {
      // Couldn't confirm right now (e.g. offline) — don't erase the
      // saved account over what may just be a transient/network
      // problem; treat the session as still valid for this visit.
      return Right(savedEmail);
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await _requireInternet();
      await authDataSource.signOut();
      await localDataSource.clear();
      return const Right(null);
    } on NoInternetException catch (e) {
      return Left(NoInternetFailure(e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } catch (e) {
      return Left(AuthFailure('Sign-out failed: $e'));
    }
  }

  // ── Backup ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, CloudBackupMetadata>> backUpToCloud({
    CloudBackupProgressCallback? onProgress,
  }) async {
    try {
      await _requireInternet();
      onProgress?.call(CloudBackupPhase.buildingArchive);
      final archive = await backupLocalDataSource.buildBackupArchive();

      // Enforce the single-snapshot policy WITHOUT ever deleting the old
      // backup before the new one is safely uploaded: the existing
      // file's content is replaced in place, so if the upload fails
      // (Drive full, connection drops) the previous backup is still
      // there instead of having been deleted first and lost.
      final existingFiles = await driveDataSource.listBackupFiles();
      final existing = existingFiles.isEmpty ? null : existingFiles.first;
      final existingId = existing?.id;
      final existingSize = int.tryParse(existing?.size ?? '') ?? 0;

      // Courtesy pre-check so a full Drive is reported immediately, with
      // real numbers, instead of after a long failed upload. The old
      // backup's size is credited since it is being replaced. Skipped
      // silently when the quota can't be read or the account is
      // unlimited — the upload itself still reports a full Drive.
      final quota = await driveDataSource.getStorageQuota();
      if (quota != null) {
        final extraNeeded = archive.bytes.length - existingSize;
        final free = quota.freeBytes < 0 ? 0 : quota.freeBytes;
        if (extraNeeded > free) {
          throw CloudStorageFullException(
            message:
                'There isn\'t enough free space in this Google Drive. Your '
                'backup needs about ${_formatBytes(extraNeeded)} more, and '
                'only ${_formatBytes(free)} is free. Free up space in '
                'Google Drive, or use a different Google account.',
          );
        }
      }

      onProgress?.call(CloudBackupPhase.uploading);
      final now = DateTime.now().toUtc();
      final uploaded = await driveDataSource.uploadBackup(
        bytes: archive.bytes,
        appProperties: CloudBackupManifestModel.toAppProperties(
          createdAt: now,
          entryCount: archive.entryCount,
        ),
        existingFileId: existingId,
      );

      // Best effort: remove any stray extra copies an older upload may
      // have left behind. Failing here never fails the backup.
      for (final extra in existingFiles.skip(1)) {
        final extraId = extra.id;
        if (extraId == null || extraId == uploaded.id) continue;
        try {
          await driveDataSource.deleteFile(extraId);
        } catch (_) {}
      }

      return Right(CloudBackupManifestModel.fromDriveFile(uploaded));
    } on NoInternetException catch (e) {
      return Left(NoInternetFailure(e.message));
    } on AuthExpiredException catch (e) {
      return Left(AuthExpiredFailure(e.message));
    } on AuthCancelledException catch (e) {
      return Left(AuthCancelledFailure(e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on CloudBackupException catch (e) {
      return Left(CloudBackupFailure(e.message));
    } on CloudStorageFullException catch (e) {
      return Left(CloudStorageFullFailure(e.message));
    } on MediaStorageException catch (e) {
      return Left(MediaStorageFailure(e.message));
    } catch (e) {
      return Left(CloudBackupFailure('Backup failed: $e'));
    }
  }

  @override
  Future<Either<Failure, CloudBackupMetadata?>> getCloudBackupStatus() async {
    try {
      await _requireInternet();
      final file = await driveDataSource.findCurrentBackupFile();
      if (file == null) return const Right(null);
      return Right(CloudBackupManifestModel.fromDriveFile(file));
    } on NoInternetException catch (e) {
      return Left(NoInternetFailure(e.message));
    } on AuthExpiredException catch (e) {
      return Left(AuthExpiredFailure(e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on CloudBackupException catch (e) {
      return Left(CloudBackupFailure(e.message));
    } catch (e) {
      return Left(CloudBackupFailure('Failed to check cloud backup: $e'));
    }
  }

  // ── Restore ───────────────────────────────────────────────────────

  @override
  Future<Either<Failure, int>> restoreFromCloud({
    CloudBackupProgressCallback? onProgress,
  }) async {
    try {
      await _requireInternet();
      final file = await driveDataSource.findCurrentBackupFile();
      final fileId = file?.id;
      if (fileId == null) {
        return const Left(
          CloudBackupFailure('No cloud backup was found for this account.'),
        );
      }

      onProgress?.call(CloudBackupPhase.downloading);
      final bytes = await driveDataSource.downloadBackup(fileId);

      onProgress?.call(CloudBackupPhase.restoring);
      final result = await backupLocalDataSource.importBackupFromBytes(bytes);

      return Right(result.importedCount);
    } on NoInternetException catch (e) {
      return Left(NoInternetFailure(e.message));
    } on AuthExpiredException catch (e) {
      return Left(AuthExpiredFailure(e.message));
    } on AuthCancelledException catch (e) {
      return Left(AuthCancelledFailure(e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on CloudBackupException catch (e) {
      return Left(CloudBackupFailure(e.message));
    } on ImportExportException catch (e) {
      return Left(ImportExportFailure(e.message));
    } on MediaStorageException catch (e) {
      return Left(MediaStorageFailure(e.message));
    } catch (e) {
      return Left(CloudBackupFailure('Restore failed: $e'));
    }
  }

  // ── Delete ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> deleteCloudBackup() async {
    try {
      await _requireInternet();
      final file = await driveDataSource.findCurrentBackupFile();
      final fileId = file?.id;
      if (fileId == null) return const Right(null); // nothing to delete
      await driveDataSource.deleteFile(fileId);
      return const Right(null);
    } on NoInternetException catch (e) {
      return Left(NoInternetFailure(e.message));
    } on AuthExpiredException catch (e) {
      return Left(AuthExpiredFailure(e.message));
    } on AuthException catch (e) {
      return Left(AuthFailure(e.message));
    } on CloudBackupException catch (e) {
      return Left(CloudBackupFailure(e.message));
    } catch (e) {
      return Left(CloudBackupFailure('Failed to delete cloud backup: $e'));
    }
  }
}