// lib/features/timeline/presentation/widgets/timeline_pills.dart

import 'package:flutter/material.dart';

/// Small translucent pill used in the hero header (entry count, favorite
/// count) over a background image.
class StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? iconColor;

  const StatPill({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: iconColor ?? color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable filled pill, used for the "go to Favorites" shortcut in the
/// collapsed app bar.
class IconPill extends StatelessWidget {
  final VoidCallback onTap;
  final Color color;
  final IconData icon;
  final String label;
  final Color textColor;

  const IconPill({
    super.key,
    required this.onTap,
    required this.color,
    required this.icon,
    required this.label,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        margin: label.isNotEmpty?null: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: textColor),
            if (label.isNotEmpty) const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small swatch + label pair used in the calendar legend row.
class LegendItem extends StatelessWidget {
  final Widget child;
  final String label;

  const LegendItem({super.key, required this.child, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        child,
       
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
