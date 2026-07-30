// lib/features/onboarding/presentation/widgets/onboarding_feature_chips.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Small pill tags listing the features a page represents (e.g.
/// "Timeline", "Analytics", "Favorite entries"). Wraps rather than
/// scrolling horizontally so it holds up in narrow layouts without
/// clipping the last chip.
class OnboardingFeatureChips extends StatelessWidget {
  final List<String> features;
  final int accentIndex;

  const OnboardingFeatureChips({
    super.key,
    required this.features,
    required this.accentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        (isDark ? AppColors.primaryDark : AppColors.primaryLight)[accentIndex]
            .toColor();
    final surface =
        (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)[0]
            .toColor();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final feature in features)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: surface.withValues(alpha: isDark ? 0.5 : 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withValues(alpha: 0.35)),
            ),
            child: Text(
              feature,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}