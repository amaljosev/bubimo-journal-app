// lib/core/storage/media_storage_service.dart

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../error/exceptions.dart';

/// Subfolder under the app's media root that a given file belongs to.
///
/// Kept as an enum (rather than a raw string) so every call site is
/// forced to pick from a known, deliberate set of folders — the same
/// reasoning as [DiaryEntriesTable]'s column-name constants: a typo in
/// a raw folder-name string would silently create a stray directory
/// instead of failing to compile.
enum MediaCategory {
  /// Gallery/camera photos inserted inline as Quill embeds, and
  /// free-floating [OverlayImage]s — both come from `image_picker`, so
  /// they share a folder rather than needing two near-identical ones.
  diaryImages,

  /// Diary entry background images picked from the user's own gallery
  /// (`bgGalleryImagePath`) — kept separate from [diaryImages] since a
  /// background is conceptually one-per-entry and it's useful to be
  /// able to look at this folder and see "just backgrounds".
  diaryBackgrounds,

  /// Remote background presets downloaded from Supabase and cached
  /// locally (`bgLocalPath`) — separate from [diaryBackgrounds] so a
  /// user-picked background is never confused with a downloaded preset
  /// when reasoning about storage.
  downloadedBackgrounds,

  /// Sticker library images downloaded from Supabase Storage. Mirrors
  /// the folder [SupabaseStickerDataSource] already writes to today
  /// (`<app_docs>/stickers/`) — see the migration note on
  /// [MediaStorageService.mediaRoot] before changing this mapping.
  stickers,

  /// User profile avatar photo.
  profileAvatar,

  /// User profile header/cover photo.
  profileHeader,

  /// Custom theme header/preview images (theme feature's own picker).
  themeHeaders;

  /// Directory name on disk. Deliberately explicit per-case (not
  /// derived from [name]) so renaming an enum value here can never
  /// silently rename — and orphan the contents of — an existing
  /// on-device folder.
  String get folderName {
    switch (this) {
      case MediaCategory.diaryImages:
        return 'diary_images';
      case MediaCategory.diaryBackgrounds:
        return 'diary_backgrounds';
      case MediaCategory.downloadedBackgrounds:
        return 'downloaded_backgrounds';
      case MediaCategory.stickers:
        // Matches SupabaseStickerDataSource's existing `stickers/`
        // folder exactly (not `media/stickers/`) — see the doc note on
        // [MediaStorageService.mediaRoot].
        return 'stickers';
      case MediaCategory.profileAvatar:
        return 'profile_avatar';
      case MediaCategory.profileHeader:
        return 'profile_header';
      case MediaCategory.themeHeaders:
        return 'theme_headers';
    }
  }
}

/// Single, app-wide entry point for turning a picked file, a cropped
/// file, or a block of downloaded bytes into a **durable, app-owned**
/// file — and returning the path that's safe to store in the database.
///
/// # Why this exists
/// `image_picker` / `image_cropper` return a path into storage the app
/// does not own (OS media store, gallery cache, or a temp directory
/// depending on platform). That path is not a stable long-term
/// reference:
/// - the OS/gallery app can evict its own cache at any time, with no
///   relationship to whether *this* app is still running;
/// - if the user deletes the original photo from their gallery, some
///   picker implementations (particularly content-URI-based pickers on
///   newer Android) leave a dangling reference;
/// - the path is meaningless after a backup/restore onto a different
///   device — it never existed there.
///
/// Every feature that accepts a photo (diary entry images/backgrounds,
/// overlay images, profile avatar/header, theme headers) MUST call
/// [saveFile] (or [saveBytes], for anything that starts as raw bytes —
/// e.g. a network download) immediately after picking/cropping/
/// downloading, and store ONLY the path [saveFile]/[saveBytes] returns.
/// The original picker/cropper/download path is discarded once this
/// call returns — it must never reach a repository or the database.
///
/// This also directly enables two requirements: the app must work
/// fully offline (every background/sticker/photo the user has already
/// added is a local file under this app's own directory, never a
/// remote URL or a gallery reference that needs network/OS access to
/// resolve), and a future backup/restore feature can back up 100% of a
/// user's media by copying one directory tree
/// ([mediaRoot]) — it never needs to know about gallery URIs, content
/// providers, or per-feature storage quirks.
///
/// Registered as a lazy singleton in `injection.dart`, immediately
/// after `AppDatabase` — every feature's data source that touches
/// files depends on this the same way every feature's data source
/// depends on `AppDatabase` for rows.
class MediaStorageService {
  const MediaStorageService();


