// lib/features/cloud_backup/presentation/pages/no_internet_page.dart

import 'package:flutter/material.dart';

/// Shown in place of [CloudBackupPage] when the device has no internet
/// access — see `CloudBackupGate`, which is what actually decides
/// whether this or the real screen gets pushed. This widget itself has
/// no connectivity logic; it only knows how to render the "you're
/// offline" state and offer a retry.
///
/// Deliberately theme-driven (colorScheme/textTheme only, no hardcoded
/// colors) so it matches whichever of the app's built-in or custom
/// themes is active, the same as every other screen in the app.
class NoInternetPage extends StatelessWidget {
  /// Called when the user taps "Try again". The caller (CloudBackupGate)
  /// re-checks connectivity and either dismisses this screen or leaves
  /// it in place, showing [isRetrying] while the check runs.
  final Future<void> Function() onRetry;

  /// True while a retry check is in flight — disables the button and
  /// swaps its icon for a small spinner so a slow/timing-out check
  /// doesn't look like a dead tap.
  final bool isRetrying;

  const NoInternetPage({
    super.key,
    required this.onRetry,
    this.isRetrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cloud Backup')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.cloud_off_rounded,
                  size: 44,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 28),
              Text(
                "You're offline",
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Cloud backup needs an internet connection to talk to '
                'Google Drive. Check your connection and try again.',
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: isRetrying ? null : onRetry,
                icon: isRetrying
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.onPrimary,
                        ),
                      )
                    : const Icon(Icons.refresh_rounded),
                label: Text(isRetrying ? 'Checking…' : 'Try again'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(180, 48),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}