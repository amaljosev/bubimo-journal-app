// lib/features/backup/data/datasources/backup_local_data_source.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../../../../core/error/exceptions.dart';
import '../../../../core/storage/media_storage_service.dart';
import '../../../../core/utils/downloads_directory_resolver.dart';
import '../../../../core/utils/id_generator.dart';
import '../../../diary_entry/data/datasources/diary_local_data_source.dart';
import '../../../diary_entry/data/models/diary_entry_model.dart';
import '../../../diary_entry/domain/entities/diary_entry.dart';
import '../../domain/entities/backup_manifest.dart';
import '../../domain/entities/export_result.dart';
import '../../domain/entities/import_result.dart';
import '../models/backup_diary_entry_model.dart';

/// Format version of the `.bubimo` bundle this app build writes and can
/// read. See [BackupManifest.formatVersion]'s doc comment — this is
/// independent of the app's own version number and the DB schema
/// version.
const int kBackupFormatVersion = 1;

/// File extension used for exported bundles. A `.bubimo` file is a
/// plain zip archive underneath — the custom extension exists purely
/// so the file is recognizable to the user and doesn't invite the OS
/// file manager to offer "extract" the way a bare `.zip` would.
const String kBackupFileExtension = '.bubimo';

/// Mirrors pubspec.yaml's `version:` field (currently `1.0.0+1`, minus
/// the build-number suffix). Shown in [BackupManifest.appVersion] for
/// the user's own reference only — see [BackupLocalDataSource
/// ._resolveAppVersion]'s doc comment for why this isn't read via a
/// runtime plugin instead. Update this alongside pubspec.yaml when
/// bumping the app version.
const String _kAppVersionForBackupManifest = '1.0.0';

/// Result of [BackupLocalDataSource.buildBackupArchive] — the built
/// zip's raw bytes plus the entry count, so a caller (local export,
/// cloud backup) can report the count without re-parsing the archive
/// just to find out how many entries it holds.
class BackupArchive {
  final Uint8List bytes;
  final int entryCount;

  const BackupArchive({required this.bytes, required this.entryCount});
}

/// Raw file-system and archive access for creating and applying
/// `.bubimo` backup bundles. No error-wrapping here — exceptions
/// propagate up to `BackupRepositoryImpl`, matching every other data
/// source in this app (see [DiaryLocalDataSource]'s own doc comment).
///
/// # What's in a bundle
/// A `.bubimo` file is a zip containing:
///  - `manifest.json` — see [BackupManifest]
///  - `data/diary_entries.json` — a JSON array, one object per
///    non-deleted diary entry, written via [BackupDiaryEntryModel]
///  - `media/...` — every file actually referenced by an exported
///    entry's path fields, saved under its known category folder (e.g.
///    `media/diary_images/0_xyz.jpg`) regardless of where the file
///    physically lives on the exporting device — see
///    [_rewriteEntryPathsForExport]'s doc comment for why this matters.
///
/// # Why every path is rewritten
/// An entry's `imagePath`/`overlayImages[].path`/etc. are, on the
/// exporting device, absolute paths like
/// `/data/user/0/com.x.bubimo/app_flutter/media/diary_images/xyz.jpg`.
/// That exact string means nothing on a different device, or even on
/// the same device after a fresh install — the app-private root
/// changes. So on export, every path is rewritten to a bundle-relative
/// form before being written into `data/diary_entries.json`; on import,
/// every bundle-relative path is resolved back into a fresh absolute
/// path on THIS install via [MediaStorageService.saveBytes], and only
/// that fresh path is ever written to the database. See
/// `media_storage_service.dart`'s doc comment for why a raw picker/
/// gallery path was never safe to store in the first place — this is
/// the same principle applied to backup/restore specifically.
///
/// # Why imports always create new entries
/// Every entry in an imported bundle gets a freshly generated id via
/// [IdGenerator.generate] — the id stored in the bundle itself is never
/// reused. This guarantees importing a bundle can never overwrite or
/// silently merge with anything already in the local database,
/// regardless of whether the bundle came from this exact device, a
/// different device, or an old backup of this same device from before
/// data was later edited or deleted.
class BackupLocalDataSource {
  final DiaryLocalDataSource diaryLocalDataSource;
  final MediaStorageService mediaStorageService;

