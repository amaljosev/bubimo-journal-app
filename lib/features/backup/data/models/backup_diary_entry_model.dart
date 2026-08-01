// lib/features/backup/data/models/backup_diary_entry_model.dart

import 'dart:convert';

import '../../../diary_entry/domain/entities/diary_entry.dart';
import '../../../diary_entry/domain/entities/mood.dart';
import '../../../diary_entry/domain/entities/overlay_image.dart';
import '../../../diary_entry/domain/entities/sticker.dart';

/// JSON codec for [DiaryEntry] used ONLY by the backup/export bundle.
///
/// Deliberately separate from [DiaryEntryModel]'s `toMap`/`fromMap` —
/// those target sqlite's column shape (`TEXT`/`INTEGER` types, JSON-
/// encoded-as-a-string sub-fields) and are allowed to change whenever
/// the `diary_entries` table's schema changes. A backup file, once
/// created, has to stay readable by future app versions indefinitely —
/// coupling its format directly to the DB's column names/types would
/// mean a schema migration could silently break every backup a user
/// made before that migration shipped. This model's JSON shape is its
/// own independent contract, versioned by
/// `BackupManifest.formatVersion`, not by the DB schema version.
///
/// Path fields (`imagePath`, `overlayImages[].path`, etc.) are written
/// here EXACTLY as they exist on the source [DiaryEntry] — i.e. as this
/// device's absolute path. `BackupLocalDataSource` is responsible for
/// rewriting them to relative bundle paths before writing this JSON
/// into the archive, and rewriting them back to a fresh absolute path
/// on import.
///
/// ONE EXCEPTION to "this model does no path manipulation itself":
/// [content] (Quill Delta JSON) can carry inline image embeds whose
/// path is baked directly into that JSON as embed data — e.g.
/// `{"insert": {"image": "/absolute/path/to/photo.jpg"}}` — not just
/// referenced via the separate [DiaryEntry.images] denormalized list.
/// [extractContentImagePaths]/[rewriteContentImagePaths] below handle
/// that one case, since `BackupLocalDataSource` needs to treat those
/// embedded paths exactly like every other media path (bundle them on
/// export, resolve them to a fresh device path on import) — otherwise
/// an inline image renders correctly right up until the entry is
/// backed up and restored, at which point its embed still points at
/// the exporting device's now-nonexistent directory.
class BackupDiaryEntryModel {
  const BackupDiaryEntryModel._();

  static Map<String, dynamic> toJson(DiaryEntry entry) {
    return {
      'id': entry.id,
      'title': entry.title,
      'date': entry.date.toIso8601String(),
      'content': entry.content,
      'preview': entry.preview,
      'mood': entry.mood?.storageValue,
      'imagePath': entry.imagePath,
      'bgColor': entry.bgColor,
      'bgImagePath': entry.bgImagePath,
      'bgGalleryImagePath': entry.bgGalleryImagePath,
      'bgLocalPath': entry.bgLocalPath,
      'bgOverlayOpacity': entry.bgOverlayOpacity,
      'bgOverlayColor': entry.bgOverlayColor,
      'images': entry.images,
      'tags': entry.tags,
      'overlayImages': entry.overlayImages.map((o) => o.toJson()).toList(),
      'stickers': entry.stickers.map((s) => s.toJson()).toList(),
      'wordCount': entry.wordCount,
      'fontFamily': entry.fontFamily,
      'alignment': entry.alignment,
      'isBold': entry.isBold,
      'isItalic': entry.isItalic,
      'isUnderline': entry.isUnderline,
      'fontSize': entry.fontSize,
      'textColorHex': entry.textColorHex,
      'isFavorite': entry.isFavorite,
      'createdAt': entry.createdAt.toIso8601String(),
      'updatedAt': entry.updatedAt.toIso8601String(),
      // isDeleted / deletedAt are deliberately NOT included — only
      // non-deleted entries are ever passed to this codec (see
      // `BackupLocalDataSource.createBackup`, which sources entries
      // from `GetAllDiaryEntries`, already filtered to exclude
      // soft-deleted rows), and a freshly imported entry should always
      // start as a normal, non-deleted entry regardless of what state
      // it happened to be in on the exporting device.
    };
  }

