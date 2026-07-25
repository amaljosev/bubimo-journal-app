// lib/core/navigation/pill_nav_bar.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/theme_tokens.dart';

// ---------------------------------------------------------------------
// Design constants — tune the whole bar from here. Colors are resolved
// from ColorScheme at build time.
// ---------------------------------------------------------------------

/// Height of the flat navigation bar surface (excludes the FAB
/// protrusion and safe-area padding).
const double kNavBarHeight = 64.0;

/// Horizontal margin between the bar and the screen edges. This,
/// together with [kBarBottomMargin], is what makes the bar read as
/// "floating" rather than docked edge-to-edge.
const double kBarHorizontalMargin = ThemeSpacing.lg;

/// Margin between the bottom of the bar and the bottom safe area /
/// screen edge.
const double kBarBottomMargin = ThemeSpacing.md;

/// Corner radius of the bar. Fully rounded (stadium) rather than a
/// soft rounded-rect: half of [kNavBarHeight] guarantees a true
/// stadium shape regardless of height tuning.
const double kBarCornerRadius = kNavBarHeight / 2;

/// Diameter of the floating diamond button (edge-to-edge of the
/// rotated square, i.e. the visual "width" of the diamond).
const double kFabSize = 60.0;

/// Corner radius applied to the square before it's rotated 45°.
const double kFabCornerRadius = ThemeRadii.xl;

/// Fraction of the FAB's total (diamond) height that should sit
/// above the top edge of the bar.
const double kFabProtrusion = 0.42;

/// Width of the empty gap reserved in the middle of the icon row so
/// the FAB has room to float above it.
const double kFabGapWidth = 92.0;

/// Blur radius for the bar's ambient drop shadow.
const double kBarShadowBlur = 28.0;

/// Vertical offset for the bar's drop shadow.
const double kBarShadowOffsetY = 12.0;

/// Blur radius for the FAB's own drop shadow.
const double kFabShadowBlur = 8.0;

/// Vertical offset for the FAB's own drop shadow.
const double kFabShadowOffsetY = 4.0;

/// Horizontal padding applied to the row of left / right icon slots,
/// inside the capsule.
const double kNavItemsHorizontalPadding = ThemeSpacing.md;

/// Press-animation timing for the FAB, sourced from the shared token
/// set so tap feedback feels consistent with the rest of the app.
const Duration kFabPressDuration = ThemeDurations.fast;
const Duration kFabReleaseDuration = ThemeDurations.standard;

/// Width of the selection pill background sitting behind the active
/// icon. Wider than it is tall so it reads as a squat rounded
/// rectangle rather than a square.
const double kPillWidth = 85.0;

/// Height of the selection pill.
const double kPillHeight = 50.0;

/// Corner radius of the selection pill.
const double kPillCornerRadius = 26.0;

/// Selection-pill slide timing/curve.
const Duration kPillSlideDuration = ThemeDurations.standard;
const Curve kPillSlideCurve = Curves.easeOutCubic;

/// Icon size for the regular (non-FAB) tabs.
const double kNavIconSize = 24.0;

// ---------------------------------------------------------------------
// Public data model for a single destination
// ---------------------------------------------------------------------

class NavBarItem {
  const NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

// ---------------------------------------------------------------------
// Main widget
// ---------------------------------------------------------------------

class PillNavBar extends StatefulWidget {
  const PillNavBar({
    super.key,
    required this.leftItems,
    required this.rightItems,
    required this.currentIndex,
    required this.onTap,
    required this.onFabTap,
    this.fabIcon = Icons.add,
  });

  final List<NavBarItem> leftItems;
  final List<NavBarItem> rightItems;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onFabTap;
  final IconData fabIcon;

  @override
  State<PillNavBar> createState() => _PillNavBarState();
}

class _PillNavBarState extends State<PillNavBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fabController;
  late final Animation<double> _fabScale;

  late List<GlobalKey> _tabKeys;

  @override
  void initState() {
    super.initState();

    _fabController = AnimationController(
      vsync: this,
      duration: kFabPressDuration,
      reverseDuration: kFabReleaseDuration,
    );

    _fabScale = Tween<double>(
      begin: 1.0,
      end: 0.88,
    ).animate(CurvedAnimation(parent: _fabController, curve: Curves.easeOut));

    _tabKeys = List.generate(
      widget.leftItems.length + widget.rightItems.length,
      (_) => GlobalKey(),
    );
  }

  @override
  void didUpdateWidget(covariant PillNavBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final int totalItems = widget.leftItems.length + widget.rightItems.length;
    if (totalItems != _tabKeys.length) {
      _tabKeys = List.generate(totalItems, (_) => GlobalKey());
    }
  }

  @override
  void dispose() {
    _fabController.dispose();
    super.dispose();
  }

  void _handleFabTapDown(TapDownDetails _) => _fabController.forward();
  void _handleFabTapUp(TapUpDetails _) => _fabController.reverse();
  void _handleFabTapCancel() => _fabController.reverse();

