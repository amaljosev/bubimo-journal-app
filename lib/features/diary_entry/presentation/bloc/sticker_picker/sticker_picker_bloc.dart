// lib/features/diary_entry/presentation/bloc/sticker_picker/sticker_picker_bloc.dart

import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../../core/error/failures.dart';
import '../../../data/datasources/sticker_cache_data_source.dart';
import '../../../domain/repositories/sticker_repository.dart';
import 'sticker_picker_event.dart';
import 'sticker_picker_state.dart';

/// How many stickers to download from the first category to seed the
/// offline cache (safety valve for a huge first category).
const int _seedCategoryCap = 40;

/// How long the sticker catalog (category -> URLs) counts as fresh.
/// Within this window, opening the sheet makes NO Supabase call at all.
/// After it, the cached catalog is still shown instantly and refreshed
/// quietly in the background (stale-while-revalidate).
///
/// Stickers are admin-managed content that changes rarely, so a few
/// hours is a good trade-off. Raise it if you add stickers seldom.
const Duration _manifestTtl = Duration(hours: 6);

typedef _Listing = Either<Failure, Map<String, List<String>>>;

/// Drives the sticker picker.
///
/// The expensive part is the Supabase Storage *listing* (one call for the
/// root folder + at least one per category). It used to run on every
/// sheet open because each open creates a brand-new bloc with empty
/// state. Now:
///
/// 1. On open, the cached catalog (memory -> disk) is emitted
///    immediately. No spinner, no network.
/// 2. If that catalog is younger than [_manifestTtl], we stop there.
/// 3. If it is older, it is refreshed in the background while the user
///    already sees the stickers (thin progress bar only).
/// 4. Only on a true cold start (no catalog, no seed) is the full-sheet
///    spinner shown, once.
/// 5. [prefetch] can be called earlier (when the diary form opens) so
///    even the cold start is usually hidden.
/// 6. Concurrent listings (prefetch + sheet open) share ONE in-flight
///    request.
class StickerPickerBloc extends Bloc<StickerPickerEvent, StickerPickerState> {
  final StickerRepository stickerRepository;
  final StickerCacheDataSource cacheDataSource;

  StickerPickerBloc({
    required this.stickerRepository,
    required this.cacheDataSource,
  }) : super(const StickerPickerState(isLoadingCategories: true)) {
    // ^ Starts in "loading" so the first frame shows the spinner instead
    //   of flashing "No stickers yet" while the cache is read.
    on<StickerPickerRequested>(_onRequested);
    on<StickerPickerRetried>(_onRetried);
    on<StickerSelected>(_onSelected);
  }

  // ── Shared, de-duplicated listing ────────────────────────────────────────

  static Future<_Listing>? _inFlightListing;

