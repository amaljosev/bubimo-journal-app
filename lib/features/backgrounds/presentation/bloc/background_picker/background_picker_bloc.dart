// lib/features/backgrounds/presentation/bloc/background_picker/background_picker_bloc.dart

import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/datasources/supabase_background_data_source.dart';
import 'background_picker_event.dart';
import 'background_picker_state.dart';

/// Bundled local preset asset paths. Replace with your actual pack —
/// each must be declared under `flutter: assets:` in pubspec.yaml.
const List<String> _bundledBackgroundPaths = [
  'assets/backgrounds/local/bg_1.jpeg',
  'assets/backgrounds/local/bg_2.webp',
  
];

/// Drives the background picker. Local presets are bundled assets and
/// shown instantly; Supabase Storage presets (bucket `assets`, folder
/// `bg_presets`) are fetched and cached in the background afterward,
/// since the app is offline-first and must never block the picker on a
/// network call.
class BackgroundPickerBloc
    extends Bloc<BackgroundPickerEvent, BackgroundPickerState> {
  final SupabaseBackgroundDataSource remoteDataSource;

  BackgroundPickerBloc({required this.remoteDataSource})
      : super(const BackgroundPickerState()) {
    on<LoadBackgrounds>(_onLoadBackgrounds);
  }

  Future<void> _onLoadBackgrounds(
    LoadBackgrounds event,
    Emitter<BackgroundPickerState> emit,
  ) async {
    // Local presets are always available — show them immediately
    // without waiting on the network.
    emit(
      state.copyWith(
        status: BackgroundPickerStatus.loaded,
        localPresets: _bundledBackgroundPaths,
      ),
    );

    try {
      final urls = await remoteDataSource.fetchAvailablePackUrls();
      developer.log(
        'Fetched ${urls.length} background preset URL(s) from Supabase',
        name: 'BackgroundPickerBloc',
      );

      final cachedPaths = <String>[];
      for (final url in urls) {
        try {
          cachedPaths.add(await remoteDataSource.downloadAndCache(url));
        } catch (error, stackTrace) {
          // Don't let one bad file sink the whole batch — log it and
          // keep going with the rest.
          developer.log(
            'Failed to download/cache background preset: $url',
            name: 'BackgroundPickerBloc',
            error: error,
            stackTrace: stackTrace,
          );
        }
      }

      // If there were URLs to work with but none of them ended up
      // cached, that's a systemic problem (bucket/folder misconfig,
      // permissions, etc.) rather than "there just aren't any
      // presets" — surface it as a failure so the retry affordance
      // shows instead of a silently-empty grid.
      final failed = urls.isNotEmpty && cachedPaths.isEmpty;

      emit(
        state.copyWith(
          remotePresets: cachedPaths,
          remoteFetchAttempted: true,
          remoteFetchFailed: failed,
        ),
      );
    } catch (error, stackTrace) {
      // Offline, or listing the bucket failed outright — non-fatal.
      // Local presets remain fully usable; the UI just shows a
      // plain, human-readable message. Logged — never surfaced
      // verbatim — so the real cause is visible to us in dev tools /
      // crash reporting.
      developer.log(
        'Failed to load Supabase background presets',
        name: 'BackgroundPickerBloc',
        error: error,
        stackTrace: stackTrace,
      );
      emit(
        state.copyWith(
          remoteFetchAttempted: true,
          remoteFetchFailed: true,
        ),
      );
    }
  }
}