// lib/features/onboarding/presentation/widgets/onboarding_page_view_item.dart

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../domain/entities/onboarding_page_data.dart';
import 'onboarding_feature_chips.dart';
import 'onboarding_hero.dart';
import 'onboarding_layout.dart';

/// One page's content: hero illustration, title, description, and
/// feature chips. Switches from stacked (illustration above text) to
/// side-by-side at [kOnboardingWideBreakpoint] so tablets and
/// landscape phones use their extra width instead of just centering
/// a narrow column in a wide screen.
class OnboardingPageViewItem extends StatelessWidget {
  final OnboardingPageData data;

  const OnboardingPageViewItem({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        (isDark ? AppColors.textDark : AppColors.textLight)[0].toColor();
    final mutedTextColor =
        (isDark ? AppColors.textDark : AppColors.textLight)[3].toColor();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kOnboardingWideBreakpoint;
        final double heroSize = isWide
            ? 260.0
            : (constraints.maxWidth * 0.5).clamp(160.0, 240.0);

        final hero = OnboardingHero(icon: data.icon, accentIndex: data.accentIndex, size: heroSize);

        final title = Text(
          data.title,
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: textColor, fontWeight: FontWeight.w700),
        );

        final description = Text(
          data.description,
          textAlign: isWide ? TextAlign.left : TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: mutedTextColor, height: 1.4),
        );

        final chips = Align(
          alignment: isWide ? Alignment.centerLeft : Alignment.center,
          child: OnboardingFeatureChips(features: data.features, accentIndex: data.accentIndex),
        );

        final textColumn = Column(
          crossAxisAlignment: isWide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            title,
            const SizedBox(height: 16),
            description,
            const SizedBox(height: 24),
            chips,
          ],
        );

        final content = isWide
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  hero,
                  const SizedBox(width: 48),
                  Flexible(child: textColumn),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  hero,
                  const SizedBox(height: 40),
                  textColumn,
                ],
              );

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: isWide ? 900 : 480),
              child: content,
            ),
          ),
        );
      },
    );
  }
}