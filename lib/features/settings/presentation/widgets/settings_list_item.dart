// lib/features/settings/presentation/widgets/settings_list_item.dart

import 'package:flutter/material.dart';
import '../../../../core/navigation/debounced_tap.dart';

/// A titled group of [SettingsListItem] rows, rendered as one rounded
/// card with dividers between rows — used throughout SettingsPage
/// (Data & Security, Preferences, Support, Spread the Word).
class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i != children.length - 1)
                  Divider(
                    height: 1,
                    thickness: 1,
                    indent: 56,
                    color: colorScheme.outlineVariant.withValues(alpha: 0.2),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A single tappable settings row: leading icon, label, trailing
/// chevron. [onTap] is nullable — rows for features not yet built are
/// passed no `onTap` and render as static, non-interactive placeholders
/// (per SettingsPage's doc comment) rather than dead taps that look
/// broken.
///
/// The tap itself goes through [DebouncedTap] (see
/// core/navigation/debounced_tap.dart) so a fast double-tap on a row —
/// e.g. "App Lock" or "Backup & Restore" — can't push the same
/// destination route twice onto the stack before the first transition
/// finishes. This was the actual bug: SettingsPage itself always called
/// context.push exactly once per tap; the double-push happened here,
/// in the tile's raw InkWell, which fired twice for one fast tap.
class SettingsListItem extends StatelessWidget {
  const SettingsListItem({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isEnabled = onTap != null;

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: isEnabled ? colorScheme.primary : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isEnabled ? colorScheme.onSurface : colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ),
          if (isEnabled)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
        ],
      ),
    );

    // Rows with no onTap (features not built yet) render as a plain,
    // non-interactive row — no DebouncedTap/InkWell wrapper, since
    // there's nothing to debounce and no ripple should suggest it's
    // tappable.
    if (!isEnabled) return row;

    return DebouncedTap(
      onTap: onTap!,
      borderRadius: BorderRadius.circular(16),
      child: row,
    );
  }
}