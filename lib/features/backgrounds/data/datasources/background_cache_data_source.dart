// lib/features/backgrounds/data/datasources/background_cache_data_source.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// The persisted list of preset URLs and when it was fetched.
class CachedBackgroundCatalog {
  final List<String> urls;
  final DateTime fetchedAt;

  const CachedBackgroundCatalog({required this.urls, required this.fetchedAt});

  Map<String, dynamic> toJson() => {
    'fetchedAt': fetchedAt.toIso8601String(),
    'urls': urls,
  };

  factory CachedBackgroundCatalog.fromJson(Map<String, dynamic> json) {
    return CachedBackgroundCatalog(
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
      urls: (json['urls'] as List).map((e) => e as String).toList(),
    );
  }
}

/// Local persistence for the preset URL list, so the picker can open
/// instantly without a Supabase listing call.
abstract class BackgroundCacheDataSource {
  /// Never throws: a missing or corrupted cache is simply `null`.
  Future<CachedBackgroundCatalog?> read();

  /// Replaces the cached list. Empty lists are ignored on purpose: a
  /// wrong storage policy makes Supabase return `[]` instead of an
  /// error, and caching that would hide every preset until it expired.
  Future<void> save(List<String> urls);
}

/// One small JSON file in the app support directory, plus an in-memory
/// copy so re-opening the picker never touches the disk.
///
/// Register as a lazy singleton so the memory copy is shared.
class JsonFileBackgroundCacheDataSource implements BackgroundCacheDataSource {
  static const String _fileName = 'background_catalog.json';

  CachedBackgroundCatalog? _memory;

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  @override
  Future<CachedBackgroundCatalog?> read() async {
    final inMemory = _memory;
    if (inMemory != null) return inMemory;

    try {
      final file = await _file();
      if (!await file.exists()) return null;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;

      final catalog = CachedBackgroundCatalog.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (catalog.urls.isEmpty) return null;

      _memory = catalog;
      return catalog;
    } catch (error, stackTrace) {
      developer.log(
        'Background catalog cache unreadable — treating as empty',
        name: 'JsonFileBackgroundCacheDataSource',
        error: error,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  @override
  Future<void> save(List<String> urls) async {
    if (urls.isEmpty) return;

    final catalog = CachedBackgroundCatalog(
      urls: List.unmodifiable(urls),
      fetchedAt: DateTime.now(),
    );
    // Memory first, so the next open benefits even if the write fails.
    _memory = catalog;

    // Temp file + rename: a crash mid-write can't leave a corrupt file.
    final file = await _file();
    final tmp = File('${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp');
    try {
      await tmp.writeAsString(jsonEncode(catalog.toJson()), flush: true);
      await tmp.rename(file.path);
    } finally {
      if (await tmp.exists()) {
        await tmp.delete();
      }
    }
  }
}