  /// Root directory all app-owned media lives under:
  /// `<ApplicationDocumentsDirectory>/media/`.
  ///
  /// Uses `getApplicationDocumentsDirectory()` — the same directory
  /// `SupabaseStickerDataSource` already uses for its sticker cache —
  /// rather than `getApplicationSupportDirectory()` (typically excluded
  /// from OS backups on both platforms) or `getTemporaryDirectory()`
  /// (can be purged by the OS at any time). Media the user has actually
  /// added to their diary needs to survive exactly the same lifecycle
  /// as the SQLite database itself.
  ///
  /// NOTE ON [MediaCategory.stickers]: today's sticker cache writes
  /// directly to `<app_docs>/stickers/`, one level above where every
  /// other category in this service lives (`<app_docs>/media/<category>/`).
  /// [MediaCategory.stickers]'s folder path is intentionally special-
  /// cased in [directoryFor] to point at that existing location rather
  /// than `<app_docs>/media/stickers/`, so this service can be adopted
  /// without a migration step for stickers that are already cached on a
  /// developer's test device. If you'd rather have every category
  /// genuinely live under one `media/` root (cleaner, but requires
  /// updating `SupabaseStickerDataSource` to write to the new path and,
  /// pre-launch, no old data to preserve so no migration needed), that's
  /// a one-line change — see [directoryFor]'s early-return branch.
  Future<Directory> mediaRoot() async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final root = Directory(p.join(appDocsDir.path, 'media'));
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  /// Returns the (created-if-needed) directory a given [category]'s
  /// files live in.
  Future<Directory> directoryFor(MediaCategory category) async {
    if (category == MediaCategory.stickers) {
      // Special case — see the NOTE in [mediaRoot]'s doc comment.
      final appDocsDir = await getApplicationDocumentsDirectory();
      final stickerDir = Directory(
        p.join(appDocsDir.path, category.folderName),
      );
      if (!await stickerDir.exists()) {
        await stickerDir.create(recursive: true);
      }
      return stickerDir;
    }

    final root = await mediaRoot();
    final dir = Directory(p.join(root.path, category.folderName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Copies [source] (e.g. the `File` from an `image_picker`/
  /// `image_cropper` result) into the app-owned directory for
  /// [category], under a newly generated unique filename, and returns
  /// the saved file's absolute path.
  ///
  /// The returned path — not [source]'s original path — is what must be
  /// stored in the database.
  ///
  /// Throws [MediaStorageException] if [source] can no longer be read
  /// (e.g. it was already evicted from the OS/gallery cache between
  /// pick and save) or if the copy/write fails for any other reason
  /// (permissions, out of disk space).
  Future<String> saveFile(
    File source, {
    required MediaCategory category,
  }) async {
    try {
      if (!await source.exists()) {
        throw MediaStorageException(
          message:
              'Source file no longer exists at ${source.path}. It may '
              'have been evicted from the OS/gallery cache before it '
              'could be saved.',
        );
      }

      final directory = await directoryFor(category);
      final extension = p.extension(source.path); // includes leading '.'
      final fileName = _generateFileName(extension: extension);
      final destination = File(p.join(directory.path, fileName));

      await source.copy(destination.path);
      return destination.path;
    } on MediaStorageException {
      rethrow;
    } catch (e) {
      throw MediaStorageException(
        message: 'Failed to save media file into $category: $e',
      );
    }
  }

  /// Writes raw [bytes] (e.g. a downloaded sticker/background, or a
  /// file extracted from an import bundle) into the app-owned directory
  /// for [category] and returns the saved file's absolute path.
  ///
  /// By default the file gets a newly generated unique filename with
  /// the given [extension] (pass with or without a leading dot — both
  /// accepted).
  ///
  /// Pass [fileName] to store the file under that exact name instead
  /// (e.g. the remote file name of a downloaded preset), so
  /// [findExistingByFileName] can find it again later. [extension] is
  /// ignored in that case. [fileName] must be a plain file name — no
  /// directory parts. An existing file with the same name is replaced.
  ///
  /// The bytes are written to a temporary file and renamed into place,
  /// so a crash or failure mid-write never leaves a truncated file under
  /// the final name.
  ///
  /// Throws [MediaStorageException] if the write fails or [fileName] is
  /// not a plain file name.
  Future<String> saveBytes(
    Uint8List bytes, {
    required MediaCategory category,
    required String extension,
    String? fileName,
  }) async {
    try {
      if (fileName != null &&
          (fileName.isEmpty ||
              fileName != p.basename(fileName) ||
              fileName == '.' ||
              fileName == '..')) {
        throw MediaStorageException(
          message: 'Invalid media file name: "$fileName"',
        );
      }

      final directory = await directoryFor(category);
      final normalizedExtension = extension.startsWith('.')
          ? extension
          : '.$extension';
      final finalName =
          fileName ?? _generateFileName(extension: normalizedExtension);
      final destination = File(p.join(directory.path, finalName));

      final temp = File(
        p.join(
          directory.path,
          '$finalName.${DateTime.now().microsecondsSinceEpoch}$_tempSuffix',
        ),
      );
      try {
        await temp.writeAsBytes(bytes, flush: true);
        await temp.rename(destination.path);
      } finally {
        if (await temp.exists()) {
          await temp.delete();
        }
      }
      return destination.path;
    } on MediaStorageException {
      rethrow;
    } catch (e) {
      throw MediaStorageException(
        message: 'Failed to save media bytes into $category: $e',
      );
    }
  }

  /// Deletes the app-owned file at [path], if it exists.
  ///
  /// Safe to call even if the file is already gone (e.g. double-cleanup
  /// after a failed prior attempt) — a missing file is treated as
  /// already-deleted, not an error. Use this when a feature replaces a
  /// photo (new avatar, new background) and wants to remove the old
  /// on-disk file rather than leaking it forever.
  ///
  /// Deliberately takes no [MediaCategory] — callers already have the
  /// exact path stored (that's the whole point of this service), so
  /// there's no ambiguity to resolve.
  Future<void> deleteFile(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      throw MediaStorageException(
        message: 'Failed to delete media file at $path: $e',
      );
    }
  }

  /// Returns the path of the non-empty file in [category] whose name is
  /// exactly [remoteFileName], or null if there is none.
  ///
  /// Only files saved with [saveBytes]'s `fileName` parameter can be
  /// found this way; files saved under a generated name (the default of
  /// [saveBytes] and [saveFile]) never match. Used by callers that
  /// download-and-cache remote files keyed by a stable remote name (e.g.
  /// [SupabaseStorageAssetService.downloadAndCache]) to skip
  /// re-downloading something already fetched in a prior session.
  ///
  /// The match is exact on purpose: a suffix match would treat
  /// `13.webp` as a hit for `3.webp`.
  Future<String?> findExistingByFileName(
    String remoteFileName, {
    required MediaCategory category,
  }) async {
    if (remoteFileName.isEmpty ||
        remoteFileName != p.basename(remoteFileName)) {
      return null;
    }

    final directory = await directoryFor(category);
    final file = File(p.join(directory.path, remoteFileName));
    if (await file.exists() && await file.length() > 0) {
      return file.path;
    }
    return null;
  }

  /// Suffix of in-progress writes (see [saveBytes]).
  static const String _tempSuffix = '.tmp';

  /// Generates a filename unique enough to never collide within this
  /// app: millisecond timestamp + a short random suffix. Avoids taking
  /// on a `uuid` package dependency for something this small; this
  /// service has no other dependencies beyond what's already in
  /// pubspec.yaml (`path`, `path_provider`).
  String _generateFileName({required String extension}) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final randomSuffix = Random().nextInt(0x7FFFFFFF).toRadixString(16);
    return '${timestamp}_$randomSuffix$extension';
  }
}