  /// Parses one entry record from `data/diary_entries.json`.
  ///
  /// [newId] is the freshly generated id this imported entry will use —
  /// see `BackupLocalDataSource.importBackup`'s doc comment for why
  /// every imported entry always gets a new id rather than reusing the
  /// one stored in the bundle. [resolvedPaths] maps every relative
  /// bundle media path referenced by this record (as originally written
  /// by [toJson]) to the fresh absolute path it was copied to on THIS
  /// device — already computed by the caller before this record is
  /// parsed, since resolving a path requires an async file-copy this
  /// synchronous parse step shouldn't perform itself.
  ///
  /// Throws [FormatException] on missing/invalid required fields, or
  /// [ArgumentError] if a path field references a bundle media path not
  /// present in [resolvedPaths] — both are caught by the caller and
  /// treated as "skip this one malformed record", not "abort the whole
  /// import" (see [ImportResult.skippedCount]).
  static DiaryEntry fromJson(
    Map<String, dynamic> json, {
    required String newId,
    required Map<String, String> resolvedPaths,
  }) {
    final date = json['date'];
    final createdAt = json['createdAt'];
    final updatedAt = json['updatedAt'];

    if (date is! String || DateTime.tryParse(date) == null) {
      throw const FormatException('Entry is missing a valid "date".');
    }
    if (createdAt is! String || DateTime.tryParse(createdAt) == null) {
      throw const FormatException('Entry is missing a valid "createdAt".');
    }
    if (updatedAt is! String || DateTime.tryParse(updatedAt) == null) {
      throw const FormatException('Entry is missing a valid "updatedAt".');
    }

    String? resolvePath(String? bundlePath) {
      if (bundlePath == null || bundlePath.isEmpty) return null;
      final resolved = resolvedPaths[bundlePath];
      if (resolved == null) {
        throw ArgumentError(
          'Entry references media path "$bundlePath" which was not '
          'found in the bundle\'s media/ directory.',
        );
      }
      return resolved;
    }

    final overlayImagesRaw = json['overlayImages'];
    final overlayImages = <OverlayImage>[];
    if (overlayImagesRaw is List) {
      for (final item in overlayImagesRaw) {
        if (item is! Map<String, dynamic>) continue;
        try {
          final bundlePath = item['path'] as String?;
          final resolved = resolvePath(bundlePath);
          if (resolved == null) continue;
          overlayImages.add(
            OverlayImage.fromJson({...item, 'path': resolved}),
          );
        } catch (_) {
          // Skip this one malformed/unresolvable overlay image, same
          // per-record fault isolation as DiaryEntryModel's own
          // _decodeOverlayImages.
        }
      }
    }

    final stickersRaw = json['stickers'];
    final stickers = <Sticker>[];
    if (stickersRaw is List) {
      for (final item in stickersRaw) {
        if (item is! Map<String, dynamic>) continue;
        try {
          // Stickers' localPath is optional (see Sticker's own doc
          // comment) — if the cached file wasn't present in the bundle
          // for any reason, fall back to null rather than dropping the
          // whole sticker; DiaryFormBloc's existing recovery logic
          // (re-download from `url`) already handles a null/missing
          // localPath.
          final bundleLocalPath = item['localPath'] as String?;
          final resolvedLocalPath = bundleLocalPath == null
              ? null
              : resolvedPaths[bundleLocalPath];
          stickers.add(
            Sticker.fromJson({...item, 'localPath': resolvedLocalPath}),
          );
        } catch (_) {
          // Skip this one malformed sticker.
        }
      }
    }

    final imagesRaw = json['images'];
    final images = <String>[];
    if (imagesRaw is List) {
      for (final item in imagesRaw) {
        if (item is! String) continue;
        final resolved = resolvePath(item);
        if (resolved != null) images.add(resolved);
      }
    }

    final tagsRaw = json['tags'];
    final tags = tagsRaw is List
        ? tagsRaw.whereType<String>().toList()
        : const <String>[];

    final rawContent = json['content'] as String?;
    final rewrittenContent = rawContent == null
        ? null
        : rewriteContentImagePaths(rawContent, resolvedPaths);

    return DiaryEntry(
      id: newId,
      title: json['title'] as String?,
      date: DateTime.parse(date),
      content: rewrittenContent,
      preview: json['preview'] as String?,
      mood: Mood.fromStorageValue(json['mood'] as String?),
      imagePath: resolvePath(json['imagePath'] as String?),
      bgColor: json['bgColor'] as String?,
      // ASSUMPTION (unverified against BackgroundImageUtils, which
      // wasn't in the files shared so far): bgImagePath is a BUNDLED
      // APP ASSET path (e.g. "assets/backgrounds/local/..."), matching
      // the assets/backgrounds/local/ entry declared in pubspec.yaml —
      // distinct from bgGalleryImagePath (user's own gallery photo) and
      // bgLocalPath (cached remote preset), which is why it's the only
      // one of the three background fields NOT resolved through
      // resolvePath() here. A bundled asset ships with every install,
      // so the same string is valid on every device — nothing to copy
      // into the export bundle or rewrite on import. If this
      // assumption is wrong (i.e. it can also hold a real on-device
      // file path in some flow), this needs to route through
      // resolvePath() like the other two.
      bgImagePath: json['bgImagePath'] as String?,
      bgGalleryImagePath: resolvePath(json['bgGalleryImagePath'] as String?),
      bgLocalPath: resolvePath(json['bgLocalPath'] as String?),
      bgOverlayOpacity:
          (json['bgOverlayOpacity'] as num?)?.toDouble() ?? 0.85,
      bgOverlayColor: json['bgOverlayColor'] as String?,
      images: images,
      tags: tags,
      overlayImages: overlayImages,
      stickers: stickers,
      wordCount: (json['wordCount'] as num?)?.toInt() ?? 0,
      fontFamily: json['fontFamily'] as String?,
      // Defaults mirror DiaryEntryModel.fromMap's exact conventions —
      // 'left'/false for these, so a backup missing them entirely
      // (e.g. one made before this fix shipped) falls back to the same
      // defaults a brand-new entry would get, rather than throwing.
      alignment: json['alignment'] as String? ?? 'left',
      isBold: json['isBold'] as bool? ?? false,
      isItalic: json['isItalic'] as bool? ?? false,
      isUnderline: json['isUnderline'] as bool? ?? false,
      fontSize: json['fontSize'] as String?,
      textColorHex: json['textColorHex'] as String?,
      isFavorite: json['isFavorite'] as bool? ?? false,
      createdAt: DateTime.parse(createdAt),
      updatedAt: DateTime.parse(updatedAt),
    );
  }

