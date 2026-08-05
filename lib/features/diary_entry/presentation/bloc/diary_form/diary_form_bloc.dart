// lib/features/diary_entry/presentation/bloc/diary_form/diary_form_bloc.dart

import 'dart:convert';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

import '../../../../../core/utils/id_generator.dart';
import '../../../domain/entities/diary_entry.dart';
import '../../../domain/entities/overlay_image.dart';
import '../../../domain/entities/sticker.dart';
import '../../../domain/usecases/create_diary_entry.dart';
import '../../../domain/usecases/get_diary_entry_by_id.dart';
import '../../../domain/usecases/update_diary_entry.dart';
import 'diary_form_event.dart';
import 'diary_form_state.dart';

/// Handles both create and update flows for a single diary entry.
///
/// Edit mode is determined by whether [DiaryFormInitialized] was given
/// an `entryId`. On save, this bloc always calls the single generic
/// [UpdateDiaryEntry] use case (via `existingEntry.copyWith(...)`) when
/// editing, or [CreateDiaryEntry] when creating — no per-field use cases.
///
/// [DiaryFormState.content] holds Quill Delta JSON (a string), not
/// plain text, since the rich editor milestone — [_buildPreview] and
/// [_countWords] parse that Delta JSON into plain text before deriving
/// the `preview`/`wordCount` fields stored on the entity.
///
/// [DiaryFormState.images] is a denormalized cache kept in sync by the
/// picker widget as photos are inserted into the document — this bloc
/// doesn't re-derive it from the Delta JSON.
///
/// [DiaryFormState.stickers] and [DiaryFormState.overlayImages] are both
/// free-floating canvas items with their own position/scale/rotation —
/// this bloc doesn't download stickers itself (that's
/// `StickerPickerBloc`'s job); it only receives the already-downloaded
/// result via [DiaryFormStickerAdded] and places it on the canvas,
/// mirroring exactly how [DiaryFormOverlayImageAdded] places a gallery
/// overlay photo.
///
/// Background fields (`bgImagePath`/`bgGalleryImagePath`/`bgLocalPath`)
/// are set as a group by [DiaryFormBackgroundChanged] — the background
/// picker widget determines which one to populate.
class DiaryFormBloc extends Bloc<DiaryFormEvent, DiaryFormState> {
  final CreateDiaryEntry createDiaryEntry;
  final UpdateDiaryEntry updateDiaryEntry;
  final GetDiaryEntryById getDiaryEntryById;

  /// The full existing entry, kept around in edit mode so save can
  /// `copyWith` only the fields the form actually changes without
  /// discarding fields this milestone's UI doesn't expose yet
  /// (tags, etc.).
  DiaryEntry? _loadedEntry;

  DiaryFormBloc({
    required this.createDiaryEntry,
    required this.updateDiaryEntry,
    required this.getDiaryEntryById,
  }) : super(DiaryFormState.initial()) {
    on<DiaryFormInitialized>(_onInitialized);
    on<DiaryFormTitleChanged>(_onTitleChanged);
    on<DiaryFormContentChanged>(_onContentChanged);
    on<DiaryFormDateChanged>(_onDateChanged);
    on<DiaryFormMoodChanged>(_onMoodChanged);
    on<DiaryFormFontFamilyChanged>(_onFontFamilyChanged);
    on<DiaryFormAlignmentChanged>(_onAlignmentChanged);
    on<DiaryFormBoldChanged>(_onBoldChanged);
    on<DiaryFormItalicChanged>(_onItalicChanged);
    on<DiaryFormUnderlineChanged>(_onUnderlineChanged);
    on<DiaryFormFontSizeChanged>(_onFontSizeChanged);
    on<DiaryFormTextColorChanged>(_onTextColorChanged);
    on<DiaryFormImageAdded>(_onImageAdded);
    on<DiaryFormOverlayImageAdded>(_onOverlayImageAdded);
    on<DiaryFormOverlayImageTransformed>(_onOverlayImageTransformed);
    on<DiaryFormOverlayImageRemoved>(_onOverlayImageRemoved);
    on<DiaryFormOverlayImageSelected>(_onOverlayImageSelected);
    on<DiaryFormStickerAdded>(_onStickerAdded);
    on<DiaryFormStickerTransformed>(_onStickerTransformed);
    on<DiaryFormStickerRemoved>(_onStickerRemoved);
    on<DiaryFormStickerSelected>(_onStickerSelected);
    on<DiaryFormBackgroundChanged>(_onBackgroundChanged);
    on<DiaryFormOverlayOpacityChanged>(_onOverlayOpacityChanged);
    on<DiaryFormSubmitted>(_onSubmitted);
  }

