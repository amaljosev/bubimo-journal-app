// lib/features/backgrounds/domain/repositories/background_repository.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';

/// The list of background preset URLs, as last known.
class BackgroundCatalog {
  /// Public Supabase URLs, in display order.
  final List<String> urls;

  /// True while the list is recent enough that no network call is
  /// needed to trust it.
  final bool isFresh;

  const BackgroundCatalog({required this.urls, required this.isFresh});
}

/// Access to the shared background preset library.
///
/// Presets are *browsed* by URL (thumbnails are loaded and disk-cached
/// by the image widget) and only *downloaded* to a durable local file
/// once the user actually picks one — that file path is what gets
/// stored on the diary entry.
abstract class BackgroundRepository {
  /// The cached URL list (memory, then disk), or null if none exists.
  /// Never touches the network and never throws.
  Future<BackgroundCatalog?> readCachedCatalog();

  /// Lists the presets from Supabase, caches a non-empty result and
  /// returns it. Concurrent calls share one request.
  Future<Either<Failure, List<String>>> refreshCatalog();

  /// Downloads [url] to the local preset folder and returns the file
  /// path. Returns the existing file without a request if already
  /// downloaded.
  Future<Either<Failure, String>> downloadPreset(String url);

  /// Warms the URL list in the background (no-op when it is fresh).
  /// Call when the diary form opens. Never throws.
  Future<void> prefetch();
}