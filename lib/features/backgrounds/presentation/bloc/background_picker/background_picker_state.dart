// lib/features/backgrounds/presentation/bloc/background_picker/background_picker_state.dart

import 'package:equatable/equatable.dart';

enum BackgroundPickerStatus {
  /// Nothing to show yet and a load is in flight (cold start only).
  loading,

  /// [BackgroundPickerState.urls] is ready to render (possibly empty).
  ready,

  /// Nothing to show and the load failed.
  failure,
}

/// A preset that has just finished downloading.
class DownloadedPreset extends Equatable {
  final String url;
  final String localPath;

  const DownloadedPreset({required this.url, required this.localPath});

  @override
  List<Object?> get props => [url, localPath];
}

class BackgroundPickerState extends Equatable {
  final BackgroundPickerStatus status;

  /// Public URLs of every preset, in display order. Thumbnails are
  /// loaded from these by the image widget.
  final List<String> urls;

  /// True while a stale list is being refreshed in the background —
  /// drives a thin, non-blocking progress bar only.
  final bool isRefreshing;

  /// The preset currently being downloaded after a tap, if any.
  final String? downloadingUrl;

  /// Set once the tapped preset is on disk; the widget reads it once
  /// and hands the path to the caller.
  final DownloadedPreset? downloaded;

  /// True when the last tap's download failed.
  final bool downloadFailed;

  const BackgroundPickerState({
    this.status = BackgroundPickerStatus.loading,
    this.urls = const [],
    this.isRefreshing = false,
    this.downloadingUrl,
    this.downloaded,
    this.downloadFailed = false,
  });

  BackgroundPickerState copyWith({
    BackgroundPickerStatus? status,
    List<String>? urls,
    bool? isRefreshing,
    String? downloadingUrl,
    bool clearDownloadingUrl = false,
    DownloadedPreset? downloaded,
    bool clearDownloaded = false,
    bool? downloadFailed,
  }) {
    return BackgroundPickerState(
      status: status ?? this.status,
      urls: urls ?? this.urls,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      downloadingUrl: clearDownloadingUrl
          ? null
          : (downloadingUrl ?? this.downloadingUrl),
      downloaded: clearDownloaded ? null : (downloaded ?? this.downloaded),
      downloadFailed: downloadFailed ?? this.downloadFailed,
    );
  }

  @override
  List<Object?> get props => [
    status,
    urls,
    isRefreshing,
    downloadingUrl,
    downloaded,
    downloadFailed,
  ];
}