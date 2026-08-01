// lib/features/onboarding/presentation/widgets/onboarding_description_tile.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import 'glass_panel.dart';

/// The description tile in a page's bento grid: the supporting
/// paragraph, in a frosted glass panel rather than a flat surface
/// card.
class OnboardingDescriptionTile extends StatelessWidget {
  final String description;

  const OnboardingDescriptionTile({super.key, required this.description});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedTextColor =
        (isDark ? AppColors.textDark : AppColors.textLight)[3].toColor();
    final neutralSurface =
        (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)[
                isDark ? 7 : 0]
            .toColor();
    final glassTint = neutralSurface.withValues(alpha: isDark ? 0.24 : 0.30);
    final borderColor = neutralSurface.withValues(alpha: isDark ? 0.5 : 0.6);

    return GlassPanel(
      tint: glassTint,
      borderColor: borderColor,
      blurSigma: 12,
      child: Text(
        description,
        style: Theme.of(
          context,
        ).textTheme.bodyLarge?.copyWith(color: mutedTextColor, height: 1.4),
      ),
    );
  }
}