// lib/features/onboarding/presentation/widgets/onboarding_dots.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Dot page indicator where each dot stays in a fixed position — no
/// horizontal stretch, no worm-style merge, no vertical jump. The
/// active dot animates by growing larger and brightening to the full
/// accent color; every other dot sits at a smaller, muted size.
/// Chosen deliberately distinct from the stretch-into-pill and
/// worm-morph styles common elsewhere, per the app's design
/// direction.
///
/// Built on [AnimatedContainer] rather than [TweenAnimationBuilder]:
/// `TweenAnimationBuilder` restarts from its `Tween`'s literal
/// `begin` value on every rebuild, which can produce a visible
/// snap-back if the previous animation hadn't finished (e.g. a quick
/// double-swipe) — `AnimatedContainer` instead always interpolates
/// from wherever it currently is toward the new target, which is the
/// correct behavior for a value (`isActive`) that can flip again
/// before the prior transition completes.
///
/// The muted/inactive color is intentionally NOT the same
/// low-opacity treatment used elsewhere for de-emphasis: at the
/// alpha this widget previously used (0.3), `textLight[4]` blended
/// against a white background renders at a contrast ratio of ~1.57,
/// well under the WCAG 3.0 minimum for non-text UI elements — which
/// is exactly why the old dots were invisible against the app's
/// light background. `_inactiveOpacity` below is set high enough
/// (0.7 → ~3.35:1 against white) to stay clearly visible while still
/// reading as secondary next to the fully-opaque active dot.
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

  static const double _activeDotSize = 12;
  static const double _inactiveDotSize = 8;
  static const double _inactiveOpacity = 0.7;
  static const Duration _duration = Duration(milliseconds: 300);

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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _Dot(
              isActive: i == currentIndex,
              activeColor: accent,
              inactiveColor: inactive,
            ),
          ),
      ],
    );
  }
}

/// A single dot: fixed footprint (`_activeDotSize`, the largest size
/// either state uses) via the outer `SizedBox` + `Center`, so
/// neighboring dots never shift position as this one grows/shrinks
/// inside that fixed box.
class _Dot extends StatelessWidget {
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;

  const _Dot({
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    final size = isActive
        ? OnboardingDots._activeDotSize
        : OnboardingDots._inactiveDotSize;
    final color = isActive
        ? activeColor
        : inactiveColor.withValues(alpha: OnboardingDots._inactiveOpacity);

    return SizedBox(
      width: OnboardingDots._activeDotSize,
      height: OnboardingDots._activeDotSize,
      child: Center(
        child: AnimatedContainer(
          duration: OnboardingDots._duration,
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    );
  }
}