// lib/features/settings/presentation/widgets/about_app_sheet.dart

import 'package:bubimo/core/constants/app_constants.dart';
import 'package:flutter/material.dart';

/// Bottom sheet showing app icon, name, version, and a short
/// description. Reached from Settings > Support > "About This App".
///
/// Plain StatelessWidget — version now comes from AppVersion.versionCode
/// (a constant), so there's no async loading or state to manage at all.
class AboutAppSheet extends StatelessWidget {
  const AboutAppSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag Handle
            Container(
              height: 5,
              width: 50,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(10),
              ),
            ),

            // App icon
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/icons/bubimo_icon.png',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),

            // App name
            Text(
              'bubimo',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),

            // Version
            Text(
              'Version ${AppConstants.versionCode}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            // Short description
            Text(
              'A cozy space for your thoughts. Write your diary in your '
              'own style, with themes that match your mood, and keep it '
              'safe behind a lock. Everything stays on your device, '
              'stored securely and shaped entirely your way.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}