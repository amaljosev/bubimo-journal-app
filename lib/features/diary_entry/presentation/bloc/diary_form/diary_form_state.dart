// lib/features/diary_entry/presentation/bloc/diary_form/diary_form_state.dart

import 'package:equatable/equatable.dart';

import '../../../domain/entities/mood.dart';
import '../../../domain/entities/overlay_image.dart';
import '../../../domain/entities/sticker.dart';

enum DiaryFormStatus {
  /// Blank create form, or existing entry not loaded yet.
  initial,

  /// Loading an existing entry for edit mode.
  loadingEntry,

  /// Entry loaded (or blank create form ready), user can edit fields.
  ready,

  /// Save in progress — UI should disable the Save button to prevent
  /// duplicate submissions.
  submitting,

  /// Save succeeded — presentation layer should pop with a success
  /// result so the calling screen (Home) refreshes.
  success,

  /// Loading or saving failed.
  failure,
}

class DiaryFormState extends Equatable {
  final DiaryFormStatus status;

  /// Null while creating a new entry; set once an existing entry has
  /// been loaded for editing.
  final String? entryId;

  final String title;

  /// Quill Delta JSON, not plain text.
  final String content;

  final DateTime date;
  final Mood? mood;
  final String? fontFamily;

  /// Text alignment applied to both the title field (via `TextAlign`)
  /// and, independently, the Quill description (via
  /// `quill.Attribute.align`). One of `'left'`, `'center'`, `'right'`,
  /// `'justify'` — defaults to `'left'`, matching Quill's own default
  /// when no alignment attribute is set.
  final String alignment;

  /// Whole-entry text style fields — same "applies to both title and
  /// description" rationale as [alignment] above. These mirror the T
  /// panel's Bold/Italic/Underline/Font size and the dedicated "Text
  /// color" panel: the toolbar applies them to the Quill description
  /// directly via `formatText`, and additionally reports them here so
  /// the plain-text title field (which can't carry a Quill attribute)
  /// can apply the equivalent `TextStyle`.
  final bool isBold;
  final bool isItalic;
  final bool isUnderline;

  /// Numeric point-size string matching `flutter_quill`'s
  /// `SizeAttribute` convention (e.g. `'20'`), or `null` for the
  /// document's default size. Parsed to a `double` at the title-field
  /// call site.
  final String? fontSize;

  /// `#RRGGBB` hex string picked from the "Text color" panel, or
  /// `null` for the default color.
  final String? textColorHex;

  /// Denormalized cache of gallery photo asset paths inserted into
  /// [content] via the rich editor's image picker. Kept in sync by
  /// [DiaryFormImageAdded] rather than re-parsed from the Delta JSON on
  /// every change.
  final List<String> images;

  /// Free-floating overlay photos layered on top of the Quill editor —
  /// kept entirely separate from [images] (inline Quill embeds). See
  /// [DiaryEntry.overlayImages] for the full rationale.
  final List<OverlayImage> overlayImages;

  /// Free-floating stickers layered on top of the Quill editor, sourced
  /// from the shared Supabase sticker library. Behaviorally identical
  /// to [overlayImages] (same transform/selection mechanics via
  /// [OverlayLayer]) but tracked separately since stickers carry a
  /// [Sticker.url] recovery source that gallery overlay photos don't
  /// have.
  final List<Sticker> stickers;

  /// Id of the overlay image currently selected (showing its
  /// delete/resize handles), or null if none is selected.
  final String? selectedOverlayImageId;

  /// Id of the sticker currently selected, or null if none is selected.
  /// Tracked independently from [selectedOverlayImageId] — an image and
  /// a sticker are never considered "the same selection" even if their
  /// generated ids happened to collide.
  final String? selectedStickerId;

  /// Background fields — precedence when rendering is gallery >
  /// preset-local > preset-remote (cached) > color. Only one is
  /// typically non-null at a time; [copyWith]'s `clearBackgrounds` flag
  /// enforces that when a new selection is made.
  final String? bgImagePath;
  final String? bgGalleryImagePath;
  final String? bgLocalPath;

  /// Opacity (0.0–1.0) of the tint blended over the background image.
  /// Defaults to 0.85, matching the fixed value every entry rendered
  /// with before this became adjustable.
  final double bgOverlayOpacity;

  /// Tint color blended over the background image: `'white'`,
  /// `'black'`, or `null` for "Auto". Defaults to `null`, meaning the
  /// tint automatically follows the app's active theme (dark app theme
  /// → light tint, light app theme → dark tint) until the user
  /// explicitly overrides it for this entry via the overlay settings
  /// sheet — see [OverlayTintUtils].
  final String? bgOverlayColor;

