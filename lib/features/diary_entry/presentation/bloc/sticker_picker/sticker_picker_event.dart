// lib/features/diary_entry/presentation/bloc/sticker_picker/sticker_picker_event.dart
//
// Reconstructed from how these events are dispatched in
// sticker_picker_sheet.dart and diary_form_page.dart — I don't have
// your actual current file to diff against, so please sanity-check
// this against it (or share it) rather than assuming a silent match.

import 'package:equatable/equatable.dart';

sealed class StickerPickerEvent extends Equatable {
  const StickerPickerEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the sticker picker sheet opens. Checks the local
/// offline seed first (shown immediately, no spinner, if present),
/// then lists categories from Supabase in the background — or as the
/// primary, spinner-visible load if there's no seed yet.
final class StickerPickerRequested extends StickerPickerEvent {
  const StickerPickerRequested();
}

/// Fired from the "Try again" button when the previous attempt left
/// nothing to show (no seed, and the listing failed).
final class StickerPickerRetried extends StickerPickerEvent {
  const StickerPickerRetried();
}

/// Fired when the user taps a sticker tile. Downloads (or, if already
/// cached — including from the offline seed — resolves instantly)
/// the sticker at [url] and reports the result via
/// [StickerPickerState.lastDownloaded] / `downloadError`.
final class StickerSelected extends StickerPickerEvent {
  final String url;

  const StickerSelected(this.url);

  @override
  List<Object?> get props => [url];
}