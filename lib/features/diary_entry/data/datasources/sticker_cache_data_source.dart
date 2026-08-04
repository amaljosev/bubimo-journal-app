// lib/features/diary_entry/data/datasources/sticker_cache_data_source.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A single sticker that's been downloaded and is safe to use offline.
class CachedSticker {
  final String url;
  final String localPath;

  const CachedSticker({required this.url, required this.localPath});

  Map<String, dynamic> toJson() => {'url': url, 'localPath': localPath};

  factory CachedSticker.fromJson(Map<String, dynamic> json) {
    return CachedSticker(
      url: json['url'] as String,
      localPath: json['localPath'] as String,
    );
  }
}

/// The persisted offline seed: one category's worth of downloaded
/// stickers, plus which category they belong to.
class CachedStickerSeed {
  final String category;
  final List<CachedSticker> stickers;

  const CachedStickerSeed({required this.category, required this.stickers});

  Map<String, dynamic> toJson() => {
        'category': category,
        'stickers': stickers.map((s) => s.toJson()).toList(),
      };

  factory CachedStickerSeed.fromJson(Map<String, dynamic> json) {
    return CachedStickerSeed(
      category: json['category'] as String,
      stickers: (json['stickers'] as List)
          .map((e) => CachedSticker.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Persists metadata for the offline sticker seed — unlike
/// [BackgroundPresetCacheDataSource]'s flat "first N" cap, stickers are
/// organized into categories (Supabase Storage subfolders), so the
/// natural seed unit here is "every sticker in the first category",
/// not an arbitrary item count. See [StickerPickerBloc]'s
/// `_seedCategoryCap` for the one safety limit that still applies (in
/// case that first category turns out to be huge).
abstract class StickerCacheDataSource {
  /// Never throws — an unreadable or corrupted cache is treated as
  /// "nothing cached yet" so a bad file can never break the picker.
  /// Returns null if no seed has been persisted yet.
  Future<CachedStickerSeed?> getCachedSeed();

  /// Replaces the persisted seed with [seed].
  Future<void> saveSeed(CachedStickerSeed seed);
}

/// Default [StickerCacheDataSource]: one small JSON file in the app's
/// support directory — same approach as
/// `JsonFileBackgroundPresetCacheDataSource`, for consistency between
/// the two pickers. If you've since moved the background preset cache
/// onto `AppDatabase` (or another local database), do the same here
/// instead; nothing outside this file needs to change either way.
class JsonFileStickerCacheDataSource implements StickerCacheDataSource {
  static const String _fileName = 'sticker_cache.json';

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  @override
  Future<CachedStickerSeed?> getCachedSeed() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;

      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return CachedStickerSeed.fromJson(decoded);
    } catch (error, stackTrace) {
      developer.log(
        'Sticker cache file unreadable — treating as empty',
        name: 'JsonFileStickerCacheDataSource',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<void> saveSeed(CachedStickerSeed seed) async {
    final file = await _cacheFile();
    await file.writeAsString(jsonEncode(seed.toJson()));
  }
}