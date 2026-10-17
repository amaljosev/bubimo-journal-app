// lib/features/ads/presentation/widgets/ads_toggle_tile.dart

import 'package:bubimo/features/plus/domain/entities/plus_feature.dart';
import 'package:bubimo/features/plus/presentation/bloc/plus_bloc.dart';
import 'package:bubimo/features/plus/presentation/widgets/plus_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection.dart';
import '../../data/services/ads_preference_service.dart';

/// A Settings row with a toggle switch for showing ads.
///
/// Visually mirrors `SettingsListItem` (icon + label, sitting inside
/// the same rounded `SettingsSection` card) but with a trailing
/// [Switch] instead of a chevron.
///
/// Turning ads OFF is a Bubimo Plus feature:
/// - Free users see the switch ON (ads are always on for them). If
///   they try to switch it off, the Plus paywall opens instead; once
///   they become members, ads switch off automatically (see
///   [AdsPreferenceService]).
/// - Plus members can switch ads off and back on freely.
class AdsToggleTile extends StatelessWidget {
  const AdsToggleTile({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final adsPreference = getIt<AdsPreferenceService>();
    final isPlus = context.select<PlusBloc, bool>((b) => b.state.isPlus);

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
              if (!isPlus) ...[
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
              ],
              Switch.adaptive(
                value: adsEnabled,
                onChanged: (wantsAds) async {
                  if (!isPlus) {
                    // Free users can't turn ads off — show the
                    // paywall. The switch value only changes if they
                    // become members (via applyPlusStatus).
                    if (!wantsAds) {
                      await PlusGate.require(context, PlusFeature.removeAds);
                    }
                    return;
                  }
                  await adsPreference.setAdsEnabled(wantsAds);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
