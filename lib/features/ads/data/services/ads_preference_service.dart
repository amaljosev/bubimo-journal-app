// lib/features/ads/data/services/ads_preference_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Whether ads should currently be shown.
///
/// The rule, since Bubimo Plus:
/// - **Free users always see ads.** They can't switch them off.
/// - **Plus members choose.** Ads are OFF by default the moment they
///   become members (that's what they paid for), and the "Show Ads"
///   switch in Settings lets them turn ads back on if they want to
///   support the app.
///
/// [adsEnabled] is the *effective* value — what every
/// [BannerAdWidget] and [InterstitialAdService] already reads — so
/// none of those needed to change. Two inputs feed it: the member's
/// own choice ([setAdsEnabled], persisted) and the entitlement
/// ([applyPlusStatus], pushed from `main.dart` whenever `PlusBloc`
/// changes).
///
/// Persisted via [SharedPreferences] — the same lightweight-flag
/// storage onboarding uses, not the app_settings SQLite table, since
/// this isn't diary data. The pre-Plus `ads_enabled` key is no longer
/// read: it recorded a choice free users can't make anymore.
class AdsPreferenceService {
  static const _plusAdsKey = 'ads_plus_enabled';

  /// Read by every ad slot to decide whether to load and display
  /// itself. `true` = show ads. Starts `true` (safe default for a free
  /// user) until [loadInitial] and [applyPlusStatus] have run.
  final ValueNotifier<bool> adsEnabled = ValueNotifier<bool>(true);

  bool _isPlus = false;

  /// A Plus member's own choice. Defaults to `false` (ads off).
  bool _plusWantsAds = false;

  /// Loads the member's saved choice. Must be awaited before `runApp`
  /// (see main.dart), followed by [applyPlusStatus], so the very first
  /// frame already reflects the real state instead of briefly flashing
  /// an ad for a member who turned them off.
  Future<void> loadInitial() async {
    final prefs = await SharedPreferences.getInstance();
    _plusWantsAds = prefs.getBool(_plusAdsKey) ?? false;
    _recompute();
  }

  /// Called with the current entitlement at startup and on every
  /// change (purchase, restore, lapse).
  void applyPlusStatus(bool isPlus) {
    _isPlus = isPlus;
    _recompute();
  }

  /// Plus members only — ignored for free users, who can't change this.
  Future<void> setAdsEnabled(bool enabled) async {
    if (!_isPlus) return;
    _plusWantsAds = enabled;
    _recompute();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_plusAdsKey, enabled);
  }

  void _recompute() {
    adsEnabled.value = _isPlus ? _plusWantsAds : true;
  }
}
