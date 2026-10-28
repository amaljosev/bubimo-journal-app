// lib/core/services/supabase_storage_asset_service.dart

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../storage/media_storage_service.dart';

/// Generic helper for listing and caching files from a folder inside
/// the app's single Supabase Storage bucket. Shared by the backgrounds
/// feature (`bg_presets` folder) and the rich editor's sticker picker
/// (`stickers` folder) — both need the same "list remote files, download
/// once, cache locally forever" behavior.
class SupabaseStorageAssetService {
  final SupabaseClient supabaseClient;
  final MediaStorageService mediaStorageService;

  const SupabaseStorageAssetService(
    this.supabaseClient,
    this.mediaStorageService,
  );

  static const String bucketName = 'assets';

  /// Lists public URLs for every file in [folder] within the `assets`
  /// bucket. Throws if offline or the request fails — callers should
  /// catch this and fall back to local-only assets, not treat it as
  /// fatal, since the app is offline-first.
  Future<List<String>> listPublicUrls(String folder) async {
    final files = await supabaseClient.storage.from(bucketName).list(
          path: folder,
        );

    return files
        .where((file) => file.name.isNotEmpty && !file.name.startsWith('.'))
        .map(
          (file) => supabaseClient.storage
              .from(bucketName)
              .getPublicUrl('$folder/${file.name}'),
        )
        .toList();
  }

  /// Downloads the file at [url] and caches it via [MediaStorageService]
  /// under [category], returning the durable local path. Skips the
  /// download if already cached from a previous fetch.
  ///
  /// The file is stored under its remote file name (e.g. `3.webp`) and
  /// looked up by that exact name, so the same URL always maps to the
  /// same local file and never to a different one.
  ///
  /// Previously wrote directly to
  /// `<app documents>/<cacheSubfolder>/` via raw `dart:io`, bypassing
  /// [MediaStorageService] entirely — same underlying issue as every
  /// other picker/download call site (see
  /// `media_storage_service.dart`'s doc comment): a file saved outside
  /// the app's single tracked media root can't be reliably found by a
  /// future backup/export pass, since export only walks
  /// [MediaStorageService.mediaRoot]. Routing through [saveBytes] here
  /// means downloaded background presets are included in a `.bubimo`
  /// export like every other category, with no separate case needed in
  /// `BackupLocalDataSource`.
  Future<String> downloadAndCache(
    String url,
    MediaCategory category,
  ) async {
    final fileName = Uri.parse(url).pathSegments.last;
    final existing = await mediaStorageService.findExistingByFileName(
      fileName,
      category: category,
    );
    if (existing != null) return existing;

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception(
        'Failed to download $url: HTTP ${response.statusCode}',
      );
    }

    return mediaStorageService.saveBytes(
      response.bodyBytes,
      category: category,
      extension: _extensionFromFileName(fileName),
      fileName: fileName,
    );
  }

  String _extensionFromFileName(String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    return dotIndex == -1 ? '' : fileName.substring(dotIndex);
  }
}