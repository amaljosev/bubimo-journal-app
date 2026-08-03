// lib/core/theme/font/safe_font_service.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../error/failures.dart';
import '../../network/network_info.dart';
import '../built_in_themes.dart';
import '../google_fonts_catalog.dart';

/// Central, crash-proof gateway for every Google Font this app uses —
/// built-in theme fonts ([BuiltInThemes]) and every family in
/// [GoogleFontsCatalog], the single shared list behind both the
/// custom-theme Font Picker and the diary entry rich-text editor's
/// font picker.
///
/// This exists because `google_fonts` fetches over HTTP the first
/// time a family is used, and that fetch runs on a *detached*
/// internal Future the calling code never gets a handle on — a
/// synchronous try/catch around `GoogleFonts.getTextTheme(...)`
/// cannot catch a failure that surfaces later, off in that detached
/// Future, as an unhandled exception. That's what was crashing first
/// launch offline: the call itself doesn't throw, the background
/// fetch does, afterward, unobserved.
///
/// The fix is to never let that detached fetch fire in a situation
/// where it's already known (or strongly suspected) to fail:
/// - [resolveTextTheme]/[resolveTextStyle] (render-time, always
///   synchronous, never throw) only ever call into `google_fonts` for
///   a family this service has already confirmed is cached — which
///   should resolve from `google_fonts`' own on-disk cache with no
///   network involved. Anything not yet confirmed renders in the
///   system default font instead of risking the call at all.
/// - [ensureFontAvailable] (explicit user actions — applying a theme,
///   picking a font) is the ONLY place that ever triggers a genuine
///   new fetch, and does so properly: gated on [NetworkInfo] first,
///   then awaited via `GoogleFonts.pendingFonts()` and wrapped in
///   try/catch, so success/failure is actually observable.
///
/// [bundledDefaultFamily] never goes through `google_fonts` at all,
/// even in [resolveTextTheme] — it's a plain native Flutter font
/// asset, so it's the one family guaranteed to work with zero network
/// dependency from the very first frame, before this service (or
/// anything else) has had a chance to load or fetch anything.
///
/// A residual gap remains, by design rather than oversight: if a
/// family this service believes is cached has its on-disk cache file
/// removed out from under it (OS storage pressure, a manual cache
/// clear, etc.), `google_fonts`' *own* internal check would try to
/// silently re-fetch it — reintroducing the original detached-fetch
/// risk for that one call. This service can't see a missing file it
/// doesn't manage, so that residual case is caught by the top-level
/// zone error handler in `main.dart` instead, as a last line of
/// defense rather than a first one.
class SafeFontService {
  final NetworkInfo networkInfo;

  SafeFontService({required this.networkInfo});

  /// The one font family bundled as a genuine native Flutter asset
  /// (see pubspec.yaml's `fonts:` section) rather than fetched through
  /// `google_fonts`. Chosen because it's Bloom's font
  /// (`BuiltInThemes.defaultTheme` — the theme every fresh install
  /// starts on) *and* Ocean's, so bundling it covers two built-in
  /// themes for zero network cost, and any custom theme that happens
  /// to pick it from the Font Picker gets the same benefit for free.
  ///
  /// Deliberately NOT registered via `google_fonts`' own "matching
  /// asset" auto-detection feature — that mechanism depends on
  /// reading `AssetManifest.json` internally, which has had
  /// recurring breakage across Flutter versions (including on
  /// current stable releases). A plain native `fonts:` entry has no
  /// dependency on that at all.
  static const String bundledDefaultFamily = 'Quicksand';

  static const String _prefsKey = 'safe_font_service.cached_families.v1';

  final Set<String> _cachedFamilies = {bundledDefaultFamily};
  final Set<String> _inFlight = {};
  SharedPreferences? _prefs;
  Timer? _retryTimer;

  /// Fires whenever a family finishes downloading successfully.
  /// AppThemeCubit wires this to a small refresh method so a
  /// background catch-up download doesn't require the user to
  /// re-apply the currently active theme to see its real font.
  void Function(String family)? onFontBecameAvailable;

