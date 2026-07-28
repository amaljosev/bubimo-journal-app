// lib/features/diary_entry/data/models/diary_entry_model.dart

import 'dart:convert';
import '../../../../core/database/tables/diary_entries_table.dart';
import '../../../../core/utils/date_utils.dart';
import '../../domain/entities/diary_entry.dart';
import '../../domain/entities/mood.dart';
import '../../domain/entities/overlay_image.dart';
import '../../domain/entities/sticker.dart';

/// Data-layer representation of [DiaryEntry], responsible for converting
/// between the domain entity and the raw `Map<String, Object?>` sqflite
/// reads/writes.
///
/// Covers every column in the final `diary_entries` schema. List fields
/// ([images], [tags]) are stored as JSON-encoded TEXT since SQLite has
/// no native array type; [overlayImages] and [stickers] are stored the
/// same way but hold full transform records (id/x/y/scale/rotation),
/// not just plain string paths.
class DiaryEntryModel extends DiaryEntry {
  const DiaryEntryModel({
    required super.id,
    super.title,
    required super.date,
    super.content,
    super.preview,
    super.mood,
    super.imagePath,
    super.bgColor,
    super.bgImagePath,
    super.bgGalleryImagePath,
    super.bgLocalPath,
    super.bgOverlayOpacity,
    super.bgOverlayColor,
    super.images,
    super.tags,
    super.overlayImages,
    super.stickers,
    super.wordCount,
    super.fontFamily,
    super.alignment,
    super.isBold,
    super.isItalic,
    super.isUnderline,
    super.fontSize,
    super.textColorHex,
    super.isFavorite,
    super.isDeleted,
    super.deletedAt,
    required super.createdAt,
    required super.updatedAt,
  });

  /// Builds a [DiaryEntryModel] from a domain [DiaryEntry], so the data
  /// layer can persist an entity constructed/updated by a use case
  /// (typically via `entry.copyWith(...)`).
  factory DiaryEntryModel.fromEntity(DiaryEntry entry) {
    return DiaryEntryModel(
      id: entry.id,
      title: entry.title,
      date: entry.date,
      content: entry.content,
      preview: entry.preview,
      mood: entry.mood,
      imagePath: entry.imagePath,
      bgColor: entry.bgColor,
      bgImagePath: entry.bgImagePath,
      bgGalleryImagePath: entry.bgGalleryImagePath,
      bgLocalPath: entry.bgLocalPath,
      bgOverlayOpacity: entry.bgOverlayOpacity,
      bgOverlayColor: entry.bgOverlayColor,
      images: entry.images,
      tags: entry.tags,
      overlayImages: entry.overlayImages,
      stickers: entry.stickers,
      wordCount: entry.wordCount,
      fontFamily: entry.fontFamily,
      alignment: entry.alignment,
      isBold: entry.isBold,
      isItalic: entry.isItalic,
      isUnderline: entry.isUnderline,
      fontSize: entry.fontSize,
      textColorHex: entry.textColorHex,
      isFavorite: entry.isFavorite,
      isDeleted: entry.isDeleted,
      deletedAt: entry.deletedAt,
      createdAt: entry.createdAt,
      updatedAt: entry.updatedAt,
    );
  }

  /// Builds a [DiaryEntryModel] from a raw sqflite row.
  factory DiaryEntryModel.fromMap(Map<String, Object?> map) {
    return DiaryEntryModel(
      id: map[DiaryEntriesTable.columnId] as String,
      title: map[DiaryEntriesTable.columnTitle] as String?,
      date: AppDateUtils.fromStorageString(
        map[DiaryEntriesTable.columnDate] as String,
      ),
      content: map[DiaryEntriesTable.columnContent] as String?,
      preview: map[DiaryEntriesTable.columnPreview] as String?,
      mood: Mood.fromStorageValue(
        map[DiaryEntriesTable.columnMood] as String?,
      ),
      imagePath: map[DiaryEntriesTable.columnImagePath] as String?,
      bgColor: map[DiaryEntriesTable.columnBgColor] as String?,
      bgImagePath: map[DiaryEntriesTable.columnBgImagePath] as String?,
      bgGalleryImagePath:
          map[DiaryEntriesTable.columnBgGalleryImagePath] as String?,
      bgLocalPath: map[DiaryEntriesTable.columnBgLocalPath] as String?,
      bgOverlayOpacity: (map[DiaryEntriesTable.columnBgOverlayOpacity]
              as num?)
          ?.toDouble() ??
          0.85,
      // No fallback to a literal color here: NULL in the DB means
      // "Auto" (tint follows the app theme) and must round-trip as
      // `null`, not be coerced into a fixed color choice.
      bgOverlayColor:
          map[DiaryEntriesTable.columnBgOverlayColor] as String?,
      images: _decodeStringList(
        map[DiaryEntriesTable.columnImages] as String?,
      ),
      tags: _decodeStringList(map[DiaryEntriesTable.columnTags] as String?),
      overlayImages: _decodeOverlayImages(
        map[DiaryEntriesTable.columnOverlayImages] as String?,
      ),
      stickers: _decodeStickers(
        map[DiaryEntriesTable.columnStickers] as String?,
      ),
      wordCount: (map[DiaryEntriesTable.columnWordCount] as int?) ?? 0,
      fontFamily: map[DiaryEntriesTable.columnFontFamily] as String?,
      alignment:
          map[DiaryEntriesTable.columnAlignment] as String? ?? 'left',
      isBold: (map[DiaryEntriesTable.columnIsBold] as int? ?? 0) == 1,
      isItalic: (map[DiaryEntriesTable.columnIsItalic] as int? ?? 0) == 1,
      isUnderline:
          (map[DiaryEntriesTable.columnIsUnderline] as int? ?? 0) == 1,
      fontSize: map[DiaryEntriesTable.columnFontSize] as String?,
      textColorHex: map[DiaryEntriesTable.columnTextColorHex] as String?,
      isFavorite: (map[DiaryEntriesTable.columnIsFavorite] as int? ?? 0) == 1,
      isDeleted: (map[DiaryEntriesTable.columnIsDeleted] as int? ?? 0) == 1,
      deletedAt: map[DiaryEntriesTable.columnDeletedAt] != null
          ? AppDateUtils.fromStorageString(
              map[DiaryEntriesTable.columnDeletedAt] as String,
            )
          : null,
      createdAt: AppDateUtils.fromStorageString(
        map[DiaryEntriesTable.columnCreatedAt] as String,
      ),
      updatedAt: AppDateUtils.fromStorageString(
        map[DiaryEntriesTable.columnUpdatedAt] as String,
      ),
    );
  }

