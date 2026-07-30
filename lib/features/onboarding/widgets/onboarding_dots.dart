// lib/features/onboarding/presentation/widgets/onboarding_dots.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Dot page indicator where the active dot smoothly stretches into a
/// pill rather than snapping — a small, purposeful animation that
/// tracks the same accent as the current page.
class OnboardingDots extends StatelessWidget {
  final int count;
  final int currentIndex;
  final int accentIndex;

  const OnboardingDots({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.accentIndex,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        (isDark ? AppColors.primaryDark : AppColors.primaryLight)[accentIndex]
            .toColor();
    final inactive =
        (isDark ? AppColors.textDark : AppColors.textLight)[4].toColor();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == currentIndex ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i == currentIndex
                  ? accent
                  : inactive.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}