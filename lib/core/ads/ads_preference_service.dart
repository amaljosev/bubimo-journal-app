// lib/core/ads/ads_preference_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether banner ads should currently be shown.
///
/// Defaults to `true` (ads on) until [loadInitial] resolves, and
/// persists the choice via [SharedPreferences] — the same lightweight
/// one-shot-flag storage the onboarding feature uses, rather than the
/// app_settings SQLite table, since this isn't diary data.
///
/// Today the only thing that flips this is the manual toggle in
/// Settings (see [AdsToggleTile]). Once in-app purchases ship, a
/// "remove ads" purchase should call [setAdsEnabled] the exact same
/// way that toggle does — no other code in the app (including
/// [BannerAdWidget]) needs to change when that lands, since every ad
/// slot already reads [adsEnabled] rather than deciding for itself.
class AdsPreferenceService {
  static const _prefsKey = 'ads_enabled';

  /// Read by every [BannerAdWidget] instance to decide whether to load
  /// and display itself. `true` = show ads.
  final ValueNotifier<bool> adsEnabled = ValueNotifier<bool>(true);

  /// Loads the persisted preference. Must be awaited before `runApp`
  /// (see main.dart) — mirrors `AppThemeCubit.loadInitialTheme()` and
  /// `LockBloc`'s cold-start load — so the very first frame already
  /// reflects the real preference instead of briefly flashing an ad
  /// for someone who already turned them off.
  Future<void> loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    adsEnabled.value = prefs.getBool(_prefsKey) ?? true;
  }

  Future<void> setAdsEnabled(bool enabled) async {
    adsEnabled.value = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, enabled);
  }
}