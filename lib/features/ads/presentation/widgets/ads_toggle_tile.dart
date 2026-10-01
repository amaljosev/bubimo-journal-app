// lib/core/ads/ads_toggle_tile.dart

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../data/services/ads_preference_service.dart';

/// A Settings row with a toggle switch for turning banner ads on/off.
///
/// Visually mirrors `SettingsListItem` (icon + label, sitting inside
/// the same rounded `SettingsSection` card) but with a trailing
/// [Switch] instead of a chevron, since this row doesn't navigate
/// anywhere — it flips [AdsPreferenceService.adsEnabled] directly.
///
/// This is a manual, user-facing toggle for now. Once in-app purchases
/// ship, a "remove ads" purchase should call
/// `getIt<AdsPreferenceService>().setAdsEnabled(false)` the same way
/// this switch does — nothing here or in [BannerAdWidget] needs to
/// change when that lands.
class AdsToggleTile extends StatelessWidget {
  const AdsToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final adsPreference = getIt<AdsPreferenceService>();

    return ValueListenableBuilder<bool>(
      valueListenable: adsPreference.adsEnabled,
      builder: (context, adsEnabled, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.ad_units_outlined,
                size: 22,
                color: colorScheme.primary,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Show Ads',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onSurface,
                  ),
                ),
              ),
              Switch.adaptive(
                value: adsEnabled,
                onChanged: adsPreference.setAdsEnabled,
              ),
            ],
          ),
        );
      },
    );
  }
}