  /// Runs the Supabase listing at most once at a time and persists a
  /// successful, non-empty result. Safe to call from anywhere.
  static Future<_Listing> _fetchAndCache(
    StickerRepository repository,
    StickerCacheDataSource cache,
  ) {
    return _inFlightListing ??= () async {
      try {
        final result = await repository.getStickersByCategory();
        final urls = result.match<Map<String, List<String>>?>(
          (_) => null,
          (value) => value,
        );
        if (urls != null && urls.isNotEmpty) {
          try {
            await cache.saveManifest(urls);
          } catch (error, stackTrace) {
            developer.log(
              'Failed to persist sticker manifest',
              name: 'StickerPickerBloc',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
        return result;
      } finally {
        _inFlightListing = null;
      }
    }();
  }

  /// Warms the catalog cache without any UI. Call it when the diary form
  /// opens so the sticker sheet is instant by the time the user taps the
  /// button. No-ops if the cached catalog is still fresh. Never throws.
  static Future<void> prefetch({
    required StickerRepository stickerRepository,
    required StickerCacheDataSource cacheDataSource,
  }) async {
    try {
      final manifest = await cacheDataSource.getCachedManifest();
      if (manifest != null && manifest.isFresh(_manifestTtl)) return;
      await _fetchAndCache(stickerRepository, cacheDataSource);
    } catch (error, stackTrace) {
      developer.log(
        'Sticker prefetch failed',
        name: 'StickerPickerBloc',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  // ── Events ───────────────────────────────────────────────────────────────

  Future<void> _onRequested(
    StickerPickerRequested event,
    Emitter<StickerPickerState> emit,
  ) async {
    final seed = await cacheDataSource.getCachedSeed();
    final manifest = await cacheDataSource.getCachedManifest();

    final hasSeed = seed != null && seed.stickers.isNotEmpty;
    final hasManifest = manifest != null && manifest.categoryUrls.isNotEmpty;

    if (hasSeed || hasManifest) {
      emit(
        state.copyWith(
          isLoadingCategories: false,
          clearCategoriesError: true,
          seededCategory: hasSeed ? seed.category : null,
          downloadedByUrl: hasSeed
              ? {for (final s in seed.stickers) s.url: s.localPath}
              : null,
          categoryUrls: hasManifest ? manifest.categoryUrls : null,
        ),
      );
    }

    // Fresh catalog: zero network calls. Just make sure the offline seed
    // exists (it is a no-op for returning users).
    if (hasManifest && manifest.isFresh(_manifestTtl)) {
      if (!hasSeed) {
        await _seedFirstCategory(emit, manifest.categoryUrls);
      }
      return;
    }

    await _syncCategories(
      emit,
      hadCache: hasSeed || hasManifest,
      hasSeed: hasSeed,
    );
  }

  Future<void> _onRetried(
    StickerPickerRetried event,
    Emitter<StickerPickerState> emit,
  ) async {
    // "Try again" only shows when nothing was on screen, so this is
    // always a fresh, no-cache attempt.
    await _syncCategories(emit, hadCache: false, hasSeed: false);
  }

  /// [hadCache]: something (seed or catalog) is already on screen, so
  /// this runs silently with only a thin progress bar.
  /// [hasSeed]: the offline sticker files already exist.
  Future<void> _syncCategories(
    Emitter<StickerPickerState> emit, {
    required bool hadCache,
    required bool hasSeed,
  }) async {
    if (hadCache) {
      emit(state.copyWith(isSyncingCategories: true));
    } else {
      emit(
        state.copyWith(isLoadingCategories: true, clearCategoriesError: true),
      );
    }

    final result = await _fetchAndCache(stickerRepository, cacheDataSource);

    // Handled without `await result.match(async ...)` so every `emit`
    // happens while this handler is still running.
    final failure = result.match<Failure?>((f) => f, (_) => null);
    final categoryUrls = result.match<Map<String, List<String>>?>(
      (_) => null,
      (urls) => urls,
    );

    if (failure != null || categoryUrls == null) {
      developer.log(
        'Failed to list sticker categories',
        name: 'StickerPickerBloc',
        error: failure?.message,
      );
      // Nothing on screen: real failure with retry. Something on
      // screen: stay fully usable, just stop the indicator.
      emit(
        hadCache
            ? state.copyWith(isSyncingCategories: false)
            : state.copyWith(
                isLoadingCategories: false,
                categoriesError: failure?.message ?? 'Unknown error',
              ),
      );
      return;
    }

    emit(
      state.copyWith(
        categoryUrls: categoryUrls,
        isLoadingCategories: false,
        isSyncingCategories: false,
      ),
    );

    if (!hasSeed && categoryUrls.isNotEmpty) {
      await _seedFirstCategory(emit, categoryUrls);
    }
  }

  /// Downloads (in parallel) up to [_seedCategoryCap] stickers from the
  /// first category and persists them as the offline seed. Not fatal on
  /// failure: every category is still brows able over the network.
  Future<void> _seedFirstCategory(
    Emitter<StickerPickerState> emit,
    Map<String, List<String>> categoryUrls,
  ) async {
    if (categoryUrls.isEmpty) return;
    final firstCategory = categoryUrls.keys.first;
    final urls = categoryUrls[firstCategory]!.take(_seedCategoryCap).toList();
    if (urls.isEmpty) return;

    final results = await Future.wait(
      urls.map((url) async {
        final downloadResult = await stickerRepository.downloadSticker(url);
        return downloadResult.match((failure) {
          developer.log(
            'Failed to seed-download sticker: $url',
            name: 'StickerPickerBloc',
            error: failure.message,
          );
          return null;
        }, (localPath) => MapEntry(url, localPath));
      }),
    );

    final newEntries = {
      for (final e in results.whereType<MapEntry<String, String>>())
        e.key: e.value,
    };
    if (newEntries.isEmpty || isClosed) return;

    emit(
      state.copyWith(
        seededCategory: firstCategory,
        downloadedByUrl: {...state.downloadedByUrl, ...newEntries},
      ),
    );

    try {
      await cacheDataSource.saveSeed(
        CachedStickerSeed(
          category: firstCategory,
          stickers: [
            for (final entry in newEntries.entries)
              CachedSticker(url: entry.key, localPath: entry.value),
          ],
        ),
      );
    } catch (error, stackTrace) {
      developer.log(
        'Failed to persist offline sticker cache',
        name: 'StickerPickerBloc',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _onSelected(
    StickerSelected event,
    Emitter<StickerPickerState> emit,
  ) async {
    emit(state.copyWith(isDownloading: true, clearDownloadError: true));

    final result = await stickerRepository.downloadSticker(event.url);

    result.match(
      (failure) {
        developer.log(
          'Failed to download selected sticker: ${event.url}',
          name: 'StickerPickerBloc',
          error: failure.message,
        );
        emit(
          state.copyWith(isDownloading: false, downloadError: failure.message),
        );
      },
      (localPath) {
        emit(
          state.copyWith(
            isDownloading: false,
            lastDownloaded: DownloadedSticker(
              url: event.url,
              localPath: localPath,
            ),
          ),
        );
      },
    );
  }
}