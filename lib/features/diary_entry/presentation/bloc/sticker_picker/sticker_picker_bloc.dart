// lib/features/diary_entry/presentation/bloc/sticker_picker/sticker_picker_bloc.dart
//
// Reconstructed around the confirmed constructor shape from
// injection.dart (`StickerPickerBloc(stickerRepository: ...)`) plus
// the event/state usage in sticker_picker_sheet.dart and
// diary_form_page.dart. I don't have your actual current file to diff
// against — please sanity-check this against it (or share it) before
// dropping it in, in case there's bloc logic here beyond what those
// two call sites exercise.

import 'dart:developer' as developer;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/datasources/sticker_cache_data_source.dart';
import '../../../domain/repositories/sticker_repository.dart';
import 'sticker_picker_event.dart';
import 'sticker_picker_state.dart';

/// How many stickers to download from the first category to seed the
/// offline cache. Categories aren't capped anywhere else (Supabase
/// Storage listing already paginates through an entire category), so
/// this is purely a safety valve in case that first category turns
/// out to be huge — without it, a 300-sticker category would mean
/// downloading 300 files before the picker ever opens for the first
/// time.
const int _seedCategoryCap = 40;

/// Drives the sticker picker.
///
/// Loading order, on every open:
/// 1. The persisted offline seed (see [StickerCacheDataSource]) — one
///    category's stickers, already downloaded. If one exists, shown
///    immediately as a single tab, no spinner.
/// 2. A Supabase category listing, to get the full picture — in the
///    background if step 1 already put something on screen, or as
///    the actual (spinner-visible) first load if it didn't.
/// 3. On a cold start only (no seed yet), the first category from
///    that listing is downloaded and persisted as the new seed.
///    Every other category stays browse-only (thumbnails straight
///    from their Supabase URLs) until something in it is actually
///    selected — same as before this change.
class StickerPickerBloc
    extends Bloc<StickerPickerEvent, StickerPickerState> {
  final StickerRepository stickerRepository;
  final StickerCacheDataSource cacheDataSource;

  StickerPickerBloc({
    required this.stickerRepository,
    required this.cacheDataSource,
  }) : super(const StickerPickerState()) {
    on<StickerPickerRequested>(_onRequested);
    on<StickerPickerRetried>(_onRetried);
    on<StickerSelected>(_onSelected);
  }

  Future<void> _onRequested(
    StickerPickerRequested event,
    Emitter<StickerPickerState> emit,
  ) async {
    final seed = await cacheDataSource.getCachedSeed();
    final hadCache = seed != null && seed.stickers.isNotEmpty;

    if (hadCache) {
      emit(
        state.copyWith(
          seededCategory: seed.category,
          downloadedByUrl: {for (final s in seed.stickers) s.url: s.localPath},
        ),
      );
    }

    await _syncCategories(emit, hadCache: hadCache);
  }

  Future<void> _onRetried(
    StickerPickerRetried event,
    Emitter<StickerPickerState> emit,
  ) async {
    // "Try again" only ever shows when the previous attempt left
    // nothing on screen (see the `hadCache` gate on categoriesError
    // below), so this always re-runs as a fresh, no-cache attempt.
    await _syncCategories(emit, hadCache: false);
  }

  Future<void> _syncCategories(
    Emitter<StickerPickerState> emit, {
    required bool hadCache,
  }) async {
    if (hadCache) {
      emit(state.copyWith(isSyncingCategories: true));
    } else {
      emit(
        state.copyWith(
          isLoadingCategories: true,
          clearCategoriesError: true,
        ),
      );
    }

    final result = await stickerRepository.getStickersByCategory();

    await result.match(
      (failure) async {
        developer.log(
          'Failed to list sticker categories',
          name: 'StickerPickerBloc',
          error: failure.message,
        );
        // No seed and the listing failed: a genuine failure, shown
        // with a retry. With a seed: still fully browsable offline —
        // just quietly stop the "checking for more" indicator.
        emit(
          hadCache
              ? state.copyWith(isSyncingCategories: false)
              : state.copyWith(
                  isLoadingCategories: false,
                  categoriesError: failure.message,
                ),
        );
      },
      (categoryUrls) async {
        emit(
          state.copyWith(
            categoryUrls: categoryUrls,
            isLoadingCategories: false,
            isSyncingCategories: false,
          ),
        );

        if (!hadCache && categoryUrls.isNotEmpty) {
          await _seedFirstCategory(emit, categoryUrls);
        }
      },
    );
  }

  /// Downloads (in parallel) up to [_seedCategoryCap] stickers from
  /// whichever category the Supabase listing returned first, and
  /// persists them as the new offline seed. Failing to seed isn't
  /// fatal — every category, including this one, is still fully
  /// browsable over the network via `state.categoryUrls` regardless;
  /// this only ever adds the "also works offline" guarantee on top.
  Future<void> _seedFirstCategory(
    Emitter<StickerPickerState> emit,
    Map<String, List<String>> categoryUrls,
  ) async {
    final firstCategory = categoryUrls.keys.first;
    final urls = categoryUrls[firstCategory]!.take(_seedCategoryCap).toList();
    if (urls.isEmpty) return;

    final results = await Future.wait(
      urls.map((url) async {
        final downloadResult = await stickerRepository.downloadSticker(url);
        return downloadResult.match(
          (failure) {
            developer.log(
              'Failed to seed-download sticker: $url',
              name: 'StickerPickerBloc',
              error: failure.message,
            );
            return null;
          },
          (localPath) => MapEntry(url, localPath),
        );
      }),
    );

    final newEntries = {
      for (final e in results.whereType<MapEntry<String, String>>())
        e.key: e.value,
    };
    if (newEntries.isEmpty) return;

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
      // Not fatal to this session — the stickers are already
      // downloaded and showing — but the next cold, offline open
      // won't have them.
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