  /// Loads the persisted "known-good" registry. Call once at startup,
  /// before the first [resolveTextTheme] call (see `main.dart`).
  /// There's no hard ordering requirement beyond "sooner is better" —
  /// every method here already degrades gracefully with an empty
  /// registry.
  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final saved = _prefs?.getStringList(_prefsKey) ?? const <String>[];
      _cachedFamilies.addAll(saved);
    } catch (_) {
      // Worst case: registry starts empty this session and everything
      // just re-verifies itself the slow way. Never a crash.
    }
  }

  bool isKnownAvailable(String fontFamily) =>
      _cachedFamilies.contains(fontFamily);

  /// Convenience passthrough for callers that just need a quick
  /// connectivity check (e.g. a picker sheet's one-time "you're
  /// offline" banner) without reaching for [NetworkInfo] directly —
  /// keeps that dependency in one place.
  Future<bool> get isOnline => networkInfo.isConnected;

  /// Synchronous, render-time font resolution for a whole
  /// [TextTheme]. NEVER throws. This is what `theme_mapper.dart`
  /// should call instead of `GoogleFonts.getTextTheme` directly.
  TextTheme resolveTextTheme({
    required String fontFamily,
    required TextTheme base,
  }) {
    if (fontFamily == bundledDefaultFamily) {
      return base.apply(fontFamily: fontFamily);
    }

    if (!_cachedFamilies.contains(fontFamily)) {
      // Not confirmed yet — don't gamble on a detached fetch just to
      // render this frame. System font now, upgraded automatically
      // later via onFontBecameAvailable once precache succeeds.
      return base;
    }

    try {
      return GoogleFonts.getTextTheme(fontFamily, base);
    } catch (_) {
      return base;
    }
  }

  /// Synchronous, render-time resolution for a single [TextStyle] —
  /// for per-tile font previews (e.g. `ThemeFontLabel`, a theme name
  /// rendered in its own font) where a full TextTheme is overkill.
  /// Same safety guarantees as [resolveTextTheme].
  TextStyle resolveTextStyle({
    required String fontFamily,
    required TextStyle base,
  }) {
    if (fontFamily == bundledDefaultFamily) {
      return base.copyWith(fontFamily: fontFamily);
    }
    if (!_cachedFamilies.contains(fontFamily)) {
      return base;
    }
    try {
      return GoogleFonts.getFont(fontFamily, textStyle: base);
    } catch (_) {
      return base;
    }
  }

  /// Explicit, awaited attempt to make [fontFamily] available — call
  /// this from user-initiated actions (applying a theme, picking a
  /// font in the Custom Theme form) where a brief wait and a real
  /// success/failure result are appropriate, unlike
  /// [resolveTextTheme]'s instant-and-silent contract.
  ///
  /// Returns `Right(null)` if the font is already available or was
  /// just downloaded successfully. Returns `Left` with a
  /// user-friendly message otherwise: [NoInternetFailure] if the
  /// network wasn't even attempted (already known offline), or
  /// [FontDownloadFailure] if a fetch was attempted and failed.
  Future<Either<Failure, void>> ensureFontAvailable(
    String fontFamily,
  ) async {
    if (fontFamily == bundledDefaultFamily ||
        _cachedFamilies.contains(fontFamily)) {
      return const Right(null);
    }

    // Someone else (a precache sweep, another call) is already
    // fetching this exact family — don't fire a duplicate request.
    if (_inFlight.contains(fontFamily)) {
      return const Right(null);
    }

    final online = await networkInfo.isConnected;
    if (!online) {
      return Left(
        NoInternetFailure(
          "You're offline and this font hasn't been downloaded yet. "
          "It'll apply with the default font for now — reconnect to "
          "get the full look.",
        ),
      );
    }

    _inFlight.add(fontFamily);
    try {
      // Triggers the load; pendingFonts() is what actually lets us
      // await + catch it, unlike calling getTextTheme alone.
      GoogleFonts.getTextTheme(fontFamily);
      await GoogleFonts.pendingFonts();
      await _markAvailable(fontFamily);
      onFontBecameAvailable?.call(fontFamily);
      return const Right(null);
    } catch (e) {
      debugPrint('SafeFontService: failed to load "$fontFamily" — $e');
      return const Left(
        FontDownloadFailure(
          "Couldn't download this font right now. Using the default "
          "font for now — you can try again later.",
        ),
      );
    } finally {
      _inFlight.remove(fontFamily);
    }
  }

  Future<void> _markAvailable(String fontFamily) async {
    _cachedFamilies.add(fontFamily);
    try {
      await _prefs?.setStringList(_prefsKey, _cachedFamilies.toList());
    } catch (_) {
      // Registry write failed (disk full, etc.) — the font is still
      // usable this session via google_fonts' own cache; worst case
      // we just re-verify it next launch. Never a crash.
    }
  }

  Set<String> _missingFamilies() => <String>{
        for (final theme in BuiltInThemes.all) theme.fontFamily,
        ...GoogleFontsCatalog.families,
      }..removeWhere(
          (family) =>
              family == bundledDefaultFamily || _cachedFamilies.contains(family),
        );

  /// Sweeps every built-in theme font plus every Font Picker catalog
  /// font, skipping anything already confirmed available, in small
  /// batches so we're not firing dozens of requests at once. No-ops
  /// entirely if offline. Safe to call repeatedly — later calls just
  /// skip whatever an earlier call already secured.
  Future<void> precacheAllKnownFonts() async {
    final online = await networkInfo.isConnected;
    if (!online) return;

    final targets = _missingFamilies().toList();
    if (targets.isEmpty) return;

    const batchSize = 4;
    for (var i = 0; i < targets.length; i += batchSize) {
      final batch = targets.skip(i).take(batchSize);
      await Future.wait(batch.map(ensureFontAvailable));
      // Small stagger between batches — polite to fonts.gstatic.com,
      // and avoids a thundering-herd retry if a batch fails due to a
      // transient blip.
      if (i + batchSize < targets.length) {
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }
  }

  /// Starts a low-frequency periodic retry (every 2 minutes) that
  /// re-runs [precacheAllKnownFonts] as long as something is still
  /// missing. This is what makes "download everything once the
  /// internet comes back" automatic without this service needing
  /// direct access to a connectivity-change stream. Call once from
  /// `main.dart`; cancels itself permanently once nothing is left to
  /// fetch.
  void startBackgroundRetry() {
    _retryTimer?.cancel();
    _retryTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
      if (_missingFamilies().isEmpty) {
        timer.cancel();
        return;
      }
      await precacheAllKnownFonts();
    });
  }

  /// Call when the app resumes from the background — the most common
  /// real-world moment connectivity actually changes (the user left
  /// the app to turn on Wi-Fi/data). Cheap no-op if already online
  /// and fully cached. Deliberately fire-and-forget: resuming the app
  /// should never wait on this.
  void onAppResumed() {
    unawaited(precacheAllKnownFonts());
  }

  void dispose() {
    _retryTimer?.cancel();
  }
}