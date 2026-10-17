// lib/features/plus/presentation/widgets/plus_feature_banner.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/plus_feature.dart';
import '../bloc/plus_bloc.dart';
import 'plus_gate.dart';

/// A short note at the top of a screen that contains Plus-only
/// actions, telling free users up front which part needs Bubimo Plus
/// (and, where it applies, what stays free) — so the paywall never
/// comes as a surprise after a tap.
///
/// Renders nothing for Plus members. Outlined rather than tinted, so
/// it reads as distinct from the screens' regular info banners.
/// "See Plus" opens the paywall for [feature].
class PlusFeatureBanner extends StatelessWidget {
  final PlusFeature feature;
  final String message;

  const PlusFeatureBanner({
    super.key,
    required this.feature,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isPlus = context.select<PlusBloc, bool>((b) => b.state.isPlus);
    if (isPlus) return const SizedBox.shrink();

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.primary.withValues(alpha: 0.4),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.workspace_premium_rounded,
              size: 22,
              color: colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: textTheme.bodySmall?.copyWith(
                  height: 1.4,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            TextButton(
              onPressed: () => PlusGate.require(context, feature),
              child: const Text('See Plus'),
            ),
          ],
        ),
      ),
    );
  }
}