  const BackupLocalDataSource({
    required this.diaryLocalDataSource,
    required this.mediaStorageService,
  });

  // ── Export ────────────────────────────────────────────────────────

  /// Creates a `.bubimo` bundle of every non-deleted diary entry and
  /// saves it to disk. Returns the saved file's absolute path, the
  /// number of entries included, the file's size in bytes, and whether
  /// it landed in the public Downloads directory (vs. an app-private
  /// fallback — see [resolveDownloadsDirectory]'s doc comment).
  /// Builds the exact same zip archive [createBackup] writes to disk —
  /// manifest, entry JSON, and every referenced media file — but
  /// returns it as bytes instead of writing anywhere. This is the
  /// shared step cloud backup (a separate feature) reuses so it never
  /// needs its own copy of the entry/media serialization logic; it
  /// only needs to decide where the resulting bytes go (Drive, in that
  /// case, instead of the Downloads folder).
  Future<BackupArchive> buildBackupArchive() async {
    final entries = await diaryLocalDataSource.getAllEntries();

    final archive = Archive();
    // Dedupes by SOURCE absolute path (not by where it lives on disk) —
    // if the same file is referenced twice, it's only read and zipped
    // once. Also tracks a per-category counter so every bundled file
    // gets a unique, collision-free name inside its category folder,
    // regardless of what its original filename was.
    final pathToBundlePath = <String, String>{};
    final categoryCounters = <MediaCategory, int>{};

    final entryJsonList = <Map<String, dynamic>>[];

    for (final entry in entries) {
      final rewritten = await _rewriteEntryPathsForExport(
        entry: entry,
        archive: archive,
        pathToBundlePath: pathToBundlePath,
        categoryCounters: categoryCounters,
      );
      entryJsonList.add(rewritten);
    }

    final manifest = BackupManifest(
      formatVersion: kBackupFormatVersion,
      exportedAt: DateTime.now(),
      appVersion: await _resolveAppVersion(),
      entryCount: entries.length,
    );

    archive.addFile(
      ArchiveFile.string('manifest.json', jsonEncode(manifest.toJson())),
    );
    archive.addFile(
      ArchiveFile.string(
        'data/diary_entries.json',
        jsonEncode(entryJsonList),
      ),
    );

    final zipBytes = ZipEncoder().encode(archive);
    return BackupArchive(
      bytes: Uint8List.fromList(zipBytes),
      entryCount: entries.length,
    );
  }

  Future<ExportResult> createBackup() async {
    final built = await buildBackupArchive();

    final fileName = _generateExportFileName();
    final (filePath, savedToPublicDownloads) = await saveToDownloads(
      bytes: built.bytes,
      fileName: fileName,
      // A `.bubimo` file is a plain zip archive underneath — see this
      // class's doc comment on kBackupFileExtension.
      allowedExtensions: [kBackupFileExtension.replaceFirst('.', '')],
      dialogTitle: 'Save backup',
    );

    return ExportResult(
      filePath: filePath,
      entryCount: built.entryCount,
      fileSizeBytes: built.bytes.length,
      savedToPublicDownloads: savedToPublicDownloads,
    );
  }

  /// Builds the export JSON for one entry, adding any media files it
  /// references into [archive] and rewriting its path fields to
  /// bundle-relative form in the returned JSON map.
  ///
  /// Each field's [MediaCategory] is known explicitly (not derived from
  /// where the file happens to sit on disk) — this is what makes export
  /// correct for a file that predates this app's [MediaStorageService]
  /// fix (e.g. an old gallery-picked overlay photo or background whose
  /// path lives outside `MediaStorageService.mediaRoot`, such as an
  /// OS/gallery cache path from before every picker routed through
  /// `MediaStorageService`). The previous implementation computed each
  /// file's bundle path as its path *relative to `mediaRoot`* — for any
  /// file NOT actually under that root, that produced a path containing
  /// `..` segments, which import's category-folder lookup
  /// ([_categoryFromBundlePath]) couldn't recognize, silently dropping
  /// that one image/sticker on restore. Bundling strictly by the field's
  /// known category instead means export/import work correctly
  /// regardless of where the source file physically lives, as long as
  /// it still exists on disk at all.
  Future<Map<String, dynamic>> _rewriteEntryPathsForExport({
    required DiaryEntry entry,
    required Archive archive,
    required Map<String, String> pathToBundlePath,
    required Map<MediaCategory, int> categoryCounters,
  }) async {
    Future<String?> rewriteAndBundle(
      String? absolutePath,
      MediaCategory category,
    ) async {
      if (absolutePath == null || absolutePath.isEmpty) return null;

      final cached = pathToBundlePath[absolutePath];
      if (cached != null) return cached;

      final file = File(absolutePath);
      if (!await file.exists()) {
        // The file this entry references is genuinely gone from disk
        // (deleted outside the app, or lost some other way) — nothing
        // to recover. Skip bundling it and drop the reference for this
        // export rather than failing the whole export over one missing
        // file.
        return null;
      }

      final index = categoryCounters[category] ?? 0;
      categoryCounters[category] = index + 1;
      final extension = p.extension(absolutePath);
      final baseName = p.basenameWithoutExtension(absolutePath);
      final bundlePath = 'media/${category.folderName}/${index}_$baseName$extension';

      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile(bundlePath, bytes.length, bytes));
      pathToBundlePath[absolutePath] = bundlePath;

      return bundlePath;
    }

