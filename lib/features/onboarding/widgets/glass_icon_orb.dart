// lib/features/onboarding/presentation/widgets/glass_icon_orb.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Renders an icon as a small dimensional "glass object" rather than
/// a flat colored shape: a radial gradient with a bright highlight
/// pulled toward the top-left (simulating a light source catching a
/// glossy/glass surface), a darker edge, a thin light rim, and a soft
/// drop shadow beneath. This is the icon treatment that reads as
/// "glass-material 3D" in current onboarding references, distinct
/// from a flat Material icon on a solid-color square.
class GlassIconOrb extends StatelessWidget {
  final IconData icon;
  final Color baseColor;
  final Color iconColor;
  final double size;

  const GlassIconOrb({
    super.key,
    required this.icon,
    required this.baseColor,
    required this.iconColor,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    // The glass highlight/rim need to read as neutral bright-white
    // regardless of theme or accent — sourced from AppColors rather
    // than Flutter's raw Colors.white, per this feature's
    // no-hardcoded-colors requirement.
    final highlight = AppColors.surfaceLight[0].toColor();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        // The highlight/shadow pair simulates a glossy surface catching
        // light from the upper-left — brighter tint near that corner,
        // the base color's own depth taking over toward the opposite
        // edge, rather than one flat fill.
        gradient: RadialGradient(
          center: const Alignment(-0.4, -0.5),
          radius: 1.1,
          colors: [
            Color.lerp(baseColor, highlight, 0.35)!,
            baseColor,
          ],
        ),
        border: Border.all(
          color: highlight.withValues(alpha: 0.35),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: baseColor.withValues(alpha: 0.45),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Icon(icon, size: size * 0.5, color: iconColor),
    );
  }
}