  Future<void> _onInitialized(
    DiaryFormInitialized event,
    Emitter<DiaryFormState> emit,
  ) async {
    if (event.entryId == null) {
      emit(state.copyWith(status: DiaryFormStatus.ready));
      return;
    }

    emit(state.copyWith(status: DiaryFormStatus.loadingEntry));

    final result = await getDiaryEntryById(event.entryId!);

    result.match(
      (failure) => emit(
        state.copyWith(
          status: DiaryFormStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (entry) {
        _loadedEntry = entry;
        emit(
          state.copyWith(
            status: DiaryFormStatus.ready,
            entryId: entry.id,
            title: entry.title ?? '',
            content: entry.content ?? '',
            date: entry.date,
            mood: entry.mood,
            fontFamily: entry.fontFamily,
            alignment: entry.alignment,
            isBold: entry.isBold,
            isItalic: entry.isItalic,
            isUnderline: entry.isUnderline,
            fontSize: entry.fontSize,
            clearFontSize: entry.fontSize == null,
            textColorHex: entry.textColorHex,
            clearTextColor: entry.textColorHex == null,
            images: entry.images,
            overlayImages: entry.overlayImages,
            stickers: entry.stickers,
            bgImagePath: entry.bgImagePath,
            bgGalleryImagePath: entry.bgGalleryImagePath,
            bgLocalPath: entry.bgLocalPath,
            bgOverlayOpacity: entry.bgOverlayOpacity,
            bgOverlayColor: entry.bgOverlayColor,
            // entry.bgOverlayColor is null for any Auto entry — copyWith's
            // `?? this.bgOverlayColor` fallback would only coincidentally
            // preserve that (since the initial state also defaults to
            // null); make it explicit so loading an Auto entry always
            // clears any stale color rather than depending on that
            // coincidence.
            clearOverlayColor: entry.bgOverlayColor == null,
          ),
        );
      },
    );
  }

  void _onTitleChanged(
    DiaryFormTitleChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(state.copyWith(title: event.title));
  }

  void _onContentChanged(
    DiaryFormContentChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(state.copyWith(content: event.content));
  }

  void _onDateChanged(
    DiaryFormDateChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(state.copyWith(date: event.date));
  }

  void _onMoodChanged(
    DiaryFormMoodChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(state.copyWith(mood: event.mood, clearMood: event.mood == null));
  }

  void _onFontFamilyChanged(
    DiaryFormFontFamilyChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(
      state.copyWith(
        fontFamily: event.fontFamily,
        clearFontFamily: event.fontFamily == null,
      ),
    );
  }

  void _onAlignmentChanged(
    DiaryFormAlignmentChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(state.copyWith(alignment: event.alignment));
  }

  void _onBoldChanged(
    DiaryFormBoldChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(state.copyWith(isBold: event.isBold));
  }

  void _onItalicChanged(
    DiaryFormItalicChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(state.copyWith(isItalic: event.isItalic));
  }

  void _onUnderlineChanged(
    DiaryFormUnderlineChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(state.copyWith(isUnderline: event.isUnderline));
  }

  void _onFontSizeChanged(
    DiaryFormFontSizeChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(
      state.copyWith(
        fontSize: event.fontSize,
        clearFontSize: event.fontSize == null,
      ),
    );
  }

  void _onTextColorChanged(
    DiaryFormTextColorChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(
      state.copyWith(
        textColorHex: event.textColorHex,
        clearTextColor: event.textColorHex == null,
      ),
    );
  }

  void _onImageAdded(DiaryFormImageAdded event, Emitter<DiaryFormState> emit) {
    emit(state.copyWith(images: [...state.images, event.imagePath]));
  }

  void _onOverlayImageAdded(
    DiaryFormOverlayImageAdded event,
    Emitter<DiaryFormState> emit,
  ) {
    final newImage = OverlayImage(
      id: event.id,
      path: event.path,
      x: event.x,
      y: event.y,
    );
    emit(
      state.copyWith(
        overlayImages: [...state.overlayImages, newImage],
        selectedOverlayImageId: event.id,
        clearSelectedSticker: true,
      ),
    );
  }

  void _onOverlayImageTransformed(
    DiaryFormOverlayImageTransformed event,
    Emitter<DiaryFormState> emit,
  ) {
    final updated = state.overlayImages
        .map(
          (img) => img.id == event.id
              ? img.copyWith(
                  x: event.x,
                  y: event.y,
                  scale: event.scale,
                  rotation: event.rotation,
                )
              : img,
        )
        .toList();
    emit(state.copyWith(overlayImages: updated));
  }

  void _onOverlayImageRemoved(
    DiaryFormOverlayImageRemoved event,
    Emitter<DiaryFormState> emit,
  ) {
    final updated = state.overlayImages
        .where((img) => img.id != event.id)
        .toList();
    final clearSelection = state.selectedOverlayImageId == event.id;
    emit(
      state.copyWith(
        overlayImages: updated,
        clearSelectedOverlayImage: clearSelection,
      ),
    );
  }

  void _onOverlayImageSelected(
    DiaryFormOverlayImageSelected event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(
      state.copyWith(
        selectedOverlayImageId: event.id,
        clearSelectedOverlayImage: event.id == null,
        // Selecting an overlay image always clears any sticker
        // selection — only one canvas item is ever "selected" (showing
        // its handles) at a time.
        clearSelectedSticker: event.id != null,
      ),
    );
  }

  void _onStickerAdded(
    DiaryFormStickerAdded event,
    Emitter<DiaryFormState> emit,
  ) {
    final newSticker = Sticker(
      id: event.id,
      url: event.url,
      localPath: event.localPath,
      x: event.x,
      y: event.y,
    );
    emit(
      state.copyWith(
        stickers: [...state.stickers, newSticker],
        selectedStickerId: event.id,
        clearSelectedOverlayImage: true,
      ),
    );
  }

  void _onStickerTransformed(
    DiaryFormStickerTransformed event,
    Emitter<DiaryFormState> emit,
  ) {
    final updated = state.stickers
        .map(
          (s) => s.id == event.id
              ? s.copyWith(
                  x: event.x,
                  y: event.y,
                  scale: event.scale,
                  rotation: event.rotation,
                )
              : s,
        )
        .toList();
    emit(state.copyWith(stickers: updated));
  }

  void _onStickerRemoved(
    DiaryFormStickerRemoved event,
    Emitter<DiaryFormState> emit,
  ) {
    final updated = state.stickers.where((s) => s.id != event.id).toList();
    final clearSelection = state.selectedStickerId == event.id;
    emit(
      state.copyWith(stickers: updated, clearSelectedSticker: clearSelection),
    );
  }

  void _onStickerSelected(
    DiaryFormStickerSelected event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(
      state.copyWith(
        selectedStickerId: event.id,
        clearSelectedSticker: event.id == null,
        clearSelectedOverlayImage: event.id != null,
      ),
    );
  }

  void _onBackgroundChanged(
    DiaryFormBackgroundChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    // Clear all three first, then set only the one the caller provided
    // — enforces that exactly one background source is active at a
    // time, per the app's rendering precedence rule.
    emit(
      state.copyWith(
        clearBackgrounds: true,
        bgImagePath: event.bgImagePath,
        bgGalleryImagePath: event.bgGalleryImagePath,
        bgLocalPath: event.bgLocalPath,
      ),
    );
  }

  void _onOverlayOpacityChanged(
    DiaryFormOverlayOpacityChanged event,
    Emitter<DiaryFormState> emit,
  ) {
    emit(
      state.copyWith(
        bgOverlayOpacity: event.opacity,
        bgOverlayColor: event.color,
        // event.color == null means the user picked "Auto" — copyWith's
        // usual `?? this.bgOverlayColor` fallback can't express
        // "explicitly clear back to null", so route through the same
        // clear-flag pattern used elsewhere in this state.
        clearOverlayColor: event.color == null,
      ),
    );
  }

  Future<void> _onSubmitted(
    DiaryFormSubmitted event,
    Emitter<DiaryFormState> emit,
  ) async {
    // Guard against duplicate submissions from rapid repeated taps —
    // once a save is in flight, ignore further submit events until it
    // resolves.
    if (state.isSubmitting) return;

    emit(state.copyWith(status: DiaryFormStatus.submitting));

    final now = DateTime.now();
    final plainText = _extractPlainText(state.content);
    final preview = _buildPreview(plainText);
    final wordCount = _countWords(plainText);

    final entry = state.isEditMode
        ? _loadedEntry!.copyWith(
            title: state.title,
            content: state.content,
            date: state.date,
            mood: state.mood,
            fontFamily: state.fontFamily,
            alignment: state.alignment,
            isBold: state.isBold,
            isItalic: state.isItalic,
            isUnderline: state.isUnderline,
            fontSize: state.fontSize,
            clearFontSize: state.fontSize == null,
            textColorHex: state.textColorHex,
            clearTextColor: state.textColorHex == null,
            images: state.images,
            overlayImages: state.overlayImages,
            stickers: state.stickers,
            bgImagePath: state.bgImagePath,
            bgGalleryImagePath: state.bgGalleryImagePath,
            bgLocalPath: state.bgLocalPath,
            bgOverlayOpacity: state.bgOverlayOpacity,
            bgOverlayColor: state.bgOverlayColor,
            // `state.bgOverlayColor == null` means Auto was chosen —
            // `copyWith`'s plain `??` fallback would otherwise silently
            // keep `_loadedEntry`'s previous explicit color instead of
            // clearing back to Auto, so route through the explicit flag.
            clearOverlayColor: state.bgOverlayColor == null,
            preview: preview,
            wordCount: wordCount,
            updatedAt: now,
          )
        : DiaryEntry(
            id: IdGenerator.generate(),
            title: state.title,
            content: state.content,
            date: state.date,
            mood: state.mood,
            fontFamily: state.fontFamily,
            alignment: state.alignment,
            isBold: state.isBold,
            isItalic: state.isItalic,
            isUnderline: state.isUnderline,
            fontSize: state.fontSize,
            textColorHex: state.textColorHex,
            images: state.images,
            overlayImages: state.overlayImages,
            stickers: state.stickers,
            bgImagePath: state.bgImagePath,
            bgGalleryImagePath: state.bgGalleryImagePath,
            bgLocalPath: state.bgLocalPath,
            bgOverlayOpacity: state.bgOverlayOpacity,
            bgOverlayColor: state.bgOverlayColor,
            preview: preview,
            wordCount: wordCount,
            createdAt: now,
            updatedAt: now,
          );

    final result = state.isEditMode
        ? await updateDiaryEntry(entry)
        : await createDiaryEntry(entry);

    result.match(
      (failure) => emit(
        state.copyWith(
          status: DiaryFormStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (_) => emit(state.copyWith(status: DiaryFormStatus.success)),
    );
  }

  /// Parses Quill Delta JSON into plain text. Falls back to returning
  /// the raw string unchanged if it isn't valid Delta JSON — this
  /// covers any legacy plain-text entries saved before the rich editor
  /// existed.
  String _extractPlainText(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';

    try {
      final decoded = jsonDecode(trimmed);
      final document = quill.Document.fromJson(decoded as List);
      return document.toPlainText().trim();
    } catch (_) {
      return trimmed;
    }
  }

  String _buildPreview(String plainText) {
    if (plainText.length <= 120) return plainText;
    return '${plainText.substring(0, 120)}…';
  }

  int _countWords(String plainText) {
    if (plainText.isEmpty) return 0;
    return plainText.split(RegExp(r'\s+')).length;
  }
}