    final json = BackupDiaryEntryModel.toJson(entry);

    json['imagePath'] = await rewriteAndBundle(
      entry.imagePath,
      MediaCategory.diaryImages,
    );
    json['bgGalleryImagePath'] = await rewriteAndBundle(
      entry.bgGalleryImagePath,
      MediaCategory.diaryBackgrounds,
    );
    json['bgLocalPath'] = await rewriteAndBundle(
      entry.bgLocalPath,
      MediaCategory.downloadedBackgrounds,
    );
    // bgImagePath is a bundled app asset path, not app-owned media — no
    // rewriting needed. See BackupDiaryEntryModel.fromJson's matching
    // note on the import side for the full rationale/caveat.

    final rewrittenImages = <String>[];
    for (final imagePath in entry.images) {
      final rewritten = await rewriteAndBundle(
        imagePath,
        MediaCategory.diaryImages,
      );
      if (rewritten != null) rewrittenImages.add(rewritten);
    }
    json['images'] = rewrittenImages;

    final rewrittenOverlayImages = <Map<String, dynamic>>[];
    for (final overlayImage in entry.overlayImages) {
      final rewritten = await rewriteAndBundle(
        overlayImage.path,
        MediaCategory.diaryImages,
      );
      if (rewritten == null) continue; // source file gone — drop it
      rewrittenOverlayImages.add({
        ...overlayImage.toJson(),
        'path': rewritten,
      });
    }
    json['overlayImages'] = rewrittenOverlayImages;

    final rewrittenStickers = <Map<String, dynamic>>[];
    for (final sticker in entry.stickers) {
      final rewrittenLocalPath = await rewriteAndBundle(
        sticker.localPath,
        MediaCategory.stickers,
      );
      rewrittenStickers.add({
        ...sticker.toJson(),
        // Unlike overlay images, a sticker with no local file isn't
        // dropped — it still has its recovery `url`, so the imported

        // copy can simply re-download it (same as
        // EditableStickerOverlay already falls back to a placeholder +
        // DiaryFormBloc's existing recovery path for a missing
        // localPath today).
        'localPath': rewrittenLocalPath,
      });
    }
    json['stickers'] = rewrittenStickers;

    // Inline images embedded directly in the Quill Delta JSON (not
    // just referenced via the denormalized `entry.images` list) need
    // the exact same bundling as every other media path — otherwise an
    // inline image renders fine right up until the entry is backed up
    // and restored, since the embed itself would still point at this
    // device's now-gone directory. See
    // BackupDiaryEntryModel.extractContentImagePaths's doc comment.
    final rawContent = entry.content;
    if (rawContent != null && rawContent.isNotEmpty) {
      final embeddedPaths =
          BackupDiaryEntryModel.extractContentImagePaths(rawContent);
      final contentPathRewrites = <String, String>{};
      for (final embeddedPath in embeddedPaths) {
        final rewritten = await rewriteAndBundle(
          embeddedPath,
          MediaCategory.diaryImages,
        );
        // If the file's gone, rewriteAndBundle returns null and this
        // path is simply left out of the rewrite map — the embed keeps
        // its original (now-broken) path, same "can't recover a
        // deleted file" outcome as every other field above.
        if (rewritten != null) contentPathRewrites[embeddedPath] = rewritten;
      }
      json['content'] = BackupDiaryEntryModel.rewriteContentImagePaths(
        rawContent,
        contentPathRewrites,
      );
    }

