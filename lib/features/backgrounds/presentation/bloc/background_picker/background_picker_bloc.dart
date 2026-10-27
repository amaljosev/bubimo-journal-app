// lib/features/backgrounds/presentation/bloc/background_picker/background_picker_bloc.dart

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/repositories/background_repository.dart';
import 'background_picker_event.dart';
import 'background_picker_state.dart';

/// Drives the background picker.
///
/// Opening it is cheap by design:
/// 1. The cached preset list (memory -> disk) is emitted immediately —
///    no spinner, no network.
/// 2. If that list is fresh, that's all. If it's stale, it is refreshed
///    in the background while the user already browses.
/// 3. Only a true cold start (no cache) shows the spinner, once — and
///    `BackgroundRepository.prefetch()` (called when the diary form
///    opens) usually hides even that.
///
/// Nothing is downloaded until the user taps a preset; thumbnails are
/// streamed and disk-cached by the image widget.
class BackgroundPickerBloc
    extends Bloc<BackgroundPickerEvent, BackgroundPickerState> {
  BackgroundPickerBloc({required this._repository})
    : super(const BackgroundPickerState()) {
    on<BackgroundPickerStarted>(_onStarted);
    on<BackgroundPickerRetried>(_onRetried);
    on<BackgroundPresetSelected>(_onSelected);
  }

  final BackgroundRepository _repository;

  Future<void> _onStarted(
    BackgroundPickerStarted event,
    Emitter<BackgroundPickerState> emit,
  ) async {
    final cached = await _repository.readCachedCatalog();

    if (cached != null) {
      emit(
        state.copyWith(
          status: BackgroundPickerStatus.ready,
          urls: cached.urls,
        ),
      );
      if (cached.isFresh) return;
      await _refresh(emit, silent: true);
      return;
    }

    await _refresh(emit, silent: false);
  }

  Future<void> _onRetried(
    BackgroundPickerRetried event,
    Emitter<BackgroundPickerState> emit,
  ) {
    return _refresh(emit, silent: false);
  }

  /// [silent]: something is already on screen, so only a thin progress
  /// bar shows and a failure leaves the cached list untouched.
  Future<void> _refresh(
    Emitter<BackgroundPickerState> emit, {
    required bool silent,
  }) async {
    emit(
      silent
          ? state.copyWith(isRefreshing: true)
          : state.copyWith(status: BackgroundPickerStatus.loading),
    );

    final result = await _repository.refreshCatalog();

    result.match(
      (_) => emit(
        silent
            ? state.copyWith(isRefreshing: false)
            : state.copyWith(status: BackgroundPickerStatus.failure),
      ),
      (urls) => emit(
        state.copyWith(
          status: BackgroundPickerStatus.ready,
          urls: urls,
          isRefreshing: false,
        ),
      ),
    );
  }

  Future<void> _onSelected(
    BackgroundPresetSelected event,
    Emitter<BackgroundPickerState> emit,
  ) async {
    // One download at a time; extra taps are ignored.
    if (state.downloadingUrl != null) return;

    emit(
      state.copyWith(
        downloadingUrl: event.url,
        clearDownloaded: true,
        downloadFailed: false,
      ),
    );

    final result = await _repository.downloadPreset(event.url);

    result.match(
      (_) => emit(
        state.copyWith(clearDownloadingUrl: true, downloadFailed: true),
      ),
      (path) => emit(
        state.copyWith(
          clearDownloadingUrl: true,
          downloaded: DownloadedPreset(url: event.url, localPath: path),
        ),
      ),
    );
  }
}