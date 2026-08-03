// lib/features/backgrounds/presentation/bloc/background_picker/background_picker_event.dart

import 'package:equatable/equatable.dart';

sealed class BackgroundPickerEvent extends Equatable {
  const BackgroundPickerEvent();

  @override
  List<Object?> get props => [];
}

/// Loads local bundled presets immediately, lists the available
/// Supabase presets, then downloads and caches the first page of
/// them. Fired once when the background picker opens (and again by
/// the "Try again" retry action, or when connectivity comes back).
final class LoadBackgrounds extends BackgroundPickerEvent {
  const LoadBackgrounds();
}

/// Downloads and caches the next page of already-listed Supabase
/// presets. Fired when the grid is scrolled near its end. A no-op if
/// a page is already in flight, the previous attempt failed
/// outright, or there's nothing left to load.
final class LoadMoreBackgrounds extends BackgroundPickerEvent {
  const LoadMoreBackgrounds();
}