// lib/features/onboarding/presentation/widgets/onboarding_hero.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// The large icon-in-a-soft-disc illustration for one onboarding
/// page. Deliberately simple — a gentle breathing scale on the disc,
/// nothing busier — since onboarding is a brief, functional moment,
/// not a marketing splash; a quiet ambient animation reads as
/// polished, a loud one reads as filler.
class OnboardingHero extends StatefulWidget {
  final IconData icon;
  final int accentIndex;
  final double size;

  const OnboardingHero({
    super.key,
    required this.icon,
    required this.accentIndex,
    this.size = 220,
  });

  @override
  State<OnboardingHero> createState() => _OnboardingHeroState();
}

class _OnboardingHeroState extends State<OnboardingHero>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _breathe;

  @override
  void initState() {
    super.initState();
    // A slow, subtle breathing loop — long duration and a small
    // amplitude (see _breathe's range below) keep this reading as
    // "ambient," not as a pulsing/attention-seeking effect.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _breathe = Tween<double>(
      begin: 0.96,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryPalette = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final accent = primaryPalette[widget.accentIndex].toColor();

    return AnimatedBuilder(
      animation: _breathe,
      builder: (context, child) {
        return Transform.scale(scale: _breathe.value, child: child);
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              accent.withValues(alpha: 0.22),
              accent.withValues(alpha: 0.05),
            ],
          ),
        ),
        child: Icon(widget.icon, size: widget.size * 0.4, color: accent),
      ),
    );
  }
}