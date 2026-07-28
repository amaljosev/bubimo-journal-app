// lib/features/diary_entry/domain/entities/diary_entry.dart

import 'package:equatable/equatable.dart';

import 'mood.dart';
import 'overlay_image.dart';
import 'sticker.dart';

/// Core domain entity representing a single diary entry.
///
/// This entity covers every field from the app's final database schema,
/// including fields not yet used by any milestone (e.g. [images],
/// [tags]). Fields unused by a not-yet-built feature stay
/// nullable/defaulted so this entity never needs another field added
/// later — future milestones only add behavior (use cases, bloc, UI)
/// that reads/writes fields that already exist here.
class DiaryEntry extends Equatable {
  final String id;
  final String? title;
  final DateTime date;
  final String? content;
  final String? preview;
  final Mood? mood;
  final String? imagePath;

  // Background — precedence when rendering: gallery > preset-local >
  // preset-remote (Supabase, cached to bgLocalPath after download) > color.
  final String? bgColor;
  final String? bgImagePath;
  final String? bgGalleryImagePath;
  final String? bgLocalPath;

  /// Opacity (0.0–1.0) of the tint blended over the background image so
  /// text/embeds stay legible over busy photos. Per-entry, since
  /// different background photos need different amounts of
  /// dimming/lightening. Defaults to 0.85 — the fixed value every entry
  /// rendered with before this became adjustable.
  final double bgOverlayOpacity;

  /// Which color is blended over the background image: `'white'`
  /// (lightens, for dark/busy photos), `'black'` (darkens, for
  /// bright/washed-out photos), or `null` for "Auto". Defaults to
  /// `null`, meaning the tint automatically follows the app's active
  /// theme (dark theme → light tint, light theme → dark tint) until the
  /// user explicitly overrides it for this entry — see
  /// `OverlayTintUtils`.
  final String? bgOverlayColor;

  /// Denormalized cache of gallery photo paths inserted inline into the
  /// Quill document (see [overlayImages] for the separate free-floating
  /// photo feature).
  final List<String> images;
  final List<String> tags;

  /// Free-floating, draggable/rotatable/resizable photos layered on top
  /// of the Quill editor, each with its own absolute position/transform
  /// data. Deliberately separate from [images], which tracks photos
  /// inserted inline as Quill embeds — the two features are additive
  /// and never share entries, so there's no collision between them.
  final List<OverlayImage> overlayImages;

  /// Free-floating stickers layered on top of the Quill editor, sourced
  /// from the shared Supabase sticker library — behaviorally identical
  /// to [overlayImages] (same transform mechanics), but each carries a
  /// [Sticker.url] recovery source so a missing local cache file can be
  /// re-downloaded rather than lost.
  final List<Sticker> stickers;

  final int wordCount;
  final String? fontFamily;

  /// Whole-entry text style — applies to both the title field and,
  /// independently, the Quill [content] (which carries its own
  /// `quill.Attribute.align` etc. inside the Delta JSON). These mirror
  /// the form's T panel / Text color panel and exist mainly so the
  /// plain-text title (which can't carry a Quill attribute of its own)
  /// keeps its style across save/reload and shows correctly on the
  /// view-only screen. One of `'left'`, `'center'`, `'right'`,
  /// `'justify'`.
  final String alignment;
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;

  /// Numeric point-size string matching `flutter_quill`'s
  /// `SizeAttribute` convention (e.g. `'20'`), or `null` for the
  /// document's default size.
  final String? fontSize;

  /// `#RRGGBB` hex string, or `null` for the default color.
  final String? textColorHex;

  final bool isFavorite;
  final bool isDeleted;
  final DateTime? deletedAt;

  final DateTime createdAt;
  final DateTime updatedAt;

