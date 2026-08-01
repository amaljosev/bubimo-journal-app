// lib/core/widgets/no_internet_page.dart

import 'package:flutter/material.dart';

/// Generic full-screen "you're offline" state, shown by any gate that
/// gets in front of something needing real internet access —
/// originally built just for `CloudBackupGate`, generalized here (with
/// [title]/[message] instead of hardcoded copy) so [InternetGate] can
/// reuse the exact same screen for one-off actions like opening the
/// Privacy Policy link, rather than every feature growing its own
/// near-identical offline screen.
///
/// This widget itself has no connectivity logic; it only knows how to
/// render the "you're offline" state and offer a retry. The caller
/// (`CloudBackupGate`, `InternetGate`) owns checking connectivity and
/// deciding what happens on retry/success.
///
/// Deliberately theme-driven (colorScheme/textTheme only, no hardcoded
/// colors) so it matches whichever of the app's built-in or custom
/// themes is active, the same as every other screen in the app.
class NoInternetPage extends StatelessWidget {
  /// Shown as the AppBar title — e.g. "Cloud Backup", "Privacy Policy".
  final String title;

  /// The body message explaining what needs internet — e.g. "Cloud
  /// backup needs an internet connection to talk to Google Drive."
  final String message;

  /// Called when the user taps "Try again". The caller re-checks
  /// connectivity and decides what happens next (dismiss this screen,
  /// run a pending action, or leave it in place) — this widget just
  /// shows [isRetrying] while that check runs.
  final Future<void> Function() onRetry;

  /// True while a retry check is in flight — disables the button and
  /// swaps its icon for a small spinner so a slow/timing-out check
  /// doesn't look like a dead tap.
  final bool isRetrying;

  const NoInternetPage({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.isRetrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(title)),
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
                message,
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