  /// Finds every inline image path embedded directly in [content]'s
  /// Quill Delta JSON (an op shaped like
  /// `{"insert": {"image": "<path>"}}`) — as opposed to
  /// [DiaryEntry.images], the separate denormalized list of the same
  /// paths kept in sync alongside the document.
  ///
  /// Used by `BackupLocalDataSource` on export, to know which embedded
  /// paths need to be bundled into the archive exactly like any other
  /// media path — otherwise an inline image's file gets correctly
  /// copied into the export ONLY if it also happens to appear in
  /// [DiaryEntry.images]; the embed itself, which is what actually
  /// renders the image, would be left pointing at the exporting
  /// device's original (now-nonexistent) path.
  ///
  /// Returns an empty list if [content] isn't valid Delta JSON (e.g. a
  /// legacy plain-text entry from before the rich editor existed) —
  /// mirrors the same fallback [DiaryFormBloc._extractPlainText] uses
  /// for the same "might not be Delta JSON" situation.
  static List<String> extractContentImagePaths(String content) {
    final ops = _tryParseDeltaOps(content);
    if (ops == null) return const [];

    final paths = <String>[];
    for (final op in ops) {
      if (op is! Map) continue;
      final insert = op['insert'];
      if (insert is Map && insert.containsKey('image')) {
        final path = insert['image'];
        if (path is String && path.isNotEmpty) paths.add(path);
      }
    }
    return paths;
  }

  /// Returns [content] with every embedded image path replaced
  /// according to [pathRewrites] (old path -> new path) — any embedded
  /// path NOT present as a key in [pathRewrites] is left untouched.
  ///
  /// The SAME function serves both directions: on export,
  /// `BackupLocalDataSource` passes an absolute-path -> bundle-relative-
  /// path map; on import, [fromJson] passes [resolvedPaths] (bundle-
  /// relative -> this device's fresh absolute path) — either way, it's
  /// just "replace every embedded path found in the map with its
  /// mapped value."
  ///
  /// Returns [content] completely unchanged if it isn't valid Delta
  /// JSON, or if no embedded path actually matches a key in
  /// [pathRewrites] — avoids needlessly re-encoding (and potentially
  /// reformatting) JSON that didn't need to change.
  static String rewriteContentImagePaths(
    String content,
    Map<String, String> pathRewrites,
  ) {
    if (pathRewrites.isEmpty) return content;

    final ops = _tryParseDeltaOps(content);
    if (ops == null) return content;

    var changed = false;
    final rewrittenOps = ops.map((op) {
      if (op is! Map) return op;
      final insert = op['insert'];
      if (insert is Map && insert.containsKey('image')) {
        final path = insert['image'];
        final replacement = path is String ? pathRewrites[path] : null;
        if (replacement != null) {
          changed = true;
          final newInsert = Map<String, dynamic>.from(insert);
          newInsert['image'] = replacement;
          return {...op, 'insert': newInsert};
        }
      }
      return op;
    }).toList();

    if (!changed) return content;
    return jsonEncode(rewrittenOps);
  }

  /// Parses [content] as Quill Delta JSON — a raw JSON array of ops,
  /// NOT wrapped in `{"ops": [...]}` (matching how this app already
  /// stores/reads it — see `DiaryFormBloc._extractPlainText`'s
  /// identical `Document.fromJson(decoded as List)` usage). Returns
  /// null for anything that isn't a valid JSON array (empty content,
  /// legacy plain text, or genuinely malformed data) rather than
  /// throwing — every caller here treats "not Delta JSON" as "nothing
  /// to do", not an error.
  static List<dynamic>? _tryParseDeltaOps(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return null;
    try {
      final decoded = jsonDecode(trimmed);
      return decoded is List ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}