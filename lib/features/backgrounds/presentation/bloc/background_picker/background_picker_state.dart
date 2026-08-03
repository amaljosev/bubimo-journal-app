// lib/features/backgrounds/presentation/bloc/background_picker/background_picker_state.dart

import 'package:equatable/equatable.dart';

enum BackgroundPickerStatus { initial, loaded }

class BackgroundPickerState extends Equatable {
  final BackgroundPickerStatus status;

  /// Bundled local asset paths — always available offline, shown
  /// immediately without waiting on any network call.
  final List<String> localPresets;

  /// Every Supabase preset URL discovered by the most recent listing
  /// call. Empty until that first succeeds — which, thanks to
  /// [remoteByUrl]'s persisted seed, doesn't have to happen before
  /// anything is shown.
  final List<String> remoteUrls;

  /// url -> durable local path, for every remote preset currently
  /// available to display: the persisted offline seed to start with,
  /// plus whatever's been paged in since. A plain Dart `Map` is a
  /// `LinkedHashMap`, so insertion order is preserved — this doubles
  /// as display order, especially before [remoteUrls] is even known.
  final Map<String, String> remoteByUrl;

  /// How many entries from the front of [remoteUrls] have been
  /// resolved — successfully cached or not — so far. Seeded by
  /// reconciling against the persisted cache before any pagination
  /// happens (see `BackgroundPickerBloc._leadingCachedCount`), then
  /// advances a page at a time from there.
  final int remoteLoadedCount;

  /// True once there's *something* to show — the persisted cache, or
  /// a completed first network fetch — or a first fetch has
  /// definitively failed with nothing to fall back on. Gates the
  /// one-time, full-tab loading spinner; never true-then-false again
  /// after the picker's first paint (a background refetch afterward
  /// uses [isLoadingMoreRemote] instead, never this).
  final bool remoteFetchAttempted;

  /// True only when there's nothing at all to show — no persisted
  /// cache, and the network fetch failed too. Whenever there's a
  /// cache, this stays false even if a later background sync fails;
  /// the cached presets remain fully usable regardless.
  final bool remoteFetchFailed;

  /// True while checking Supabase for more presets — either the
  /// background "any updates?" sync right after a cached seed is
  /// shown, or a scroll-triggered page beyond what's currently loaded.
  /// Drives a small, non-blocking footer indicator only, never the
  /// full-tab spinner.
  final bool isLoadingMoreRemote;

  const BackgroundPickerState({
    this.status = BackgroundPickerStatus.initial,
    this.localPresets = const [],
    this.remoteUrls = const [],
    this.remoteByUrl = const {},
    this.remoteLoadedCount = 0,
    this.remoteFetchAttempted = false,
    this.remoteFetchFailed = false,
    this.isLoadingMoreRemote = false,
  });

  /// The grid's display list, derived from [remoteByUrl] rather than
  /// stored separately — one source of truth for "what's currently on
  /// screen", so it can never drift out of sync with the map.
  List<String> get remotePresets => remoteByUrl.values.toList();

  /// Whether there are more Supabase presets left to page in.
  bool get hasMoreRemote => remoteLoadedCount < remoteUrls.length;

  BackgroundPickerState copyWith({
    BackgroundPickerStatus? status,
    List<String>? localPresets,
    List<String>? remoteUrls,
    Map<String, String>? remoteByUrl,
    int? remoteLoadedCount,
    bool? remoteFetchAttempted,
    bool? remoteFetchFailed,
    bool? isLoadingMoreRemote,
  }) {
    return BackgroundPickerState(
      status: status ?? this.status,
      localPresets: localPresets ?? this.localPresets,
      remoteUrls: remoteUrls ?? this.remoteUrls,
      remoteByUrl: remoteByUrl ?? this.remoteByUrl,
      remoteLoadedCount: remoteLoadedCount ?? this.remoteLoadedCount,
      remoteFetchAttempted: remoteFetchAttempted ?? this.remoteFetchAttempted,
      remoteFetchFailed: remoteFetchFailed ?? this.remoteFetchFailed,
      isLoadingMoreRemote: isLoadingMoreRemote ?? this.isLoadingMoreRemote,
    );
  }

  @override
  List<Object?> get props => [
        status,
        localPresets,
        remoteUrls,
        remoteByUrl,
        remoteLoadedCount,
        remoteFetchAttempted,
        remoteFetchFailed,
        isLoadingMoreRemote,
      ];
}