  /// Converts this model into a raw sqflite row for insert/update.
  Map<String, Object?> toMap() {
    return {
      DiaryEntriesTable.columnId: id,
      DiaryEntriesTable.columnTitle: title,
      DiaryEntriesTable.columnDate: AppDateUtils.toStorageString(date),
      DiaryEntriesTable.columnContent: content,
      DiaryEntriesTable.columnPreview: preview,
      DiaryEntriesTable.columnMood: mood?.storageValue,
      DiaryEntriesTable.columnImagePath: imagePath,
      DiaryEntriesTable.columnBgColor: bgColor,
      DiaryEntriesTable.columnBgImagePath: bgImagePath,
      DiaryEntriesTable.columnBgGalleryImagePath: bgGalleryImagePath,
      DiaryEntriesTable.columnBgLocalPath: bgLocalPath,
      DiaryEntriesTable.columnBgOverlayOpacity: bgOverlayOpacity,
      DiaryEntriesTable.columnBgOverlayColor: bgOverlayColor,
      DiaryEntriesTable.columnStickers: _encodeStickers(stickers),
      DiaryEntriesTable.columnImages: _encodeStringList(images),
      DiaryEntriesTable.columnTags: _encodeStringList(tags),
      DiaryEntriesTable.columnOverlayImages:
          _encodeOverlayImages(overlayImages),
      DiaryEntriesTable.columnWordCount: wordCount,
      DiaryEntriesTable.columnFontFamily: fontFamily,
      DiaryEntriesTable.columnAlignment: alignment,
      DiaryEntriesTable.columnIsBold: isBold ? 1 : 0,
      DiaryEntriesTable.columnIsItalic: isItalic ? 1 : 0,
      DiaryEntriesTable.columnIsUnderline: isUnderline ? 1 : 0,
      DiaryEntriesTable.columnFontSize: fontSize,
      DiaryEntriesTable.columnTextColorHex: textColorHex,
      DiaryEntriesTable.columnIsFavorite: isFavorite ? 1 : 0,
      DiaryEntriesTable.columnIsDeleted: isDeleted ? 1 : 0,
      DiaryEntriesTable.columnDeletedAt: deletedAt != null
          ? AppDateUtils.toStorageString(deletedAt!)
          : null,
      DiaryEntriesTable.columnCreatedAt: AppDateUtils.toStorageString(
        createdAt,
      ),
      DiaryEntriesTable.columnUpdatedAt: AppDateUtils.toStorageString(
        updatedAt,
      ),
    };
  }

  static String? _encodeStringList(List<String> list) {
    if (list.isEmpty) return null;
    return jsonEncode(list);
  }

  static List<String> _decodeStringList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    final decoded = jsonDecode(raw);
    if (decoded is List) {
      return decoded.map((e) => e.toString()).toList();
    }
    return const [];
  }

  static String? _encodeOverlayImages(List<OverlayImage> list) {
    if (list.isEmpty) return null;
    return jsonEncode(list.map((o) => o.toJson()).toList());
  }

  /// Malformed entries (missing/invalid fields) are skipped individually
  /// rather than discarding the whole list, so one corrupt record can't
  /// wipe out every other overlay image on the entry.
  static List<OverlayImage> _decodeOverlayImages(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final result = <OverlayImage>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            result.add(OverlayImage.fromJson(item));
          } catch (_) {
            // Skip this single malformed record.
          }
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }

  static String? _encodeStickers(List<Sticker> list) {
    if (list.isEmpty) return null;
    return jsonEncode(list.map((s) => s.toJson()).toList());
  }

  /// Malformed entries are skipped individually, same rationale as
  /// [_decodeOverlayImages] — one corrupt sticker record shouldn't wipe
  /// out every other sticker on the entry.
  static List<Sticker> _decodeStickers(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final result = <Sticker>[];
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          try {
            result.add(Sticker.fromJson(item));
          } catch (_) {
            // Skip this single malformed record.
          }
        }
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}