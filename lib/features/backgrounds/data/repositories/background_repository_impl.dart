// lib/features/backgrounds/data/repositories/background_repository_impl.dart

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/repositories/background_repository.dart';
import '../datasources/background_cache_data_source.dart';
import '../datasources/supabase_background_data_source.dart';

/// Implements [BackgroundRepository]: Supabase for the catalog and
/// downloads, a small local cache for the catalog, and Failure
/// conversion so nothing above this layer needs a try/catch.
///
/// Register as a lazy singleton: the in-flight request tracking below
/// is per instance.
class BackgroundRepositoryImpl implements BackgroundRepository {
  BackgroundRepositoryImpl({
    required this._remote,
    required this._cache,
  });

  final SupabaseBackgroundDataSource _remote;
  final BackgroundCacheDataSource _cache;

  /// How long the cached URL list is trusted without asking Supabase.
  /// Presets change rarely; after this the cached list is still shown
  /// instantly and refreshed in the background.
  static const Duration _catalogTtl = Duration(hours: 6);

  Future<Either<Failure, List<String>>>? _inFlightRefresh;
  final Map<String, Future<Either<Failure, String>>> _inFlightDownloads = {};

  @override
  Future<BackgroundCatalog?> readCachedCatalog() async {
    final cached = await _cache.read();
    if (cached == null) return null;
    return BackgroundCatalog(
      urls: cached.urls,
      isFresh: DateTime.now().difference(cached.fetchedAt) < _catalogTtl,
    );
  }

  @override
  Future<Either<Failure, List<String>>> refreshCatalog() {
    return _inFlightRefresh ??= _refresh().whenComplete(() {
      _inFlightRefresh = null;
    });
  }

  Future<Either<Failure, List<String>>> _refresh() async {
    final stopwatch = Stopwatch()..start();
    try {
      final urls = await _remote.listPresetUrls();
      _log('listed ${urls.length} preset(s) in ${stopwatch.elapsedMilliseconds} ms');

      try {
        await _cache.save(urls);
      } catch (error) {
        _log('could not persist catalog: $error');
      }
      return Right(urls);
    } catch (error) {
      _log('listing failed: $error');
      return Left(NetworkFailure('Failed to load backgrounds: $error'));
    }
  }

  @override
  Future<Either<Failure, String>> downloadPreset(String url) {
    // NOTE: the callback must use a block body. `Map.remove` returns the
    // very Future stored in the map, and `whenComplete` waits for a
    // Future returned by its callback — an arrow body here would make
    // the download wait on itself forever.
    return _inFlightDownloads[url] ??= _download(url).whenComplete(() {
      _inFlightDownloads.remove(url);
    });
  }

  Future<Either<Failure, String>> _download(String url) async {
    final stopwatch = Stopwatch()..start();
    try {
      final path = await _remote.downloadPreset(url);
      _log('downloaded ${url.split('/').last} in ${stopwatch.elapsedMilliseconds} ms');
      return Right(path);
    } catch (error) {
      _log('download failed for ${url.split('/').last}: $error');
      return Left(NetworkFailure('Failed to download background: $error'));
    }
  }

  @override
  Future<void> prefetch() async {
    final cached = await readCachedCatalog();
    if (cached != null && cached.isFresh) return;
    await refreshCatalog();
  }

  /// `debugPrint` so it always appears in the `flutter run` console
  /// (debug builds only).
  void _log(String message) {
    if (kDebugMode) debugPrint('[Backgrounds] $message');
  }
}