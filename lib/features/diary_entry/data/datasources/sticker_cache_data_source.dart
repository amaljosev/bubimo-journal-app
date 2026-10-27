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

/// The persisted *catalog*: category -> ordered sticker URLs, as returned
/// by the (expensive) Supabase Storage listing, plus when it was fetched.
///
/// This is what removes the repeated API calls. The listing costs one
/// `list()` call for the root folder plus at least one more per category
/// (more with pagination), so it must not run every time the sheet opens.
/// Instead the catalog is cached in memory + on disk and only re-fetched
/// once it is older than a TTL (see `_manifestTtl` in
/// `StickerPickerBloc`).
class CachedStickerManifest {
  final Map<String, List<String>> categoryUrls;
  final DateTime fetchedAt;

  const CachedStickerManifest({
    required this.categoryUrls,
    required this.fetchedAt,
  });

  bool isFresh(Duration ttl) => DateTime.now().difference(fetchedAt) < ttl;

  Map<String, dynamic> toJson() => {
        'fetchedAt': fetchedAt.toIso8601String(),
        'categories': categoryUrls,
      };

  factory CachedStickerManifest.fromJson(Map<String, dynamic> json) {
    final raw = json['categories'] as Map<String, dynamic>;
    return CachedStickerManifest(
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      categoryUrls: {
        for (final entry in raw.entries)
          entry.key: (entry.value as List).map((e) => e as String).toList(),
      },
    );
  }
}

/// Persists metadata for the offline sticker seed and the sticker
/// catalog (manifest).
abstract class StickerCacheDataSource {
  /// Never throws — an unreadable or corrupted cache is treated as
  /// "nothing cached yet" so a bad file can never break the picker.
  /// Returns null if no seed has been persisted yet.
  Future<CachedStickerSeed?> getCachedSeed();

  /// Replaces the persisted seed with [seed].
  Future<void> saveSeed(CachedStickerSeed seed);

  /// Never throws. Returns the cached catalog (memory first, then disk),
  /// or null if none exists / it is unreadable.
  Future<CachedStickerManifest?> getCachedManifest();

  /// Replaces the cached catalog. Empty maps are ignored on purpose: a
  /// misconfigured RLS policy makes Supabase Storage return `[]` instead
  /// of an error, and caching that would hide stickers until the TTL
  /// expired.
  Future<void> saveManifest(Map<String, List<String>> categoryUrls);
}

/// Default [StickerCacheDataSource]: small JSON files in the app's
/// support directory, plus a process-wide in-memory copy of the manifest
/// so re-opening the sheet within one app session never touches the disk
/// or the network.
class JsonFileStickerCacheDataSource implements StickerCacheDataSource {
  static const String _fileName = 'sticker_cache.json';
  static const String _manifestFileName = 'sticker_manifest.json';

  /// Static on purpose: it survives even if the DI container creates a
  /// new instance of this class each time (factory registration).
  static CachedStickerManifest? _memoryManifest;

  Future<File> _file(String name) async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$name');
  }

  @override
  Future<CachedStickerSeed?> getCachedSeed() async {
    try {
      final file = await _file(_fileName);
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
    final file = await _file(_fileName);
    await file.writeAsString(jsonEncode(seed.toJson()), flush: true);
  }

  @override
  Future<CachedStickerManifest?> getCachedManifest() async {
    final inMemory = _memoryManifest;
    if (inMemory != null) return inMemory;

    try {
      final file = await _file(_manifestFileName);
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;

      final manifest = CachedStickerManifest.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      _memoryManifest = manifest;
      return manifest;
    } catch (error, stackTrace) {
      developer.log(
        'Sticker manifest unreadable — treating as empty',
        name: 'JsonFileStickerCacheDataSource',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<void> saveManifest(Map<String, List<String>> categoryUrls) async {
    if (categoryUrls.isEmpty) return;

    final manifest = CachedStickerManifest(
      categoryUrls: categoryUrls,
      fetchedAt: DateTime.now(),
    );
    // Memory first: the very next sheet open benefits even if the disk
    // write below is slow or fails.
    _memoryManifest = manifest;

    // Write to a temp file then rename, so a crash mid-write can never
    // leave a half-written (corrupt) manifest behind.
    final file = await _file(_manifestFileName);
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(manifest.toJson()), flush: true);
    await tmp.rename(file.path);
  }
}