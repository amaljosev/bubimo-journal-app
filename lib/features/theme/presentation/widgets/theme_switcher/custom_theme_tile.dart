// lib/features/theme/presentation/widgets/theme_switcher/custom_theme_tile.dart

import 'package:flutter/material.dart';

import '../../../domain/entities/app_theme_data.dart';
import '../shared/theme_color_swatch.dart';
import '../shared/theme_font_label.dart';
import '../shared/theme_header_image.dart';
import '../shared/theme_tile_card.dart';

/// A single custom theme row on the "Custom Themes" tab.
///
/// Like [BuiltInThemeTile], always renders [theme.name] in
/// [theme.fontFamily] regardless of the currently active app theme.
///
/// Unlike built-ins, applying is an explicit action — "Apply Theme"
/// must be tapped (per spec: saving/selecting a custom theme never
/// auto-applies it). Also exposes edit and delete affordances, since
/// custom themes (unlike built-ins) are user-owned and mutable.
class CustomThemeTile extends StatelessWidget {
  final AppThemeData theme;
  final bool isActive;
  final bool isEnabled;

  /// When true (free user), the Apply button shows a lock icon to signal
  /// that applying a custom theme requires Bubimo Plus. The paywall itself
  /// is enforced by the caller's [onApply].
  final bool isLocked;
  final VoidCallback onApply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CustomThemeTile({
    super.key,
    required this.theme,
    required this.isActive,
    required this.onApply,
    required this.onEdit,
    required this.onDelete,
    this.isEnabled = true,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final headerImagePath = theme.headerImagePath;

    return ThemeTileCard(
      isActive: isActive,
      leading: headerImagePath != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 56,
                height: 56,
                child: ThemeHeaderImage.fromTheme(theme),
              ),
            )
          : ThemeColorGradientBlock(
              colors: [
                theme.primaryColor.toColor(),
                theme.secondaryColor.toColor(),
              ],
            ),
      titleAndSubtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ThemeFontLabel(
            theme.name,
            fontFamily: theme.fontFamily,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
          const SizedBox(height: 4),
          ThemeFontLabel(
            theme.fontFamily,
            fontFamily: theme.fontFamily,
            fontSize: 13,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
      trailing:
          isActive ? Icon(Icons.check_circle, color: colorScheme.primary) : null,
      footer: Row(
        children: [
          Expanded(
            child: FilledButton.tonal(
              onPressed: isEnabled && !isActive ? onApply : null,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isLocked && !isActive) ...[
                    const Icon(Icons.lock_outline_rounded, size: 18),
                    const SizedBox(width: 6),
                  ],
                  Text(isActive ? 'Applied' : 'Apply Theme'),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: isEnabled ? onEdit : null,
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
          ),
          IconButton(
            onPressed: isEnabled ? onDelete : null,
            icon: Icon(Icons.delete_outline, color: colorScheme.error),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}