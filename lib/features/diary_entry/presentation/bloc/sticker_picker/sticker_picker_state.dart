// lib/features/diary_entry/presentation/bloc/sticker_picker/sticker_picker_state.dart
//
// Reconstructed from how these fields are read in
// sticker_picker_sheet.dart and diary_form_page.dart (isLoadingCategories,
// categoriesError, stickersByCategory, isDownloading, downloadError,
// lastDownloaded.url/.localPath) — I don't have your actual current
// file, so please diff this against it (or share it) rather than
// assuming a silent match; there may be fields in your real file this
// doesn't know about.

import 'package:equatable/equatable.dart';

/// A single sticker as the picker grid renders it: always has a URL;
/// has a local path only once downloaded — from the persisted offline
/// seed, or from a background/foreground download. Tiles with a null
/// [localPath] render via `CachedNetworkImage(imageUrl: url)`; tiles
/// with one render via `Image.file(File(localPath))`.
class StickerPickerItem extends Equatable {
  final String url;
  final String? localPath;

  const StickerPickerItem({required this.url, this.localPath});

  @override
  List<Object?> get props => [url, localPath];
}

/// A sticker that's just finished downloading via [StickerSelected] —
/// unchanged from before this reconstruction, just named explicitly
/// here since it needs a concrete type.
class DownloadedSticker extends Equatable {
  final String url;
  final String localPath;

  const DownloadedSticker({required this.url, required this.localPath});

  @override
  List<Object?> get props => [url, localPath];
}

class StickerPickerState extends Equatable {
  /// True only while there's *nothing* to show yet and a fetch is in
  /// flight — the one-time, full-sheet loading spinner. Never true
  /// again after the picker's first paint if a seed was available.
  final bool isLoadingCategories;

  /// Non-null only when there's nothing at all to show — no offline
  /// seed, and the Supabase listing failed too.
  final String? categoriesError;

  /// True while checking Supabase for the full category list in the
  /// background — i.e. a seed was already shown, so this drives a
  /// small, non-blocking indicator only, never the full-sheet spinner.
  final bool isSyncingCategories;

  /// The one category that's been downloaded and persisted for
  /// offline use. Null until known — either read back from the cache,
  /// or set once `_seedFirstCategory` finishes on a first-ever run.
  final String? seededCategory;

  /// url -> local path, for every sticker downloaded so far: the
  /// persisted seed for [seededCategory] to start, unchanged
  /// afterward (later categories are browsed straight from their
  /// Supabase URLs, not downloaded until individually selected).
  final Map<String, String> downloadedByUrl;

  /// category -> ordered URL list, once known from Supabase. Empty
  /// until that first listing completes.
  final Map<String, List<String>> categoryUrls;

  final bool isDownloading;
  final String? downloadError;
  final DownloadedSticker? lastDownloaded;

  const StickerPickerState({
    this.isLoadingCategories = false,
    this.categoriesError,
    this.isSyncingCategories = false,
    this.seededCategory,
    this.downloadedByUrl = const {},
    this.categoryUrls = const {},
    this.isDownloading = false,
    this.downloadError,
    this.lastDownloaded,
  });

  /// What the UI actually renders: category -> ordered list of items,
  /// each carrying a local path wherever [downloadedByUrl] has one.
  /// Before the first Supabase listing completes, this is just the
  /// persisted seed category (if any); afterward, it's every known
  /// category, with the seed's local paths preserved rather than
  /// dropped once the fuller picture arrives.
  Map<String, List<StickerPickerItem>> get stickersByCategory {
    if (categoryUrls.isNotEmpty) {
      return {
        for (final entry in categoryUrls.entries)
          entry.key: [
            for (final url in entry.value)
              StickerPickerItem(url: url, localPath: downloadedByUrl[url]),
          ],
      };
    }
    if (seededCategory != null && downloadedByUrl.isNotEmpty) {
      return {
        seededCategory!: [
          for (final entry in downloadedByUrl.entries)
            StickerPickerItem(url: entry.key, localPath: entry.value),
        ],
      };
    }
    return const {};
  }

  StickerPickerState copyWith({
    bool? isLoadingCategories,
    String? categoriesError,
    bool clearCategoriesError = false,
    bool? isSyncingCategories,
    String? seededCategory,
    Map<String, String>? downloadedByUrl,
    Map<String, List<String>>? categoryUrls,
    bool? isDownloading,
    String? downloadError,
    bool clearDownloadError = false,
    DownloadedSticker? lastDownloaded,
  }) {
    return StickerPickerState(
      isLoadingCategories: isLoadingCategories ?? this.isLoadingCategories,
      categoriesError: clearCategoriesError
          ? null
          : (categoriesError ?? this.categoriesError),
      isSyncingCategories: isSyncingCategories ?? this.isSyncingCategories,
      seededCategory: seededCategory ?? this.seededCategory,
      downloadedByUrl: downloadedByUrl ?? this.downloadedByUrl,
      categoryUrls: categoryUrls ?? this.categoryUrls,
      isDownloading: isDownloading ?? this.isDownloading,
      downloadError: clearDownloadError
          ? null
          : (downloadError ?? this.downloadError),
      lastDownloaded: lastDownloaded ?? this.lastDownloaded,
    );
  }

  @override
  List<Object?> get props => [
        isLoadingCategories,
        categoriesError,
        isSyncingCategories,
        seededCategory,
        downloadedByUrl,
        categoryUrls,
        isDownloading,
        downloadError,
        lastDownloaded,
      ];
}