  const DiaryEntry({
    required this.id,
    this.title,
    required this.date,
    this.content,
    this.preview,
    this.mood,
    this.imagePath,
    this.bgColor,
    this.bgImagePath,
    this.bgGalleryImagePath,
    this.bgLocalPath,
    this.bgOverlayOpacity = 0.85,
    this.bgOverlayColor,
    this.images = const [],
    this.tags = const [],
    this.overlayImages = const [],
    this.stickers = const [],
    this.wordCount = 0,
    this.fontFamily,
    this.alignment = 'left',
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontSize,
    this.textColorHex,
    this.isFavorite = false,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Returns a copy of this entry with the given fields replaced.
  ///
  /// This is the mechanism every feature milestone uses to "add" its own
  /// update behavior without new use cases — e.g. favorites calls
  /// `entry.copyWith(isFavorite: true)`, mood picker calls
  /// `entry.copyWith(mood: selectedMood)`, then both pass the result to
  /// the same generic `UpdateDiaryEntry` use case.
  ///
  /// Nullable fields that should be explicitly clearable (set back to
  /// null) use a sentinel-free approach here for simplicity — pass the
  /// current value explicitly if you don't want to change a field.
  /// [bgOverlayColor] is the one exception: `null` is itself a
  /// meaningful, commonly-set value ("Auto" — tint follows the app
  /// theme, see `OverlayTintUtils`), not just "leave unchanged", so it
  /// needs the explicit [clearOverlayColor] flag below to distinguish
  /// "don't touch this field" from "set it back to Auto".
  DiaryEntry copyWith({
    String? id,
    String? title,
    DateTime? date,
    String? content,
    String? preview,
    Mood? mood,
    String? imagePath,
    String? bgColor,
    String? bgImagePath,
    String? bgGalleryImagePath,
    String? bgLocalPath,
    double? bgOverlayOpacity,
    String? bgOverlayColor,
    bool clearOverlayColor = false,
    List<String>? images,
    List<String>? tags,
    List<OverlayImage>? overlayImages,
    List<Sticker>? stickers,
    int? wordCount,
    String? fontFamily,
    String? alignment,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    String? fontSize,
    bool clearFontSize = false,
    String? textColorHex,
    bool clearTextColor = false,
    bool? isFavorite,
    bool? isDeleted,
    DateTime? deletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DiaryEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      content: content ?? this.content,
      preview: preview ?? this.preview,
      mood: mood ?? this.mood,
      imagePath: imagePath ?? this.imagePath,
      bgColor: bgColor ?? this.bgColor,
      bgImagePath: bgImagePath ?? this.bgImagePath,
      bgGalleryImagePath: bgGalleryImagePath ?? this.bgGalleryImagePath,
      bgLocalPath: bgLocalPath ?? this.bgLocalPath,
      bgOverlayOpacity: bgOverlayOpacity ?? this.bgOverlayOpacity,
      bgOverlayColor: clearOverlayColor
          ? null
          : (bgOverlayColor ?? this.bgOverlayColor),
      images: images ?? this.images,
      tags: tags ?? this.tags,
      overlayImages: overlayImages ?? this.overlayImages,
      stickers: stickers ?? this.stickers,
      wordCount: wordCount ?? this.wordCount,
      fontFamily: fontFamily ?? this.fontFamily,
      alignment: alignment ?? this.alignment,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      fontSize: clearFontSize ? null : (fontSize ?? this.fontSize),
      textColorHex:
          clearTextColor ? null : (textColorHex ?? this.textColorHex),
      isFavorite: isFavorite ?? this.isFavorite,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        date,
        content,
        preview,
        mood,
        imagePath,
        bgColor,
        bgImagePath,
        bgGalleryImagePath,
        bgLocalPath,
        bgOverlayOpacity,
        bgOverlayColor,
        images,
        tags,
        overlayImages,
        stickers,
        wordCount,
        fontFamily,
        alignment,
        isBold,
        isItalic,
        isUnderline,
        fontSize,
        textColorHex,
        isFavorite,
        isDeleted,
        deletedAt,
        createdAt,
        updatedAt,
      ];
}