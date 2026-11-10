// lib/features/ads/data/services/interstitial_ad_service.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_unit_ids.dart';
import 'ads_preference_service.dart';

/// Shows a full-screen (interstitial) ad after a diary entry is saved,
/// at most once per calendar day. No ad on the user's first day.
///
/// - Call [preload] at app start (and it is safe to call again later).
/// - After saving, call [showIfEligible]. It never throws, and it waits
///   at most [_saveWaitTimeout] for an ad that isn't ready yet.
/// - The daily slot is only used up when an ad is actually shown.
class InterstitialAdService {
  InterstitialAdService(this._adsPreference);

  final AdsPreferenceService _adsPreference;

  static const _lastShownKey = 'interstitial_last_shown_date';
  static const _firstDayKey = 'interstitial_first_day';
  // Old key from the notice-page rollout. Users who already saw the
  // notice are past their first day, so they keep getting ads normally.
  static const _legacyNoticeSeenKey = 'interstitial_notice_seen';

  static const _maxAdAge = Duration(minutes: 55);

  /// Slow networks need more patience: retry waits are 5s, 10s, 15s, 20s.
  static const _maxLoadAttempts = 4;
  static const _retryDelay = Duration(seconds: 5);
  static const _loadTimeout = Duration(seconds: 30);

  /// Longest the save flow waits for an ad that isn't ready yet.
  static const _saveWaitTimeout = Duration(seconds: 1);

  InterstitialAd? _ad;
  DateTime? _loadedAt;
  Future<void>? _inFlightLoad;

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  /// False on the user's first day, and after an ad was shown today.
  Future<bool> _canServeAdToday() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();

    final isLegacyUser = prefs.getBool(_legacyNoticeSeenKey) ?? false;
    if (!isLegacyUser) {
      final firstDay = prefs.getString(_firstDayKey);
      if (firstDay == null) {
        await prefs.setString(_firstDayKey, today); // first launch
        return false;
      }
      if (firstDay == today) return false; // still the first day
    }
    return prefs.getString(_lastShownKey) != today;
  }

  Future<void> _markShownToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastShownKey, _todayKey());
  }

  /// Loads an ad in the background. Joins a load already in progress and
  /// does nothing when a fresh ad is already waiting.
  Future<void> preload() {
    if (!_adsPreference.adsEnabled.value) return Future<void>.value();
    _disposeIfExpired();
    if (_ad != null) return Future<void>.value();
    return _inFlightLoad ??= _loadWithRetry().whenComplete(
      () => _inFlightLoad = null,
    );
  }

  Future<void> _loadWithRetry() async {
    if (!await _canServeAdToday()) return;

    for (var attempt = 1; attempt <= _maxLoadAttempts; attempt++) {
      if (await _requestAd()) return;
      if (attempt < _maxLoadAttempts) {
        await Future<void>.delayed(_retryDelay * attempt);
      }
    }
  }

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
            if (!result.isCompleted) result.complete(true);
          },
          onAdFailedToLoad: (error) {
            debugPrint(
              'InterstitialAdService: failed to load ad: '
              'code=${error.code} message=${error.message}',
            );
            if (!result.isCompleted) result.complete(false);
          },
        ),
      );
    } catch (e) {
      debugPrint('InterstitialAdService: load error: $e');
      return false;
    }

    return result.future.timeout(_loadTimeout, onTimeout: () => false);
  }

  void _disposeIfExpired() {
    final loadedAt = _loadedAt;
    if (loadedAt == null) return;
    if (DateTime.now().difference(loadedAt) > _maxAdAge) {
      _ad?.dispose();
      _ad = null;
      _loadedAt = null;
    }
  }

  InterstitialAd? _takeReadyAd() {
    _disposeIfExpired();
    final ad = _ad;
    _ad = null;
    _loadedAt = null;
    return ad;
  }

  /// The preloaded ad if there is one. Otherwise waits only briefly for
  /// the load already in progress (or starts one) — the load keeps
  /// running in the background either way, so the ad is ready next time.
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