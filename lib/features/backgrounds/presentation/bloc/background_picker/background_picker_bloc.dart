// lib/features/backgrounds/presentation/bloc/background_picker/background_picker_bloc.dart

import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/datasources/background_preset_cache_data_source.dart';
import '../../../data/datasources/supabase_background_data_source.dart';
import 'background_picker_event.dart';
import 'background_picker_state.dart';

/// Bundled local preset asset paths. Replace with your actual pack —
/// each must be declared under `flutter: assets:` in pubspec.yaml.
const List<String> _bundledBackgroundPaths = [
  'assets/backgrounds/local/bg_1.jpeg',
  'assets/backgrounds/local/bg_2.webp',
  
];

/// How many Supabase presets to download per page once paging beyond
/// the offline seed.
const int _pageSize = 24;

/// How many presets get persisted for guaranteed offline access — see
/// [BackgroundPresetCacheDataSource]. Deliberately much smaller than
/// [_pageSize]: this is a "never leaves you with nothing offline"
/// seed, not a cache of everything the user has ever scrolled past.
const int _seedCacheSize = 10;

/// Drives the background picker.
///
/// Loading order, on every open:
/// 1. Local bundled presets — instant, always available.
/// 2. The persisted offline seed (see [BackgroundPresetCacheDataSource])
///    — if one exists, shown immediately, no spinner, since it's
///    already on disk.
/// 3. A Supabase listing call, to pick up anything new — in the
///    background if step 2 already put something on screen, or as the
///    actual (spinner-visible) first load if step 2 came up empty.
/// 4. Further pages beyond the seed, downloaded on demand as the user
///    scrolls (`LoadMoreBackgrounds`), same as before — just not
///    persisted for offline use themselves.
class BackgroundPickerBloc
    extends Bloc<BackgroundPickerEvent, BackgroundPickerState> {
  final SupabaseBackgroundDataSource remoteDataSource;
  final BackgroundPresetCacheDataSource cacheDataSource;

  BackgroundPickerBloc({
    required this.remoteDataSource,
    required this.cacheDataSource,
  }) : super(const BackgroundPickerState()) {
    on<LoadBackgrounds>(_onLoadBackgrounds);
    on<LoadMoreBackgrounds>(_onLoadMoreBackgrounds);
  }

  Future<void> _onLoadBackgrounds(
    LoadBackgrounds event,
    Emitter<BackgroundPickerState> emit,
  ) async {
    // Local presets are always available — show them immediately
    // without waiting on anything else.
    emit(
      state.copyWith(
        status: BackgroundPickerStatus.loaded,
        localPresets: _bundledBackgroundPaths,
      ),
    );

    // 1. Local cache first. This is the whole point: if a seed is
    // already persisted, show it now — no spinner, no network
    // round-trip on the critical path.
    final cached = await cacheDataSource.getCachedPresets();
    final hadCache = cached.isNotEmpty;

    if (hadCache) {
      emit(
        state.copyWith(
          remoteByUrl: {for (final c in cached) c.url: c.localPath},
          remoteFetchAttempted: true,
          remoteFetchFailed: false,
        ),
      );
    }

    // 2. Check Supabase for anything new — in the background if step
    // 1 already gave us something to show, or as the real (blocking)
    // first load if it didn't.
    await _syncWithSupabase(emit, hadCache: hadCache);
  }

  Future<void> _syncWithSupabase(
    Emitter<BackgroundPickerState> emit, {
    required bool hadCache,
  }) async {
    if (hadCache) {
      emit(state.copyWith(isLoadingMoreRemote: true));
    } else {
      // Nothing to show yet — this fetch *is* the primary loading
      // state. Reset explicitly in case this is a "Try again" retry
      // rather than the very first attempt, so the UI flips back to
      // the spinner instead of sitting on a stale error screen with
      // no feedback that a retry is even happening.
      emit(
        state.copyWith(remoteFetchAttempted: false, remoteFetchFailed: false),
      );
    }

    List<String> urls;
    try {
      urls = await remoteDataSource.fetchAvailablePackUrls();
      developer.log(
        'Fetched ${urls.length} background preset URL(s) from Supabase',
        name: 'BackgroundPickerBloc',
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to list Supabase background presets',
        name: 'BackgroundPickerBloc',
        error: error,
        stackTrace: stackTrace,
      );
      // No cache and the network failed too: a genuine failure, shown
      // with a retry. With a cache: still fully usable offline — just
      // quietly stop the "checking for more" indicator and leave the
      // cached seed exactly as it was.
      emit(
        hadCache
            ? state.copyWith(isLoadingMoreRemote: false)
            : state.copyWith(
                remoteFetchAttempted: true,
                remoteFetchFailed: true,
              ),
      );
      return;
    }

    // Reconcile against whatever's already shown (the persisted seed,
    // or nothing) so pagination resumes from the right place instead
    // of re-walking presets we already have.
    final cursor = _leadingCachedCount(urls, state.remoteByUrl);
    emit(state.copyWith(remoteUrls: urls, remoteLoadedCount: cursor));

    if (!hadCache) {
      // Nothing offline yet — this download *is* the seed, persisted
      // once it lands (see `_loadNextPage`'s `persistAsSeed`).
      await _loadNextPage(emit, pageSize: _seedCacheSize, persistAsSeed: true);
    } else {
      emit(state.copyWith(isLoadingMoreRemote: false));
    }
  }

  /// How many of [freshUrls], counting from the front, are already
  /// present in [cached] — i.e. how much of a fresh listing the
  /// current display already covers, so `remoteLoadedCount` can pick
  /// up from there instead of 0.
  ///
  /// Stops at the first miss rather than counting matches anywhere in
  /// the list — Supabase's listing order is stable in the ordinary
  /// case, and a strictly-leading count is what makes the result safe
  /// to use as a cursor into `remoteUrls` for `_loadNextPage`. If the
  /// bucket's contents were reordered since the seed was cached, this
  /// just falls back toward re-walking from 0, which costs a few
  /// redundant lookups — each one still cheap, since
  /// `downloadAndCache` itself skips the actual download when a URL is
  /// already cached — rather than anything breaking.
  int _leadingCachedCount(List<String> freshUrls, Map<String, String> cached) {
    var count = 0;
    while (count < freshUrls.length && cached.containsKey(freshUrls[count])) {
      count++;
    }
    return count;
  }

  Future<void> _onLoadMoreBackgrounds(
    LoadMoreBackgrounds event,
    Emitter<BackgroundPickerState> emit,
  ) async {
    // Already fetching a page, the last attempt failed outright (the
    // user needs to hit "Try again" first), or nothing left to fetch.
    if (state.remoteFetchFailed ||
        state.isLoadingMoreRemote ||
        !state.hasMoreRemote) {
      return;
    }
    await _loadNextPage(emit, pageSize: _pageSize, persistAsSeed: false);
  }

  Future<void> _loadNextPage(
    Emitter<BackgroundPickerState> emit, {
    required int pageSize,
    required bool persistAsSeed,
  }) async {
    final start = state.remoteLoadedCount;
    final end = math.min(start + pageSize, state.remoteUrls.length);
    final page = state.remoteUrls.sublist(start, end);

    if (page.isEmpty) {
      // Nothing left to download (e.g. the bucket is genuinely empty,
      // or we're exactly caught up) — a real "no more presets" state,
      // not a failure.
      emit(
        state.copyWith(
          remoteFetchAttempted: true,
          remoteFetchFailed: false,
          isLoadingMoreRemote: false,
        ),
      );
      return;
    }

    emit(state.copyWith(isLoadingMoreRemote: true));

    // Downloaded in parallel rather than one-by-one — with 100+
    // presets, awaiting each download in sequence is what made the
    // whole thing feel slow in the first place.
    final results = await Future.wait(
      page.map((url) async {
        try {
          final path = await remoteDataSource.downloadAndCache(url);
          return MapEntry(url, path);
        } catch (error, stackTrace) {
          // One bad file shouldn't drop the rest of the page — log it
          // and just leave it out.
          developer.log(
            'Failed to download/cache background preset: $url',
            name: 'BackgroundPickerBloc',
            error: error,
            stackTrace: stackTrace,
          );
          return null;
        }
      }),
    );

    final newEntries = {
      for (final e in results.whereType<MapEntry<String, String>>())
        e.key: e.value,
    };
    final mergedEntries = {...state.remoteByUrl, ...newEntries};

    // Only a genuinely first batch — nothing shown before it, no
    // cache, no prior page — failing outright counts as a hard
    // failure worth a retry UI. A later page failing just means the
    // grid quietly stops growing for now, logged for us to
    // investigate.
    final isFirstEverBatch = start == 0 && state.remoteByUrl.isEmpty;
    final failed = isFirstEverBatch && newEntries.isEmpty;

    emit(
      state.copyWith(
        remoteByUrl: mergedEntries,
        remoteLoadedCount: end,
        remoteFetchAttempted: true,
        remoteFetchFailed: failed,
        isLoadingMoreRemote: false,
      ),
    );

    if (persistAsSeed && newEntries.isNotEmpty) {
      try {
        await cacheDataSource.savePresets([
          for (final entry in mergedEntries.entries.take(_seedCacheSize))
            CachedBackgroundPreset(url: entry.key, localPath: entry.value),
        ]);
      } catch (error, stackTrace) {
        // Failing to persist the seed isn't fatal to this session —
        // the presets are already downloaded and showing — but it
        // does mean the next cold, offline open won't have them.
        developer.log(
          'Failed to persist offline background preset cache',
          name: 'BackgroundPickerBloc',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }
  }
}