// lib/features/onboarding/presentation/widgets/glass_panel.dart

import 'dart:ui';

import 'package:flutter/material.dart';

/// A reusable frosted-glass surface: blurred backdrop, translucent
/// tint, a thin light border, and a soft shadow for lift — the
/// standard glassmorphism recipe (`ClipRRect` + `BackdropFilter` +
/// a translucent `Container`, no external package needed).
///
/// Performance note: `BackdropFilter` is genuinely expensive, and
/// stacking many of them on one screen is a well-documented mobile
/// perf trap. This app's onboarding pages use a handful of these per
/// page (hero + description + a few feature tiles) — each `GlassPanel`
/// bounds its own blur to just its own rounded-rect region via
/// `ClipRRect`, and none of them nest inside another `BackdropFilter`,
/// so each blur pass only ever samples the plain background behind
/// it, never another blurred layer. If a future page ever needed
/// noticeably more tiles than this, that would be the point to
/// reconsider (e.g. blur a shared backdrop once behind a whole
/// group instead of once per tile).
class GlassPanel extends StatelessWidget {
  final Widget child;
  final Color tint;
  final Color borderColor;
  final double borderRadius;
  final double blurSigma;
  final EdgeInsetsGeometry padding;

  const GlassPanel({
    super.key,
    required this.child,
    required this.tint,
    required this.borderColor,
    this.borderRadius = 28,
    this.blurSigma = 16,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      // The shadow lives on an OUTER Container, not inside the
      // ClipRRect — a shadow drawn inside a clipped, blurred region
      // gets clipped away too and never renders.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: borderColor.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor, width: 1.2),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}