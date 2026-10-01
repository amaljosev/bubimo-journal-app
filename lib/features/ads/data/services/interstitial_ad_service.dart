// lib/core/ads/interstitial_ad_service.dart

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
/// An ad is skipped (silently) when: "Show Ads" is off in Settings, the
/// notice hasn't been seen yet, an ad was already shown (or the notice
/// was seen) today, or no ad is loaded yet. The daily limit is only
/// used up when an ad was actually shown, so a failed load doesn't
/// cost the user's day.
class InterstitialAdService {
  InterstitialAdService(this._adsPreference);

  final AdsPreferenceService _adsPreference;

  static const _lastShownKey = 'interstitial_last_shown_date';
  static const _noticeSeenKey = 'interstitial_notice_seen';

  /// Google expires loaded interstitials after 1 hour; discard a bit
  /// earlier so we never try to show a stale one.
  static const _maxAdAge = Duration(minutes: 55);

  InterstitialAd? _ad;
  DateTime? _loadedAt;
  bool _isLoading = false;

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
  /// call repeatedly.
  Future<void> preload() async {
    if (!_adsPreference.adsEnabled.value) return;
    if (_ad != null || _isLoading) return;
    _isLoading = true;

    try {
      // No point requesting an ad that can't be shown today.
      if (!await _canServeAdToday()) {
        _isLoading = false;
        return;
      }

      await InterstitialAd.load(
        adUnitId: AdUnitIds.interstitial,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _ad = ad;
            _loadedAt = DateTime.now();
            _isLoading = false;
          },
          onAdFailedToLoad: (error) {
            debugPrint('InterstitialAdService: failed to load ad: $error');
            _ad = null;
            _isLoading = false;
          },
        ),
      );
    } catch (e) {
      debugPrint('InterstitialAdService: preload error: $e');
      _isLoading = false;
    }
  }

  /// Returns the loaded ad if it's still fresh, otherwise discards it.
  InterstitialAd? _takeReadyAd() {
    final ad = _ad;
    final loadedAt = _loadedAt;
    _ad = null;
    _loadedAt = null;
    if (ad == null) return null;
    if (loadedAt == null ||
        DateTime.now().difference(loadedAt) > _maxAdAge) {
      ad.dispose();
      return null;
    }
    return ad;
  }

  /// Shows the ad if allowed. Completes when the ad is dismissed, or
  /// right away if there's nothing to show. Never throws.
  Future<void> showIfEligible() async {
    try {
      if (!_adsPreference.adsEnabled.value) return;
      if (!await _canServeAdToday()) return;

      final ad = _takeReadyAd();
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