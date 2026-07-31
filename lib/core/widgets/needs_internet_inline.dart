// lib/core/widgets/needs_internet_inline.dart

import 'package:flutter/material.dart';

/// Themed inline "this needs internet" state, for any bottom sheet or
/// panel that has body space to show it in — the full-body version
/// used by the sticker and background pickers when their remote
/// fetch has no connection to work with.
///
/// Deliberately NOT a SnackBar: a SnackBar disappears on its own,
/// competes with the sheet's own dismiss gesture, and doesn't explain
/// *why* the grid is empty once it's gone. This sits in the exact
/// spot the content would otherwise occupy, stays until the user acts,
/// and pairs the explanation with a retry — closer to how the cloud
/// backup gate's `NoInternetPage` reads, just sized for a sheet
/// instead of a full screen.
class NeedsInternetInline extends StatelessWidget {
  /// What the user was trying to do — filled into "You need an
  /// internet connection to {action}." e.g. "browse stickers",
  /// "load background presets".
  final String action;

  final VoidCallback onRetry;
  final bool isRetrying;

  const NeedsInternetInline({
    super.key,
    required this.action,
    required this.onRetry,
    this.isRetrying = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: 34,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No internet connection',
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You need an internet connection to $action.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.tonalIcon(
              onPressed: isRetrying ? null : onRetry,
              icon: isRetrying
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colorScheme.primary,
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(isRetrying ? 'Checking…' : 'Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact banner variant for surfaces that stay partially usable
/// while offline — the font panel's list still works from cache, so
/// this sits above it as a dismissible strip rather than replacing the
/// whole panel the way [NeedsInternetInline] replaces a sheet's body.
class NeedsInternetBanner extends StatelessWidget {
  /// What's degraded while offline, e.g. "New fonts can't be
  /// downloaded right now — you can still use already-loaded ones."
  final String message;

  const NeedsInternetBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 18,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}