  final String? errorMessage;

  const DiaryFormState({
    this.status = DiaryFormStatus.initial,
    this.entryId,
    this.title = '',
    this.content = '',
    required this.date,
    this.mood,
    this.fontFamily,
    this.alignment = 'left',
    this.isBold = false,
    this.isItalic = false,
    this.isUnderline = false,
    this.fontSize,
    this.textColorHex,
    this.images = const [],
    this.overlayImages = const [],
    this.stickers = const [],
    this.selectedOverlayImageId,
    this.selectedStickerId,
    this.bgImagePath,
    this.bgGalleryImagePath,
    this.bgLocalPath,
    this.bgOverlayOpacity = 0.50,
    this.bgOverlayColor,
    this.errorMessage,
  });

  factory DiaryFormState.initial() => DiaryFormState(date: DateTime.now());

  bool get isEditMode => entryId != null;
  bool get isSubmitting => status == DiaryFormStatus.submitting;

  /// When [clearBackgrounds] is true, all three background fields are
  /// set to EXACTLY the values passed in (null if omitted) rather than
  /// merged with the existing state — this is how a new background
  /// selection replaces whichever of the three was previously active,
  /// instead of leaving a stale value in one of the other two fields.
  DiaryFormState copyWith({
    DiaryFormStatus? status,
    String? entryId,
    String? title,
    String? content,
    DateTime? date,
    Mood? mood,
    bool clearMood = false,
    String? fontFamily,
    String? alignment,
    bool? isBold,
    bool? isItalic,
    bool? isUnderline,
    String? fontSize,
    bool clearFontSize = false,
    String? textColorHex,
    bool clearTextColor = false,
    List<String>? images,
    List<OverlayImage>? overlayImages,
    List<Sticker>? stickers,
    String? selectedOverlayImageId,
    bool clearSelectedOverlayImage = false,
    String? selectedStickerId,
    bool clearSelectedSticker = false,
    String? bgImagePath,
    String? bgGalleryImagePath,
    String? bgLocalPath,
    bool clearBackgrounds = false,
    double? bgOverlayOpacity,
    String? bgOverlayColor,
    bool clearOverlayColor = false,
    String? errorMessage,
  }) {
    return DiaryFormState(
      status: status ?? this.status,
      entryId: entryId ?? this.entryId,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      mood: clearMood ? null : (mood ?? this.mood),
      fontFamily: fontFamily ?? this.fontFamily,
      alignment: alignment ?? this.alignment,
      isBold: isBold ?? this.isBold,
      isItalic: isItalic ?? this.isItalic,
      isUnderline: isUnderline ?? this.isUnderline,
      fontSize: clearFontSize ? null : (fontSize ?? this.fontSize),
      textColorHex:
          clearTextColor ? null : (textColorHex ?? this.textColorHex),
      images: images ?? this.images,
      overlayImages: overlayImages ?? this.overlayImages,
      stickers: stickers ?? this.stickers,
      selectedOverlayImageId: clearSelectedOverlayImage
          ? null
          : (selectedOverlayImageId ?? this.selectedOverlayImageId),
      selectedStickerId: clearSelectedSticker
          ? null
          : (selectedStickerId ?? this.selectedStickerId),
      bgImagePath:
          clearBackgrounds ? bgImagePath : (bgImagePath ?? this.bgImagePath),
      bgGalleryImagePath: clearBackgrounds
          ? bgGalleryImagePath
          : (bgGalleryImagePath ?? this.bgGalleryImagePath),
      bgLocalPath:
          clearBackgrounds ? bgLocalPath : (bgLocalPath ?? this.bgLocalPath),
      bgOverlayOpacity: bgOverlayOpacity ?? this.bgOverlayOpacity,
      bgOverlayColor: clearOverlayColor
          ? null
          : (bgOverlayColor ?? this.bgOverlayColor),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        entryId,
        title,
        content,
        date,
        mood,
        fontFamily,
        alignment,
        isBold,
        isItalic,
        isUnderline,
        fontSize,
        textColorHex,
        images,
        overlayImages,
        stickers,
        selectedOverlayImageId,
        selectedStickerId,
        bgImagePath,
        bgGalleryImagePath,
        bgLocalPath,
        bgOverlayOpacity,
        bgOverlayColor,
        errorMessage,
      ];
}