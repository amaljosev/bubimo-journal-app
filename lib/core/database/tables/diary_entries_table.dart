// lib/core/db/tables/diary_entries_table.dart
/// Schema definition for the `diary_entries` table.
///
/// This is the FINAL schema covering every field the app will ever need,
/// including fields not yet used by any milestone (e.g. stickers, images,
/// tags, is_deleted). This avoids future ALTER TABLE migrations for every
/// new feature milestone.
///
/// Pre-launch schema collapse: this table went through several
/// incremental migrations during development (adding overlay opacity/
/// color columns, then fixing up `bg_overlay_color`'s nullability) —
/// see `AppDatabase`'s version-history note. None of that migration SQL
/// applies anymore now that the database is resetting to version 1, so
/// it's been removed; [createTableSql] below already reflects the
/// final, corrected shape directly (`bg_overlay_color` nullable from
/// the start, no NOT NULL DEFAULT 'white' mistake to fix up).
class DiaryEntriesTable {
  DiaryEntriesTable._();

  static const String tableName = 'diary_entries';

  // Column names — use these constants everywhere instead of raw strings
  // to avoid typos causing silent query failures.
  static const String columnId = 'id';
  static const String columnTitle = 'title';
  static const String columnDate = 'date';
  static const String columnContent = 'content';
  static const String columnPreview = 'preview';
  static const String columnMood = 'mood';
  static const String columnImagePath = 'image_path';
  static const String columnBgColor = 'bg_color';
  static const String columnBgImagePath = 'bg_image_path';
  static const String columnBgGalleryImagePath = 'bg_gallery_image_path';
  static const String columnBgLocalPath = 'bg_local_path';
  static const String columnStickers = 'stickers';
  static const String columnImages = 'images';
  static const String columnTags = 'tags';

  /// JSON-encoded list of overlay image transform records (id, path, x,
  /// y, scale, rotation) — free-floating photos layered on top of the
  /// Quill editor. Kept separate from [columnImages], which tracks
  /// inline Quill embed paths only.
  static const String columnOverlayImages = 'overlay_images';

  /// Opacity (0.0–1.0) of the tint applied over the background image so
  /// text/embeds stay legible. Per-entry since different photos need
  /// different amounts of dimming/lightening. Defaults to 0.85.
  static const String columnBgOverlayOpacity = 'bg_overlay_opacity';

  /// Which tint color is blended over the background image: `'white'`
  /// (lightens a busy/dark photo) or `'black'` (darkens a bright one).
  /// `NULL` means "Auto" — the tint automatically follows the app's
  /// active theme (dark theme → black tint so white entry text stays
  /// legible; light theme → white tint so dark entry text stays
  /// legible) until the user explicitly overrides it for that entry.
  /// See `OverlayTintUtils`. Auto (`NULL`) is the default for every new
  /// entry — nullable with no default constraint.
  static const String columnBgOverlayColor = 'bg_overlay_color';
  static const String columnWordCount = 'word_count';
  static const String columnFontFamily = 'font_family';

  /// Whole-entry text style — see `DiaryEntry.alignment` etc. for the
  /// full rationale (mirrors the form's T panel / Text color panel so
  /// the plain-text title survives save/reload and shows correctly on
  /// the view-only screen). `'left'`, `'center'`, `'right'`, or
  /// `'justify'`.
  static const String columnAlignment = 'alignment';
  static const String columnIsBold = 'is_bold';
  static const String columnIsItalic = 'is_italic';
  static const String columnIsUnderline = 'is_underline';

  /// Numeric point-size string (e.g. `'20'`), or `NULL` for the
  /// document's default size.
  static const String columnFontSize = 'font_size';

  /// `#RRGGBB` hex string, or `NULL` for the default color.
  static const String columnTextColorHex = 'text_color_hex';

  static const String columnIsFavorite = 'is_favorite';
  static const String columnIsDeleted = 'is_deleted';
  static const String columnDeletedAt = 'deleted_at';
  static const String columnCreatedAt = 'created_at';
  static const String columnUpdatedAt = 'updated_at';

  static const String createTableSql = '''
    CREATE TABLE $tableName (
      $columnId TEXT PRIMARY KEY,
      $columnTitle TEXT,
      $columnDate TEXT NOT NULL,
      $columnContent TEXT,
      $columnPreview TEXT,
      $columnMood TEXT,
      $columnImagePath TEXT,
      $columnBgColor TEXT,
      $columnBgImagePath TEXT,
      $columnBgGalleryImagePath TEXT,
      $columnBgLocalPath TEXT,
      $columnStickers TEXT,
      $columnImages TEXT,
      $columnTags TEXT,
      $columnOverlayImages TEXT,
      $columnBgOverlayOpacity REAL NOT NULL DEFAULT 0.85,
      $columnBgOverlayColor TEXT,
      $columnWordCount INTEGER NOT NULL DEFAULT 0,
      $columnFontFamily TEXT,
      $columnAlignment TEXT NOT NULL DEFAULT 'left',
      $columnIsBold INTEGER NOT NULL DEFAULT 0,
      $columnIsItalic INTEGER NOT NULL DEFAULT 0,
      $columnIsUnderline INTEGER NOT NULL DEFAULT 0,
      $columnFontSize TEXT,
      $columnTextColorHex TEXT,
      $columnIsFavorite INTEGER NOT NULL DEFAULT 0,
      $columnIsDeleted INTEGER NOT NULL DEFAULT 0,
      $columnDeletedAt TEXT,
      $columnCreatedAt TEXT NOT NULL,
      $columnUpdatedAt TEXT NOT NULL
    );
  ''';
}