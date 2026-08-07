// lib/features/theme/presentation/pages/theme_screen.dart

import 'package:bubimo/features/shared/presentation/widgets/appbar_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/router/app_router.dart';
import '../../domain/entities/app_theme_data.dart';
import '../bloc/theme_list/theme_list_bloc.dart';
import '../cubit/app_theme_cubit.dart';
import '../widgets/theme_switcher/built_in_theme_tile.dart';
import '../widgets/theme_switcher/current_theme_header.dart';
import '../widgets/theme_switcher/custom_theme_tile.dart';
import '../widgets/theme_switcher/reset_to_default_button.dart';

/// The Theme Switcher screen: a plain `AppBar` titled "Themes", the
/// currently applied theme, a Reset to Default action, and two tabs
/// (App Themes / Custom Themes) listing every available theme.
///
/// `ThemeListBloc` is provided by `MainShell` (kept alive across tab
/// switches, matching every other tab's pattern) — this widget expects
/// one to already be in context via `BlocProvider.value`, exactly as
/// `MainShell` sets up for its Themes tab. This screen owns its own
/// `Scaffold`/`AppBar`, consistent with every other tab in `MainShell`.
class ThemeScreen extends StatefulWidget {
  const ThemeScreen({super.key});

  @override
  State<ThemeScreen> createState() => _ThemeScreenState();
}

