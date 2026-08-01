// lib/features/onboarding/presentation/widgets/onboarding_mesh_background.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../widgets/onboarding_pages_data.dart';

/// A layered "mesh gradient" background: 3 large soft-edged color
/// blobs (built from wide-stop `RadialGradient`s, not a runtime blur —
/// see the performance note on `GlassPanel`) that drift at different
/// speeds as [scrollPosition] changes, giving the glass panels above
/// them a sense of floating over something with real depth rather
/// than a flat two-stop gradient.
///
/// Each blob's color cross-fades between the current and adjacent
/// page's accent the same way the previous single-gradient background
/// did — this widget replaces that one outright, not alongside it.
class OnboardingMeshBackground extends StatelessWidget {
  final double scrollPosition;
  final bool isDark;

  const OnboardingMeshBackground({
    super.key,
    required this.scrollPosition,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final pageCount = kOnboardingPages.length;
    final clamped = scrollPosition.clamp(0.0, (pageCount - 1).toDouble());
    final lowerIndex = clamped.floor();
    final upperIndex = (lowerIndex + 1).clamp(0, pageCount - 1);
    final t = clamped - lowerIndex;

    final background =
        (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)[0]
            .toColor();

    final lowerAccentIndex = kOnboardingPages[lowerIndex].accentIndex;
    final upperAccentIndex = kOnboardingPages[upperIndex].accentIndex;
    final primaryPalette = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final lowerAccent = primaryPalette[lowerAccentIndex].toColor();
    final upperAccent = primaryPalette[upperAccentIndex].toColor();
    final accent = Color.lerp(lowerAccent, upperAccent, t)!;

    // Three blobs at different base positions and different parallax
    // speeds (the multiplier on scrollPosition) — the slowest barely
    // moves, the fastest drifts noticeably, which is what actually
    // reads as "depth" rather than everything panning together as one
    // flat image.
    final drift1 = scrollPosition * 18;
    final drift2 = scrollPosition * -12;
    final drift3 = scrollPosition * 8;

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(color: background),
        child: Stack(
          children: [
            _Blob(
              color: accent,
              opacity: isDark ? 0.35 : 0.28,
              top: -80 + drift1,
              left: -60,
              size: 320,
            ),
            _Blob(
              color: accent,
              opacity: isDark ? 0.25 : 0.20,
              top: 180 + drift2,
              right: -100,
              size: 280,
            ),
            _Blob(
              color: accent,
              opacity: isDark ? 0.20 : 0.16,
              bottom: -60 + drift3,
              left: -40,
              size: 260,
            ),
          ],
        ),
      ),
    );
  }
}

/// A single soft-edged color blob. Built entirely from a wide-stop
/// `RadialGradient` (color fully transparent well before the edge of
/// its own bounding box) rather than a `Container` + runtime blur —
/// this achieves a soft, blurred-looking edge without an actual
/// `BackdropFilter`/`ImageFilter.blur` pass, which matters here since
/// several `GlassPanel`s elsewhere on the same page already spend
/// that budget; adding blurred background blobs on top would stack
/// multiple expensive blur passes on one screen.
class _Blob extends StatelessWidget {
  final Color color;
  final double opacity;
  final double size;
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;

  const _Blob({
    required this.color,
    required this.opacity,
    required this.size,
    this.top,
    this.left,
    this.right,
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: opacity),
              color.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }
}