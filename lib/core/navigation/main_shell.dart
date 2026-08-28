// lib/core/navigation/main_shell.dart

import 'package:bubimo/core/navigation/notched_nav_bar.dart';
import 'package:bubimo/core/router/app_router.dart';
import 'package:bubimo/features/profile/presentation/pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../features/profile/presentation/bloc/analytics_bloc.dart';
import '../../features/profile/presentation/bloc/analytics_event.dart';
import '../../features/home/presentation/bloc/diary_list/diary_list_bloc.dart';
import '../../features/home/presentation/bloc/diary_list/diary_list_event.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/profile/presentation/cubit/profile_cubit.dart';
import '../../features/theme/presentation/bloc/theme_list/theme_list_bloc.dart';
import '../../features/theme/presentation/pages/theme_screen.dart';
import '../../features/timeline/presentation/pages/timeline_page.dart';
import '../di/injection.dart';

/// App-wide navigation shell. Owns the bottom navigation bar and an
/// [IndexedStack] of the four top-level tabs: Timeline, Diary, Themes,
/// Profile.
///
/// The bottom bar is a [PillNavBar] — a floating, fully-rounded
/// icon-only capsule with a smooth concave notch cut into its top
/// edge, seating a persistent floating diamond-shaped "+" FAB that
/// always opens the diary create form (see [_openCreateEntry]),
/// regardless of which tab is active. The currently active tab is
/// highlighted by a circular pill that slides between icons. This
/// mirrors the reference design: two tabs, floating FAB, two tabs.
///
/// [PillNavBar] pulls all of its colors from `Theme.of(context)
/// .colorScheme`, so it re-colors automatically whenever the user
/// switches between built-in or custom themes (see
/// `AppThemeCubit`/`theme_mapper.dart`) — no wiring needed here beyond
/// mounting it under the themed `MaterialApp.router` in `main.dart`.
///
/// Back-button behavior: Diary (index 1) is the "home" tab. Pressing
/// system back while on any other tab returns to Diary instead of
/// exiting the app or popping the shell route; pressing back while
/// already on Diary allows the normal pop (app exit / previous route).
class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  static const int _homeIndex = 1; // Diary is the default landing tab.
  static const int _timelineIndex = 0;

  int _currentIndex = _homeIndex;

  // Created once and kept alive for the lifetime of the shell.
  late final DiaryListBloc _diaryListBloc;
  late final ThemeListBloc _themeListBloc;
  late final ProfileCubit _profileCubit;
  late final AnalyticsBloc _analyticsBloc;

  // Guards against rapid repeated taps on the nav bar's FAB opening
  // multiple stacked Create screens.
  bool _isNavigatingToCreate = false;

  static const List<NavBarItem> _leftTabs = [
    NavBarItem(
      label: 'Timeline',
      icon: Icons.calendar_month_outlined,
      activeIcon: Icons.calendar_month,
    ),
    NavBarItem(
      label: 'Diary',
      icon: Icons.book_outlined,
      activeIcon: Icons.book,
    ),
  ];

  static const List<NavBarItem> _rightTabs = [
    NavBarItem(
      label: 'Themes',
      icon: Icons.palette_outlined,
      activeIcon: Icons.palette,
    ),
    NavBarItem(
      label: 'Profile',
      icon: Icons.person_outline,
      activeIcon: Icons.person,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _diaryListBloc = getIt<DiaryListBloc>()..add(const LoadDiaryEntries());
    _themeListBloc = getIt<ThemeListBloc>()..add(const ThemeListLoaded());
    _profileCubit = getIt<ProfileCubit>()..loadProfile();
    _analyticsBloc = getIt<AnalyticsBloc>()..add(const LoadAnalytics());
  }

  @override
  void dispose() {
    _diaryListBloc.close();
    _themeListBloc.close();
    _profileCubit.close();
    _analyticsBloc.close();
    super.dispose();
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    if (index == 1 && _currentIndex != 1) {
      _diaryListBloc.add(LoadDiaryEntries());
    }

    if (index == 3 && _currentIndex != 3) {
      _analyticsBloc.add(LoadAnalytics());
    }
    setState(() => _currentIndex = index);
  }

  Future<void> _openCreateEntry(BuildContext context) async {
    if (_isNavigatingToCreate) return;
    _isNavigatingToCreate = true;

    // Capture which tab was active *before* pushing the form. The FAB
    // is reachable from every tab, so once the form pops back we need
    // to know whether we were sitting on Profile/Analytics — in that
    // case a plain pop would just reveal that screen again instead of
    // showing the entry the user just saved.
    final openedFromIndex = _currentIndex;

    final result = await context.push<bool>(AppRoutes.diaryForm);

    _isNavigatingToCreate = false;

    if (result == true && context.mounted) {
      if (openedFromIndex != _homeIndex) {
        // The FAB is reachable from every tab. Route to the Diary tab
        // instead of letting the pop reveal whichever tab (Timeline,
        // Themes, Profile/Analytics) the entry was created from.
        // `_onTabTapped` both flips the selected pill in `PillNavBar`
        // and (since it's switching *into* index 1) already dispatches
        // `LoadDiaryEntries`, so there's no separate reload needed in
        // this branch.
        _onTabTapped(_homeIndex);
      } else {
        // Already on the Diary tab — just refresh it in place.
        _diaryListBloc.add(const LoadDiaryEntries());
      }
    }
  }

  /// Called when a pop is attempted (system back button / gesture) while
  /// [canPop] below was false, i.e. whenever we're not on the Diary tab.
  /// Instead of letting the pop proceed (which would exit the app), we
  /// redirect the user back to the Diary tab.
  void _handlePopInvoked(bool didPop, Object? result) {
    if (didPop) return; // Already handled elsewhere; nothing to do.

    if (_currentIndex != _homeIndex) {
      _onTabTapped(_homeIndex);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Only allow the system pop (which exits the app / goes to the
      // previous route) when we're already on the Diary "home" tab.
      canPop: _currentIndex == _homeIndex,
      onPopInvokedWithResult: _handlePopInvoked,
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: [
            BlocProvider.value(
              value: _diaryListBloc,
              child: const TimelinePage(),
            ),
            BlocProvider.value(
              value: _diaryListBloc,
              // Home only previews the most recent entries (see
              // HomePage's doc comment / `_maxHomeEntries`); its
              // "View more" row hands off to the Timeline tab — the
              // same tab this IndexedStack already keeps mounted at
              // `_timelineIndex`, fed by this same `_diaryListBloc` —
              // rather than pushing a new route that would just show a
              // second, disconnected copy of the same data.
              child: HomePage(
                onViewMoreInTimeline: () => _onTabTapped(_timelineIndex),
              ),
            ),
            BlocProvider.value(
              value: _themeListBloc,
              child: const ThemeScreen(),
            ),
            MultiBlocProvider(
              providers: [
                BlocProvider.value(value: _profileCubit),
                BlocProvider.value(value: _analyticsBloc),
              ],
              child: const ProfileAnalyticsScreen(),
            ),
          ],
        ),
        extendBody: true,
        bottomNavigationBar: PillNavBar(
          leftItems: _leftTabs,
          rightItems: _rightTabs,
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          onFabTap: () => _openCreateEntry(context),
          fabIcon: Icons.add, // keep the "+" icon
        ),
      ),
    );
  }
}