  /// Finds the horizontal center of the currently-selected tab, in the
  /// coordinate space of the Stack that hosts the pill. Returns null
  /// until the first post-frame layout pass has run (or if the index
  /// is out of range, e.g. transiently during item-list changes).
  double? _selectedTabCenterX(BuildContext stackContext) {
    if (widget.currentIndex < 0 || widget.currentIndex >= _tabKeys.length) {
      return null;
    }

    final BuildContext? tabContext =
        _tabKeys[widget.currentIndex].currentContext;
    final RenderBox? tabBox = tabContext?.findRenderObject() as RenderBox?;
    final RenderBox? stackBox = stackContext.findRenderObject() as RenderBox?;
    if (tabBox == null || stackBox == null || !tabBox.attached) {
      return null;
    }

    final Offset topLeftInStack = tabBox.localToGlobal(
      Offset.zero,
      ancestor: stackBox,
    );
    return topLeftInStack.dx + tabBox.size.width / 2;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    // Separate the nav bar from diary cards that use surfaceContainerHigh.
    final Color navBarBackground = colorScheme.surfaceContainerLowest;

    // Selected pill should feel related to the theme, but not identical
    // to the diary item surface.
    final Color selectedPillColor = isDark ? Colors.white12 : Colors.black12;

    final double diamondBBoxHeight = kFabSize * math.sqrt2;
    final double fabProtrusionHeight = kFabProtrusion * diamondBBoxHeight;

    final double totalHeight =
        kNavBarHeight + fabProtrusionHeight + 4.0 + kBarBottomMargin;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // ---------------- Floating rounded-rectangle bar surface ----
          Positioned(
            left: kBarHorizontalMargin,
            right: kBarHorizontalMargin,
            bottom: kBarBottomMargin,
            height: kNavBarHeight,
            child: Container(
              decoration: BoxDecoration(
                color: navBarBackground,
                borderRadius: BorderRadius.circular(kBarCornerRadius),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.59),
                    blurRadius: kBarShadowBlur,
                    offset: const Offset(0, kBarShadowOffsetY),
                  ),
                ],
              ),
              child: Builder(
                builder: (stackContext) {
                  return Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Sliding selection pill
                      _SelectionPill(
                        getTargetCenterX: () =>
                            _selectedTabCenterX(stackContext),
                        color: selectedPillColor,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kNavItemsHorizontalPadding,
                        ),
                        child: Row(
                          children: [
                            for (int i = 0; i < widget.leftItems.length; i++)
                              Expanded(
                                key: _tabKeys[i],
                                child: _NavItem(
                                  item: widget.leftItems[i],
                                  selected: widget.currentIndex == i,
                                  onTap: () => widget.onTap(i),
                                ),
                              ),
                            SizedBox(width: kFabGapWidth * 0.78),
                            for (int i = 0; i < widget.rightItems.length; i++)
                              Expanded(
                                key: _tabKeys[widget.leftItems.length + i],
                                child: _NavItem(
                                  item: widget.rightItems[i],
                                  selected:
                                      widget.currentIndex ==
                                      widget.leftItems.length + i,
                                  onTap: () =>
                                      widget.onTap(widget.leftItems.length + i),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),

          // ---------------- Floating diamond FAB ----------------
          Positioned(
            bottom: kBarBottomMargin + kNavBarHeight - fabProtrusionHeight,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTapDown: _handleFabTapDown,
                onTapUp: _handleFabTapUp,
                onTapCancel: _handleFabTapCancel,
                child: AnimatedBuilder(
                  animation: _fabScale,
                  builder: (context, child) =>
                      Transform.scale(scale: _fabScale.value, child: child),
                  child: _FloatingDiamondButton(
                    size: kFabSize,
                    cornerRadius: kFabCornerRadius,
                    color: colorScheme.primary,
                    shadowColor: colorScheme.shadow,
                    icon: widget.fabIcon,
                    iconColor: colorScheme.onPrimary,
                    onTap: widget.onFabTap,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Sliding selection pill
// ---------------------------------------------------------------------

class _SelectionPill extends StatefulWidget {
  const _SelectionPill({required this.getTargetCenterX, required this.color});

  final double? Function() getTargetCenterX;
  final Color color;

  @override
  State<_SelectionPill> createState() => _SelectionPillState();
}

class _SelectionPillState extends State<_SelectionPill> {
  double? _lastKnownCenterX;

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final double? measured = widget.getTargetCenterX();
      if (measured != null && measured != _lastKnownCenterX && mounted) {
        setState(() => _lastKnownCenterX = measured);
      }
    });

    final double? centerX = _lastKnownCenterX;

    if (centerX == null) {
      return const SizedBox.shrink();
    }

    return AnimatedPositioned(
      duration: kPillSlideDuration,
      curve: kPillSlideCurve,
      left: centerX - kPillWidth / 2,
      top: (kNavBarHeight - kPillHeight) / 2,
      width: kPillWidth,
      height: kPillHeight,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(kPillCornerRadius),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Individual tab item — icon only, no label.
// ---------------------------------------------------------------------

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavBarItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final Color color = selected
        ? colorScheme.secondary
        : colorScheme.onSurfaceVariant;

    return Tooltip(
      message: item.label,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          height: kNavBarHeight,
          child: Center(
            child: Icon(
              selected ? item.activeIcon : item.icon,
              color: color,
              size: kNavIconSize,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Floating diamond button
// ---------------------------------------------------------------------

class _FloatingDiamondButton extends StatelessWidget {
  const _FloatingDiamondButton({
    required this.size,
    required this.cornerRadius,
    required this.color,
    required this.shadowColor,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  final double size;
  final double cornerRadius;
  final Color color;
  final Color shadowColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final double bbox = size * math.sqrt2;

    return SizedBox(
      width: bbox,
      height: bbox,
      child: Center(
        child: Transform.rotate(
          angle: math.pi / 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(cornerRadius),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: kFabShadowBlur,
                  offset: const Offset(0, kFabShadowOffsetY),
                ),
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.15),
                  blurRadius: kFabShadowBlur * 1.5,
                  offset: const Offset(0, kFabShadowOffsetY),
                ),
              ],
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(cornerRadius),
                onTap: onTap,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Transform.rotate(
                    angle: -math.pi / 4,
                    child: Icon(icon, color: iconColor, size: size * 0.4),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
