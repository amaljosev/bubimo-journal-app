// lib/features/ads/data/services/interstitial_ad_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_unit_ids.dart';
import 'ads_preference_service.dart';

/// Shows a full-screen (interstitial) ad after a diary entry is saved,
/// at most once per calendar day.
///
/// Rollout: the very first save ever shows a no-ad notice page instead
/// (see [shouldShowNotice] / [markNoticeSeen]); real ads begin the next
/// calendar day.
///
/// Usage:
/// - Call [preload] when the diary form opens, so an ad is ready by the
///   time the user taps Save.
/// - After the entry is saved: if [shouldShowNotice] is true, show the
///   notice page and then call [markNoticeSeen]; otherwise call
///   [showIfEligible]. It completes once the ad is dismissed — or
///   immediately if no ad is shown — and never throws, so saving can
///   never be blocked by an ad problem.
///
/// Loading is resilient on purpose, because a production ad unit does
/// not always fill the first request (unlike Google's test units):
/// - [preload] retries a few times with a growing delay.
/// - If no ad is ready at save time (slow network, every retry failed,
///   or the form was opened offline and the user is online now),
///   [showIfEligible] requests one right then and waits up to
///   [_saveWaitTimeout] for it. An ad that arrives later is kept for
///   the next save.
///
/// An ad is skipped (silently) when: "Show Ads" is off in Settings, the
/// notice hasn't been seen yet, an ad was already shown (or the notice
/// was seen) today, or no ad could be loaded in time. The daily limit
/// is only used up when an ad was actually shown, so a save without an
/// ad (offline, no fill) leaves today's slot for the next save.
class InterstitialAdService {
  InterstitialAdService(this._adsPreference);

  final AdsPreferenceService _adsPreference;

  static const _lastShownKey = 'interstitial_last_shown_date';
  static const _noticeSeenKey = 'interstitial_notice_seen';

  /// Google expires loaded interstitials after 1 hour; discard a bit
  /// earlier so we never try to show a stale one.
  static const _maxAdAge = Duration(minutes: 55);

  /// Requests per [preload]; the wait before retry N is
  /// `_retryDelay * N` (5s, then 10s).
  static const _maxLoadAttempts = 3;
  static const _retryDelay = Duration(seconds: 5);

  /// A request whose callback never fires is treated as failed, so one
  /// stuck request can't block loading for the rest of the session.
  static const _loadTimeout = Duration(seconds: 15);

  /// Longest the save flow waits for an ad that isn't ready yet.
  static const _saveWaitTimeout = Duration(seconds: 3);

  InterstitialAd? _ad;
  DateTime? _loadedAt;

  /// The load currently running, if any. Shared by every caller so
  /// concurrent [preload] calls never start duplicate requests.
  Future<void>? _inFlightLoad;

  /// Device-local calendar date as `yyyy-MM-dd` — changes at midnight.
  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  /// True when an ad may be served right now as far as the rules go:
  /// the one-time notice has been seen, and nothing was shown today.
  Future<bool> _canServeAdToday() async {
    final prefs = await SharedPreferences.getInstance();
    final noticeSeen = prefs.getBool(_noticeSeenKey) ?? false;
    if (!noticeSeen) return false;
    return prefs.getString(_lastShownKey) != _todayKey();
  }

  Future<void> _markShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastShownKey, _todayKey());
  }

  /// True when the one-time, no-ad notice page should be shown instead
  /// of an ad: ads are on and the user has never seen the notice.
  Future<bool> shouldShowNotice() async {
    if (!_adsPreference.adsEnabled.value) return false;
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(_noticeSeenKey) ?? false);
  }

  /// Records that the notice was seen. Also uses up today's slot, so the
  /// first real ad appears from the next calendar day.
  Future<void> markNoticeSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_noticeSeenKey, true);
    await prefs.setString(_lastShownKey, _todayKey());
  }

  /// Loads an ad in the background if one is worth loading. Safe to
  /// call repeatedly: it joins a load already in progress and does
  /// nothing when a fresh ad is already waiting.
  Future<void> preload() {
    if (!_adsPreference.adsEnabled.value) return Future<void>.value();
    _disposeIfExpired();
    if (_ad != null) return Future<void>.value();
    return _inFlightLoad ??= _loadWithRetry().whenComplete(
      () => _inFlightLoad = null,
    );
  }

  Future<void> _loadWithRetry() async {
    // No point requesting an ad that can't be shown today.
    if (!await _canServeAdToday()) return;

    for (var attempt = 1; attempt <= _maxLoadAttempts; attempt++) {
      if (await _requestAd()) return;
      if (attempt < _maxLoadAttempts) {
        await Future<void>.delayed(_retryDelay * attempt);
      }
    }
  }

  /// Makes one ad request. Completes with `true` once an ad is stored in
  /// [_ad], or `false` on failure or timeout. Never throws.
  Future<bool> _requestAd() async {
    final result = Completer<bool>();

    try {
      await InterstitialAd.load(
        adUnitId: AdUnitIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _ad?.dispose();
            _ad = ad;
            _loadedAt = DateTime.now();
            result.complete(true);
          },
          onAdFailedToLoad: (error) {
            debugPrint(
              'InterstitialAdService: failed to load ad: '
              'code=${error.code} message=${error.message}',
            );
            result.complete(false);
          },
        ),
      );
    } catch (e) {
      debugPrint('InterstitialAdService: load error: $e');
      return false;
    }

    return result.future.timeout(_loadTimeout, onTimeout: () => false);
  }

  /// Discards the loaded ad if it is too old to show safely.
  void _disposeIfExpired() {
    final loadedAt = _loadedAt;
    if (loadedAt == null) return;
    if (DateTime.now().difference(loadedAt) > _maxAdAge) {
      _ad?.dispose();
      _ad = null;
      _loadedAt = null;
    }
  }

  /// Hands over the loaded ad if it's still fresh (and forgets it, since
  /// an interstitial can be shown only once), otherwise returns null.
  InterstitialAd? _takeReadyAd() {
    _disposeIfExpired();
    final ad = _ad;
    _ad = null;
    _loadedAt = null;
    return ad;
  }

  /// The ad to show right now: the preloaded one, or — if none is ready
  /// — a fresh request awaited for at most [_saveWaitTimeout].
  Future<InterstitialAd?> _obtainAd() async {
    final ready = _takeReadyAd();
    if (ready != null) return ready;

    await preload().timeout(_saveWaitTimeout, onTimeout: () {});
    return _takeReadyAd();
  }

  /// Shows the ad if allowed. Completes when the ad is dismissed, or
  /// right away if there's nothing to show. Never throws.
  Future<void> showIfEligible() async {
    try {
      if (!_adsPreference.adsEnabled.value) return;
      if (!await _canServeAdToday()) return;

      final ad = await _obtainAd();
      if (ad == null) return;

      final dismissed = Completer<void>();

      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) {
          // Only a shown ad uses up today's slot.
          unawaited(_markShownToday());
        },
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          if (!dismissed.isCompleted) dismissed.complete();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('InterstitialAdService: failed to show ad: $error');
          ad.dispose();
          if (!dismissed.isCompleted) dismissed.complete();
        },
      );

      await ad.show();
      await dismissed.future;
    } catch (e) {
      debugPrint('InterstitialAdService: show error: $e');
    }
  }
}