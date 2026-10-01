// lib/core/ads/ad_unit_ids.dart

import 'package:bubimo/core/config/secrets.dart';
import 'package:flutter/foundation.dart';

/// Central place for every AdMob ad unit ID this app uses.
///
/// [banner] and [interstitial] resolve to Google's official test units
/// in debug builds and to the real production units in release builds,
/// so a developer build never accidentally serves (or clicks) real ads
/// during day-to-day development — AdMob requires test ads while
/// developing, and real ad impressions/clicks from a dev device risk
/// an invalid-traffic flag on the account.
///
/// Android-only: this app doesn't ship on iOS, so there's no separate
/// iOS ad unit constant here.
abstract final class AdUnitIds {
  // static const String _prodBannerAdUnitId = Secrets.prodBannerAdUnitId;

  /// Google's official Android test banner unit ID — always returns a
  /// test ad, safe to ship in debug builds indefinitely.
  // static const String _testBannerAdUnitId =
  //     'ca-app-pub-3940256099942544/6300978111';

  // static String get banner =>
  //     kDebugMode ? _testBannerAdUnitId : _prodBannerAdUnitId;

  static const String _prodInterstitialAdUnitId =
      Secrets.prodInterstitialAdUnitId;

  /// Google's official Android test interstitial unit ID.
  static const String _testInterstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712';

  static String get interstitial =>
      kDebugMode ? _testInterstitialAdUnitId : _prodInterstitialAdUnitId;
}
