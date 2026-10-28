// lib/core/widgets/minimal_tab_bar.dart

import 'package:flutter/material.dart';

/// A minimal, text-only tab bar: no backgrounds, no ripples, just the
/// labels with a short rounded underline under the selected one and a
/// faint hairline divider below the row.
///
/// Uses [controller] if given, otherwise the nearest
/// [DefaultTabController].
///
/// Alignment: the first label's text starts exactly [horizontalInset]
/// from the left edge, so it lines up with content below that uses the
/// same inset (e.g. a grid with 16 px padding). Tabs are separated by
/// `2 * _labelGap` (24 px).
class MinimalTabBar extends StatelessWidget {
  const MinimalTabBar({
    super.key,
    required this.labels,
    this.controller,
    this.isScrollable = true,
    this.horizontalInset = 16,
  }) : assert(horizontalInset >= _labelGap);

  final List<String> labels;
  final TabController? controller;

  /// True for tab names of unknown number/length (left-aligned, scrolls
  /// sideways). False for a fixed small set that should share the width.
  final bool isScrollable;

  /// Distance from the bar's left edge to the first label's text.
  final double horizontalInset;

  /// Horizontal padding on each side of every label.
  static const double _labelGap = 12;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TabBar(
      controller: controller,
      isScrollable: isScrollable,
      tabAlignment: isScrollable ? TabAlignment.start : TabAlignment.fill,
      // Bar padding + label padding add up to [horizontalInset].
      padding: EdgeInsets.symmetric(horizontal: horizontalInset - _labelGap),
      labelPadding: const EdgeInsets.symmetric(horizontal: _labelGap),
      indicatorSize: TabBarIndicatorSize.label,
      indicator: UnderlineTabIndicator(
        borderSide: BorderSide(width: 3, color: colors.primary),
        borderRadius: BorderRadius.circular(3),
      ),
      dividerColor: colors.outlineVariant.withValues(alpha: 0.5),
      dividerHeight: 1,
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      labelColor: colors.onSurface,
      unselectedLabelColor: colors.onSurfaceVariant,
      labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      unselectedLabelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      tabs: [for (final label in labels) Tab(height: 44, text: label)],
    );
  }
}