// lib/features/backgrounds/data/datasources/supabase_background_data_source.dart

import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/supabase_storage_asset_service.dart';
import '../../../../core/storage/media_storage_service.dart';

/// Raw Supabase Storage + local file access for background presets.
/// No error wrapping — exceptions propagate to
/// `BackgroundRepositoryImpl`, which converts them to `Failure`s.
///
/// Presets live in the public `assets` bucket under `bg_presets/`.
/// Lists through [SupabaseClient] directly (like the sticker data
/// source); downloads through [SupabaseStorageAssetService] (like
/// stickers) so files land in durable app media storage.
class SupabaseBackgroundDataSource {
  SupabaseBackgroundDataSource(this._supabase, this._assetService);

  final SupabaseClient _supabase;
  final SupabaseStorageAssetService _assetService;

  static const String _bucket = 'assets';
  static const String _folder = 'bg_presets';

  static const int _pageSize = 100;
  static const Duration _listTimeout = Duration(seconds: 20);

  static const List<String> _supportedExtensions = [
    '.webp',
    '.png',
    '.jpg',
    '.jpeg',
  ];

  /// Lists every preset's public URL, paging through the folder with an
  /// explicit offset (a single call returns at most [_pageSize] items).
  /// Folders / placeholder entries are ignored by the extension filter.
  Future<List<String>> listPresetUrls() async {
    final storage = _supabase.storage.from(_bucket);
    final names = <String>[];

    var offset = 0;
    while (true) {
      final files = await storage
          .list(
            path: _folder,
            searchOptions: SearchOptions(limit: _pageSize, offset: offset),
          )
          .timeout(_listTimeout);

      names.addAll(files.map((f) => f.name).where(_isSupportedImage));

      if (files.length < _pageSize) break;
      offset += _pageSize;
    }

    names.sort(_compareNames);
    return [for (final name in names) storage.getPublicUrl('$_folder/$name')];
  }

  /// Downloads [url] into the app's durable media storage
  /// ([MediaCategory.downloadedBackgrounds] — the folder
  /// `DiaryEntry.bgLocalPath` is expected to live in, covered by backup
  /// and cleanup) and returns the local path. Same mechanism stickers
  /// use. Skips the download if the file already exists.
  ///
  /// The URL must point into our own bucket folder (same scheme/host)
  /// before anything is fetched or written.
  Future<String> downloadPreset(String url) async {
    final uri = Uri.parse(url);
    if (!_isTrustedPresetUri(uri)) {
      throw const FormatException('Untrusted background preset URL');
    }
    _safeFileName(uri); // validates the file name, throws if invalid

    final path = await _assetService.downloadAndCache(
      url,
      MediaCategory.downloadedBackgrounds,
    );
    if (path.isEmpty || !await File(path).exists()) {
      throw FileSystemException('Background was not saved locally', path);
    }
    return path;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  bool _isSupportedImage(String name) {
    final lower = name.toLowerCase();
    return _supportedExtensions.any(lower.endsWith);
  }

  /// Only URLs inside this exact bucket folder (same scheme + host) are
  /// downloaded.
  bool _isTrustedPresetUri(Uri uri) {
    final base = Uri.parse(
      _supabase.storage.from(_bucket).getPublicUrl(_folder),
    );
    return uri.scheme == base.scheme &&
        uri.host == base.host &&
        uri.path.startsWith('${base.path}/');
  }

  String _safeFileName(Uri uri) {
    final name = uri.pathSegments.isEmpty ? '' : uri.pathSegments.last;
    final invalid =
        name.isEmpty ||
        name.contains('/') ||
        name.contains('\\') ||
        name.contains('..') ||
        !_isSupportedImage(name);
    if (invalid) {
      throw FormatException('Invalid background file name: "$name"');
    }
    return name;
  }

  /// Natural order, so `2.webp` comes before `10.webp`. Numbered names
  /// first, then everything else alphabetically.
  static int _compareNames(String a, String b) {
    final na = int.tryParse(_stem(a));
    final nb = int.tryParse(_stem(b));
    if (na != null && nb != null) return na.compareTo(nb);
    if (na != null) return -1;
    if (nb != null) return 1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  static String _stem(String name) {
    final dot = name.lastIndexOf('.');
    return dot < 0 ? name : name.substring(0, dot);
  }
}