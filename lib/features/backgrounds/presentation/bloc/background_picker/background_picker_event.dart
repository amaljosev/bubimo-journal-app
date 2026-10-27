// lib/features/backgrounds/presentation/bloc/background_picker/background_picker_event.dart

import 'package:equatable/equatable.dart';

sealed class BackgroundPickerEvent extends Equatable {
  const BackgroundPickerEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once when the picker opens. Shows the cached preset list
/// instantly if there is one, and refreshes it in the background when
/// it is stale (or loads it with a spinner when there is none).
final class BackgroundPickerStarted extends BackgroundPickerEvent {
  const BackgroundPickerStarted();
}

/// Fired by the "Try again" button after a failed first load.
final class BackgroundPickerRetried extends BackgroundPickerEvent {
  const BackgroundPickerRetried();
}

/// Fired when the user taps a preset: downloads it to a durable local
/// file (instant if already downloaded) and reports the path through
/// `BackgroundPickerState.downloaded`.
final class BackgroundPresetSelected extends BackgroundPickerEvent {
  final String url;

  const BackgroundPresetSelected(this.url);

  @override
  List<Object?> get props => [url];
}