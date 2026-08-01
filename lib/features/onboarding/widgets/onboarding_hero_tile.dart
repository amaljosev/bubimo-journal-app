// lib/features/onboarding/presentation/widgets/onboarding_hero_tile.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'glass_icon_orb.dart';
import 'glass_panel.dart';

/// The larger top tile in a page's bento grid: a glass panel holding
/// a dimensional glass-material icon orb and the page title.
/// Previously a flat tinted `Container`; now a genuine frosted-glass
/// surface (see `GlassPanel`) with a glossy icon treatment (see
/// `GlassIconOrb`) rather than a flat colored icon square.
class OnboardingHeroTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final int accentIndex;

  const OnboardingHeroTile({
    super.key,
    required this.icon,
    required this.title,
    required this.accentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        (isDark ? AppColors.primaryDark : AppColors.primaryLight)[accentIndex]
            .toColor();
    final textColor =
        (isDark ? AppColors.textDark : AppColors.textLight)[0].toColor();
    final onAccent = AppColors.surfaceLight[0].toColor();

    // The glass tint itself stays neutral (a soft white/near-black
    // wash), NOT accent-colored — the accent lives in the icon orb
    // and the border/shadow tint instead. A colored glass fill would
    // fight the mesh background's own accent-colored blobs showing
    // through; a neutral tint lets the blur genuinely show the
    // background's color through the glass, which is the whole point
    // of the effect. Sourced from AppColors' surface roles (near-white
    // in light mode, near-black in dark) rather than raw Flutter
    // colors, per this feature's no-hardcoded-colors requirement.
    final neutralSurface =
        (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)[
                isDark ? 7 : 0]
            .toColor();
    final glassTint = neutralSurface.withValues(alpha: isDark ? 0.28 : 0.35);
    final borderColor = accent.withValues(alpha: 0.4);

    return GlassPanel(
      tint: glassTint,
      borderColor: borderColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassIconOrb(icon: icon, baseColor: accent, iconColor: onAccent),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}