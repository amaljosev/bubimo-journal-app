// lib/features/plus/presentation/widgets/plus_benefits_list.dart

import 'package:flutter/material.dart';

import '../../domain/entities/plus_feature.dart';

/// The "what you get" rows on the paywall — built from
/// [PlusFeature.values] so it always matches what is actually gated.
class PlusBenefitsList extends StatelessWidget {
  const PlusBenefitsList({super.key});

  IconData _iconFor(PlusFeature feature) {
    return switch (feature) {
      PlusFeature.customThemes => Icons.palette_outlined,
      PlusFeature.cloudBackup => Icons.cloud_upload_outlined,
      PlusFeature.localBackup => Icons.save_alt_rounded,
      PlusFeature.pdfExport => Icons.picture_as_pdf_outlined,
      PlusFeature.removeAds => Icons.block_rounded,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      children: [
        for (final feature in PlusFeature.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _iconFor(feature),
                    size: 20,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        feature.pitch,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