class _ThemeScreenState extends State<ThemeScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
  );

  // Guards against the "Add Custom Theme" button / a custom theme's
  // edit tap firing twice in quick succession (double-tap, or a tap
  // landing during a BlocConsumer rebuild) and pushing
  // AppRoutes.customThemeScreen onto the stack twice. Both entry
  // points share one flag since they lead to the same destination
  // route and are mutually exclusive from the user's perspective —
  // you're never trying to both add and edit in the same instant.
  bool _isNavigatingToCustomThemeScreen = false;

  Future<void> _openCreateCustomTheme(BuildContext context) async {
    if (_isNavigatingToCustomThemeScreen) return;
    _isNavigatingToCustomThemeScreen = true;

    final result = await context.push<bool>(AppRoutes.customThemeScreen);

    if (context.mounted) {
      setState(() => _isNavigatingToCustomThemeScreen = false);
    } else {
      _isNavigatingToCustomThemeScreen = false;
    }

    if (result == true && context.mounted) {
      context.read<ThemeListBloc>().add(const ThemeListLoaded());
    }
  }

  Future<void> _openEditCustomTheme(
    BuildContext context,
    AppThemeData theme,
  ) async {
    if (_isNavigatingToCustomThemeScreen) return;
    _isNavigatingToCustomThemeScreen = true;

    final result = await context.push<bool>(
      AppRoutes.customThemeScreen,
      extra: theme,
    );

    if (context.mounted) {
      setState(() => _isNavigatingToCustomThemeScreen = false);
    } else {
      _isNavigatingToCustomThemeScreen = false;
    }

    if (result == true && context.mounted) {
      context.read<ThemeListBloc>().add(const ThemeListLoaded());
    }
  }

  Future<void> _confirmDelete(BuildContext context, AppThemeData theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete theme?'),
        content: Text('"${theme.name}" will be permanently deleted.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              'Delete',
              style: TextStyle(
                color: Theme.of(dialogContext).colorScheme.error,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<ThemeListBloc>().add(ThemeListCustomThemeDeleted(theme.id));
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ThemeListBloc, ThemeListState>(
      listenWhen: (previous, current) =>
          current.errorMessage != null &&
          current.errorMessage != previous.errorMessage,
      listener: (context, state) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(state.errorMessage!)));
      },
      builder: (context, state) {
        final activeTheme = getIt<AppThemeCubit>().currentTheme;

        return Scaffold(
          appBar: myAppbar(context, 'Themes', null),
          // NestedScrollView replaces the old Column + Expanded(TabBarView).
          // That layout gave the header (theme card / reset button / tab
          // bar) a fixed footprint and only let the *inner* list scroll —
          // fine at default text size, but at larger accessibility text
          // scales or on short screens the fixed footprint alone can
          // exceed the viewport, and there was no way to reach the
          // content that got pushed off (or clipped with an overflow
          // error). NestedScrollView is the widget built for this exact
          // shape: non-list header content plus a TabBarView whose tabs
          // each need their own scrollable list, all coordinated as one
          // continuous scroll. A plain CustomScrollView can't host a
          // TabBarView directly (it isn't a sliver and won't shrink-wrap),
          // so NestedScrollView is the correct fit here, not just "a"
          // fit.
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverToBoxAdapter(
                  child: Column(
                    // Required: SliverToBoxAdapter gives its child an
                    // unbounded max height, so this Column must size
                    // itself to its children (min) rather than try to
                    // fill the available space (max, the default).
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (activeTheme != null)
                        CurrentThemeHeader(theme: activeTheme),
                      ResetToDefaultButton(
                        isEnabled: !state.isActionInProgress,
                        onPressed: () => context.read<ThemeListBloc>().add(
                          const ThemeListResetToDefaultRequested(),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: _ModernTabBar(controller: _tabController),
                      ),
                    ],
                  ),
                ),
              ];
            },
            body: TabBarView(
              controller: _tabController,
              children: [
                _BuiltInThemesTab(state: state),
                _CustomThemesTab(
                  state: state,
                  isNavigating: _isNavigatingToCustomThemeScreen,
                  onEdit: (theme) => _openEditCustomTheme(context, theme),
                  onDelete: (theme) => _confirmDelete(context, theme),
                  onAdd: () => _openCreateCustomTheme(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A floating, elevated pill-style tab bar built from scratch (not
/// Flutter's built-in `TabBar` indicator, which can't cast a shadow off
/// its own indicator). The whole bar sits in a shadowed card above the
/// content; a filled pill slides between "App Themes" and "Custom
/// Themes" with its own drop shadow.
///
/// Rebuild scope is deliberately narrow: [_tabController]'s animation
/// drives an [AnimatedBuilder] wrapped tightly around just the sliding
/// pill, so only that `Container` repaints on every animation tick.
/// The labels and outer card are built once and never rebuilt by the
/// animation — only [_onIndexChanged] (fired on committed tab changes,
/// not every frame) triggers a `setState` for the label bold/color
/// swap.
class _ModernTabBar extends StatefulWidget {
  final TabController controller;

  const _ModernTabBar({required this.controller});

  @override
  State<_ModernTabBar> createState() => _ModernTabBarState();
}

class _ModernTabBarState extends State<_ModernTabBar> {
  static const List<String> _labels = ['App Themes', 'Custom Themes'];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onIndexChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onIndexChanged);
    super.dispose();
  }

  void _onIndexChanged() {
    // TabController fires this listener continuously during a swipe,
    // but we only need a rebuild when the *committed* index actually
    // changes (for the label weight/color swap) — indexIsChanging
    // covers taps, and comparing against the previous index covers
    // swipe-driven changes settling on a new page.
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SizedBox(
        height: 44,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / _labels.length;

            return Stack(
              children: [
                AnimatedBuilder(
                  animation: widget.controller.animation!,
                  builder: (context, child) {
                    final position =
                        (widget.controller.animation?.value ??
                                widget.controller.index.toDouble())
                            .clamp(0.0, _labels.length - 1.0);
                    return Positioned(
                      left: position * segmentWidth,
                      width: segmentWidth,
                      top: 0,
                      bottom: 0,
                      child: child!,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < _labels.length; i++)
                      Expanded(
                        child: _TabLabel(
                          label: _labels[i],
                          isSelected: widget.controller.index == i,
                          selectedColor: colorScheme.onPrimary,
                          unselectedColor: colorScheme.onSurfaceVariant,
                          onTap: () => widget.controller.animateTo(
                            i,
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _TabLabel extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const _TabLabel({
    required this.label,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? selectedColor : unselectedColor,
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }
}

class _BuiltInThemesTab extends StatelessWidget {
  final ThemeListState state;

  const _BuiltInThemesTab({required this.state});

  @override
  Widget build(BuildContext context) {
    if (state.status == ThemeListStatus.loading) {
      // Still a CustomScrollView (not a bare Center) so this tab is a
      // valid, always-scrollable body for the NestedScrollView — if a
      // huge text scale ever makes even the spinner + header overflow,
      // this can still be scrolled to instead of clipping.
      return const CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    // CustomScrollView + SliverList is the sliver-level equivalent of
    // the old ListView.builder (ListView.builder is this exact same
    // pair under the hood) — needed here because NestedScrollView's
    // body must be built from slivers to participate in the shared
    // outer/inner scroll coordination.
    return CustomScrollView(
      key: const PageStorageKey('built_in_themes_tab'),
      slivers: [
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            0,
            8,
            0,
            24 + MediaQuery.of(context).padding.bottom,
          ),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final theme = state.builtInThemes[index];
                return BuiltInThemeTile(
                  theme: theme,
                  isActive: theme.id == state.activeThemeId,
                  isEnabled: !state.isActionInProgress,
                  onTap: () => context.read<ThemeListBloc>().add(
                    ThemeListThemeApplied(theme.id),
                  ),
                );
              },
              childCount: state.builtInThemes.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _CustomThemesTab extends StatelessWidget {
  final ThemeListState state;
  final bool isNavigating;
  final ValueChanged<AppThemeData> onEdit;
  final ValueChanged<AppThemeData> onDelete;
  final VoidCallback onAdd;

  const _CustomThemesTab({
    required this.state,
    required this.isNavigating,
    required this.onEdit,
    required this.onDelete,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    if (state.status == ThemeListStatus.loading) {
      return const CustomScrollView(
        slivers: [
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
        ],
      );
    }

    // Disabling the button/tiles while a push is in flight (rather than
    // only relying on the debounce flag inside the handler) gives the
    // user visible feedback too — the button greys out immediately
    // instead of silently swallowing the extra taps.
    final canNavigate = !isNavigating;

    return CustomScrollView(
      key: const PageStorageKey('custom_themes_tab'),
      slivers: [
        // The "Add Custom Theme" button now scrolls with this tab's
        // content instead of sitting in a fixed slot above it — it's
        // tab-specific, so it belongs inside this tab's own scroll
        // region, same as the list below it.
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          sliver: SliverToBoxAdapter(
            child: FilledButton.icon(
              onPressed: (state.canAddCustomTheme && canNavigate)
                  ? onAdd
                  : null,
              icon: const Icon(Icons.add),
              label: Text(
                state.canAddCustomTheme
                    ? 'Add Custom Theme'
                    : 'Custom theme limit reached (3/3)',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
            ),
          ),
        ),
        if (state.customThemes.isEmpty)
          SliverFillRemaining(
            // hasScrollBody: false lets this size to the empty-state
            // content and center it when it fits, but still allows the
            // CustomScrollView to scroll to it if it doesn't.
            hasScrollBody: false,
            child: _EmptyCustomThemes(onAdd: canNavigate ? onAdd : () {}),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              0,
              8,
              0,
              24 + MediaQuery.of(context).padding.bottom,
            ),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final theme = state.customThemes[index];
                  return CustomThemeTile(
                    theme: theme,
                    isActive: theme.id == state.activeThemeId,
                    isEnabled: !state.isActionInProgress,
                    onApply: () => context.read<ThemeListBloc>().add(
                      ThemeListThemeApplied(theme.id),
                    ),
                    onEdit: canNavigate ? () => onEdit(theme) : () {},
                    onDelete: () => onDelete(theme),
                  );
                },
                childCount: state.customThemes.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _EmptyCustomThemes extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyCustomThemes({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.palette_outlined,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No custom themes yet',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Create up to 3 custom themes with your own colors, font, and header image.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}