    return json;
  }

  // ── Import ────────────────────────────────────────────────────────

  /// Reads, validates, and applies the `.bubimo` bundle at [filePath].
  ///
  /// Throws [ImportExportException] if the manifest is missing,
  /// unreadable, or declares a [BackupManifest.formatVersion] this app
  /// build doesn't know how to read — this check happens BEFORE any
  /// entry data is parsed or any database write occurs, so an
  /// incompatible/corrupt file is rejected cleanly with no partial
  /// state change.
  Future<ImportResult> importBackup(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    return importBackupFromBytes(bytes);
  }

  /// Same as [importBackup], but takes the archive's bytes directly
  /// rather than reading them from a local file path — used by cloud
  /// backup's restore flow, which downloads the bytes from Drive and
  /// has no local file to point [importBackup] at. Every validation
  /// and media-resolution step is identical either way; only where the
  /// bytes originally came from differs.
  Future<ImportResult> importBackupFromBytes(List<int> bytes) async {
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (e) {
      throw ImportExportException(
        message: 'This file isn\'t a valid backup archive: $e',
      );
    }

    final manifestFile = archive.findFile('manifest.json');
    if (manifestFile == null) {
      throw const ImportExportException(
        message: 'This file is missing its manifest and can\'t be read '
            'as a backup.',
      );
    }

    final BackupManifest manifest;
    try {
      final manifestJson = jsonDecode(
        utf8.decode(manifestFile.content as List<int>),
      );
      manifest = BackupManifest.fromJson(manifestJson as Map<String, dynamic>);
    } on FormatException catch (e) {
      throw ImportExportException(
        message: 'This backup\'s manifest is invalid: ${e.message}',
      );
    }

    if (manifest.formatVersion > kBackupFormatVersion) {
      throw ImportExportException(
        message:
            'This backup was created by a newer version of the app '
            '(format version ${manifest.formatVersion}) and can\'t be '
            'read by this version. Please update the app and try again.',
      );
    }

    final entriesFile = archive.findFile('data/diary_entries.json');
    if (entriesFile == null) {
      throw const ImportExportException(
        message: 'This backup is missing its diary entry data.',
      );
    }

    final rawEntries = jsonDecode(
      utf8.decode(entriesFile.content as List<int>),
    );
    if (rawEntries is! List) {
      throw const ImportExportException(
        message: 'This backup\'s diary entry data is malformed.',
      );
    }

    var importedCount = 0;
    var skippedCount = 0;

    for (final rawEntry in rawEntries) {
      if (rawEntry is! Map<String, dynamic>) {
        skippedCount++;
        continue;
      }

      try {
        final resolvedPaths = await _resolveEntryMediaForImport(
          rawEntry: rawEntry,
          archive: archive,
        );

        final entry = BackupDiaryEntryModel.fromJson(
          rawEntry,
          newId: IdGenerator.generate(),
          resolvedPaths: resolvedPaths,
        );

        await diaryLocalDataSource.insertEntry(
          DiaryEntryModel.fromEntity(entry),
        );
        importedCount++;
      } catch (_) {
        // One malformed/unresolvable entry doesn't fail the whole
        // import — same per-record fault isolation used throughout
        // this codebase (see DiaryEntryModel's decode helpers).
        skippedCount++;
      }
    }

    return ImportResult(
      importedCount: importedCount,
      skippedCount: skippedCount,
    );
  }

  /// For one raw entry record, finds every relative media path it
  /// references, copies that file's bytes out of [archive] into this
  /// device's real media directory via [MediaStorageService.saveBytes],
  /// and returns a map from the original bundle-relative path to the
  /// fresh absolute path it now lives at.
  ///
  /// Done as a separate pass BEFORE [BackupDiaryEntryModel.fromJson]
  /// parses the entry, since resolving a path requires an async file
  /// write that a synchronous JSON-parsing step shouldn't perform
  /// itself — mirrors the same separation-of-concerns reasoning as
  /// [DiaryEntryModel.fromMap] doing pure parsing while
  /// [DiaryLocalDataSource] handles all I/O.
  Future<Map<String, String>> _resolveEntryMediaForImport({
    required Map<String, dynamic> rawEntry,
    required Archive archive,
  }) async {
    final resolved = <String, String>{};

    Future<void> resolveOne(String? bundlePath) async {
      if (bundlePath == null || bundlePath.isEmpty) return;
      if (resolved.containsKey(bundlePath)) return; // already resolved

      final archiveFile = archive.findFile(bundlePath);
      if (archiveFile == null) {
        // Referenced but not actually present in the bundle (e.g. the
        // source file was already missing at export time — see
        // _rewriteEntryPathsForExport's matching check). Leave
        // unresolved; BackupDiaryEntryModel.fromJson's resolvePath will
        // throw for this one field, which is caught per-record.
        return;
      }

      final category = _categoryFromBundlePath(bundlePath);
      if (category == null) return;

      final bytes = archiveFile.content as List<int>;
      final extension = p.extension(bundlePath);
      final savedPath = await mediaStorageService.saveBytes(
        Uint8List.fromList(bytes),
        category: category,
        extension: extension,
      );
      resolved[bundlePath] = savedPath;
    }

    await resolveOne(rawEntry['imagePath'] as String?);
    await resolveOne(rawEntry['bgGalleryImagePath'] as String?);
    await resolveOne(rawEntry['bgLocalPath'] as String?);

    final imagesRaw = rawEntry['images'];
    if (imagesRaw is List) {
      for (final item in imagesRaw) {
        if (item is String) await resolveOne(item);
      }
    }

    final overlayImagesRaw = rawEntry['overlayImages'];
    if (overlayImagesRaw is List) {
      for (final item in overlayImagesRaw) {
        if (item is Map<String, dynamic>) {
          await resolveOne(item['path'] as String?);
        }
      }
    }

    final stickersRaw = rawEntry['stickers'];
    if (stickersRaw is List) {
      for (final item in stickersRaw) {
        if (item is Map<String, dynamic>) {
          await resolveOne(item['localPath'] as String?);
        }
      }
    }

    // Inline images embedded directly in the entry's Quill Delta JSON
    // content — mirrors export's identical handling in
    // _rewriteEntryPathsForExport. These bundle-relative paths use the
    // same media/diary_images/... form as every other diaryImages
    // path, so _categoryFromBundlePath resolves them the same way.
    final rawContent = rawEntry['content'];
    if (rawContent is String && rawContent.isNotEmpty) {
      final embeddedPaths =
          BackupDiaryEntryModel.extractContentImagePaths(rawContent);
      for (final embeddedPath in embeddedPaths) {
        await resolveOne(embeddedPath);
      }
    }

    return resolved;
  }

  /// Maps a bundle-relative media path (e.g.
  /// `media/diary_images/xyz.jpg`) back to the [MediaCategory] it
  /// belongs in, so it can be saved into the correct folder on this
  /// device. Returns null for a path that doesn't match any known
  /// category folder (e.g. a foreign/corrupted bundle).
  MediaCategory? _categoryFromBundlePath(String bundlePath) {
    final segments = p.split(bundlePath);
    // Expected shape: media/<folderName>/<filename>, i.e. 3 segments.
    if (segments.length < 3 || segments.first != 'media') return null;
    final folderName = segments[1];

    for (final category in MediaCategory.values) {
      if (category.folderName == folderName) return category;
    }
    return null;
  }

  // ── Shared helpers ────────────────────────────────────────────────

  Future<String> _resolveAppVersion() async {
    // Deliberately NOT using a plugin (e.g. package_info_plus) to read
    // this at runtime — appVersion is purely informational (see
    // BackupManifest's doc comment: it's shown to the user for their
    // own reference and never used for any compatibility decision), so
    // pulling in an entire additional native-platform-channel
    // dependency just to populate a display string isn't worth it.
    // Update this constant alongside pubspec.yaml's own `version:`
    // field when bumping the app version.
    return _kAppVersionForBackupManifest;
  }

  String _generateExportFileName() {
    final now = DateTime.now();
    final datePart =
        '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}'
        '_${_twoDigits(now.hour)}${_twoDigits(now.minute)}';
    return 'bubimo_backup_$datePart$kBackupFileExtension';
  }

  String _twoDigits(int value) => value.toString().padLeft(2, '0');
}