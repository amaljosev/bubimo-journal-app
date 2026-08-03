// lib/features/backgrounds/data/datasources/background_preset_cache_data_source.dart

import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A single background preset that's been downloaded and is safe to
/// use offline: the Supabase URL it came from (its stable identity —
/// used as the ded up/lookup key) and the durable local file path it
/// was cached to.
class CachedBackgroundPreset {
  final String url;
  final String localPath;

  const CachedBackgroundPreset({required this.url, required this.localPath});

  Map<String, dynamic> toJson() => {'url': url, 'localPath': localPath};

  factory CachedBackgroundPreset.fromJson(Map<String, dynamic> json) {
    return CachedBackgroundPreset(
      url: json['url'] as String,
      localPath: json['localPath'] as String,
    );
  }
}

/// Persists metadata for the small "always available offline" seed
/// set of background presets — NOT the full Supabase catalog, just
/// however many [BackgroundPickerBloc] decides to keep around for
/// guaranteed offline access (see its `_seedCacheSize`).
///
/// Deliberately a narrow "get everything / replace everything"
/// interface rather than incremental add/remove methods — the seed
/// set is small (currently 10 entries) and always rewritten as a
/// whole, so callers don't need anything more granular.
abstract class BackgroundPresetCacheDataSource {
  /// Never throws — an unreadable or corrupted cache is treated the
  /// same as "nothing cached yet" so a bad file can never break the
  /// picker; [BackgroundPickerBloc] just falls back to a normal
  /// network fetch.
  Future<List<CachedBackgroundPreset>> getCachedPresets();

  /// Replaces the entire persisted set with [presets].
  Future<void> savePresets(List<CachedBackgroundPreset> presets);
}

/// Default [BackgroundPresetCacheDataSource]: one small JSON file in
/// the app's support directory.
///
/// This is a reasonable-default guess, not a confirmed fit for this
/// codebase — if there's already a local database (sqflite, drift,
/// Hive, Isar, ...) used elsewhere for offline data, swap this
/// implementation out for one backed by that instead. Nothing outside
/// this file needs to change either way: `BackgroundPickerBloc` only
/// depends on the abstract interface above.
class JsonFileBackgroundPresetCacheDataSource
    implements BackgroundPresetCacheDataSource {
  static const String _fileName = 'background_preset_cache.json';

  Future<File> _cacheFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  @override
  Future<List<CachedBackgroundPreset>> getCachedPresets() async {
    try {
      final file = await _cacheFile();
      if (!await file.exists()) return const [];

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return const [];

      final decoded = jsonDecode(raw) as List;
      return decoded
          .map(
            (e) => CachedBackgroundPreset.fromJson(e as Map<String, dynamic>),
          )
          .toList();
    } catch (error, stackTrace) {
      developer.log(
        'Background preset cache file unreadable — treating as empty',
        name: 'JsonFileBackgroundPresetCacheDataSource',
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  @override
  Future<void> savePresets(List<CachedBackgroundPreset> presets) async {
    final file = await _cacheFile();
    final encoded = jsonEncode(presets.map((p) => p.toJson()).toList());
    await file.writeAsString(encoded);
  }
}