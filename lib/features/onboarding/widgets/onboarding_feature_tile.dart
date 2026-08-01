// lib/features/onboarding/presentation/widgets/onboarding_feature_tile.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../domain/entities/onboarding_page_data.dart';
import 'glass_icon_orb.dart';
import 'glass_panel.dart';

/// One small feature tile in a page's bento grid — a glass panel
/// holding a glass-material icon orb and a one-line label. Previously
/// a flat surface `Container`; now matches the same glass morphic
/// treatment as the hero and description tiles above it.
class OnboardingPageDataTile extends StatelessWidget {
  final OnboardingPageData feature;
  final int accentIndex;

  const OnboardingPageDataTile({
    super.key,
    required this.feature,
    required this.accentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        (isDark ? AppColors.primaryDark : AppColors.primaryLight)[accentIndex]
            .toColor();
    final textColor =
        (isDark ? AppColors.textDark : AppColors.textLight)[1].toColor();
    final onAccent = AppColors.surfaceLight[0].toColor();
    final neutralSurface =
        (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)[
                isDark ? 7 : 0]
            .toColor();
    final glassTint = neutralSurface.withValues(alpha: isDark ? 0.22 : 0.28);
    final borderColor = accent.withValues(alpha: 0.3);

    return GlassPanel(
      tint: glassTint,
      borderColor: borderColor,
      borderRadius: 22,
      blurSigma: 10,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassIconOrb(
            icon: feature.icon,
            baseColor: accent,
            iconColor: onAccent,
            size: 40,
          ),
          const SizedBox(height: 10),
          Text(
            feature.title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: textColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}