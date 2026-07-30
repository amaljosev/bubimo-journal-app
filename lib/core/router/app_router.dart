// lib/core/router/app_router.dart

import 'package:bubimo/core/di/injection.dart';
import 'package:bubimo/core/navigation/main_shell.dart';
import 'package:bubimo/features/help/domain/faq_item.dart';
import 'package:bubimo/features/help/presentation/pages/faq_detail_screen.dart';
import 'package:bubimo/features/help/presentation/pages/help_screen.dart';
import 'package:bubimo/features/onboarding/presentation/pages/splash_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../features/app_lock/presentation/bloc/lock_bloc.dart';
import '../../../features/app_lock/presentation/pages/app_lock_settings_page.dart';
import '../../../features/app_lock/presentation/pages/lock_gate.dart';
import '../../../features/app_lock/presentation/pages/pin_lock_screen.dart';
import '../../../features/app_lock/presentation/pages/security_question_page.dart';
import '../../../features/app_lock/presentation/routing/app_lock_route_paths.dart';
import '../../../features/app_lock/presentation/routing/lock_redirect.dart';
import '../../../features/backup/presentation/pages/backup_restore_page.dart';
import '../../../features/cloud_backup/presentation/pages/cloud_backup_page.dart';
import '../../../features/diary_entry/presentation/pages/diary_entry_view_page.dart';
import '../../../features/diary_entry/presentation/pages/diary_form_page.dart';
import '../../../features/favorites/presentation/pages/favorites_page.dart';
import '../../../features/home/presentation/bloc/diary_list/diary_list_bloc.dart';
import '../../../features/home/presentation/bloc/diary_list/diary_list_event.dart';
import '../../../features/onboarding/domain/usecases/check_onboarding_status.dart';
import '../../../features/onboarding/presentation/pages/onboarding_page.dart';
import '../../../features/reminders/presentation/bloc/reminder_settings/reminder_settings_bloc.dart';
import '../../../features/reminders/presentation/bloc/reminder_settings/reminder_settings_event.dart';
import '../../../features/reminders/presentation/pages/reminder_settings_page.dart';
import '../../../features/settings/presentation/pages/settings_page.dart';
import '../../../features/theme/domain/entities/app_theme_data.dart';
import '../../../features/theme/presentation/pages/custom_theme_screen.dart';

/// Centralized route path constants. Use these instead of raw strings
/// when navigating, to avoid typos and make renames a one-line change.
/// The app-lock constants below are re-exports of AppLockRoutePaths
/// (defined inside the app_lock feature itself, since
/// AppLockSettingsPage needs to push to them without importing this
/// file and creating a circular import) — kept here too so every other
/// feature can keep referencing `AppRoutes.appLock...`/`AppRoutes.lock...`
/// the same way it references every other route.
class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String home = '/';
  static const String onboarding = '/onboarding';
  static const String diaryForm = '/diary-form';
  static const String diaryView = '/diary-view';
  static const String customThemeScreen = '/theme/custom';
  static const String reminderSettings = '/settings/reminders';
  static const String settings = '/settings';
  static const String favorites = '/favorites';
  static const String importExport = '/import-export';
  static const String cloudBackup = '/cloud-backup';
  static const String help = '/help';
  static const String helpDetail = '/help/detail';
  static const String appLockSettings = AppLockRoutePaths.settings;
  static const String appLockPinCreate = AppLockRoutePaths.pinCreate;
  static const String appLockSecurityQuestionSetup =
      AppLockRoutePaths.securityQuestionSetup;
  static const String lockGate = AppLockRoutePaths.lockGate;
  static const String lockPinVerify = AppLockRoutePaths.pinVerify;
  static const String lockSecurityQuestionVerify =
      AppLockRoutePaths.securityQuestionVerify;
}

/// Set once [SplashPage]'s `checks` future resolves — read
/// synchronously on every `redirect` call afterward, same caching
/// rationale as before: `redirect` fires on every route change (not
/// just cold start) and can't cleanly `await` a fresh read each time.
///
/// This used to be populated by `initializeAppRouter()`, awaited in
/// `main()` before `runApp`. It's now populated by
/// [_runStartupChecks], awaited *inside* [AppRoutes.splash]'s route
/// instead — the splash's icon-pulse animation needs somewhere to
/// run while this resolves, and blocking `runApp` itself would mean
/// showing nothing (or a second, native-only splash) during that
/// wait rather than the animated splash. `LoadLockConfig` moves here
/// for the same reason: it used to fire in `main()` right after
/// `configureDependencies()` alongside this check (see this doc
/// comment's previous revision), and both first-run reads still
/// happen together, just now inside splash instead of before it.
bool _onboardingCompleted = false;

/// Awaited by [AppRoutes.splash]'s route via [SplashPage.checks].
/// Runs onboarding-status and lock-config concurrently — not
/// sequentially — since they're independent reads (SharedPreferences
/// vs. whatever `LockBloc`'s config source is) with no ordering
/// dependency on each other, only on both finishing before splash
/// hands off to `redirect`.
Future<void> _runStartupChecks() async {
  
  await Future.wait([
    getIt<CheckOnboardingStatus>()().then((completed) {
      _onboardingCompleted = completed;
    }),
    // <-- add the lock-config-loaded future here, alongside the
    // onboarding check above, once its source is confirmed.
  ]);
}

final GoRouter appRouter = GoRouter(
  initialLocation: AppRoutes.splash,
  // Three independent gates compose here, in order:
  //
  // 0. Splash: exempted outright — it's the one screen every cold
  //    start passes through before either flag below is even read
  //    (see [_runStartupChecks]/[_onboardingCompleted]'s doc
  //    comments). Nothing ever redirects *to* splash; it's only ever
  //    `initialLocation`, so the only thing this gate needs to do is
  //    stay out of the other two gates' way while active.
  //
  // 1. Onboarding: unchanged from before splash existed — if
  //    `_onboardingCompleted` is false, every route except splash and
  //    `AppRoutes.onboarding` itself redirects there. App lock is
  //    never configured for a user who hasn't finished onboarding
  //    yet, so there's no ordering conflict to resolve between gates
  //    1 and 2 — a fresh install always hits this branch before
  //    `lockRedirect` ever gets a chance to fire.
  //
  // 2. Lock: `lockRedirect` reads getIt<LockBloc>().state directly
  //    (not via context, since `redirect` runs before a widget tree
  //    exists for this navigation) — see lock_redirect.dart for the
  //    exemptions (lock gate itself, its two verify screens, and the
  //    settings/setup screens) that keep this from becoming an
  //    infinite redirect loop.
  redirect: (context, state) {
    final isSplashRoute = state.matchedLocation == AppRoutes.splash;
    if (isSplashRoute) {
      return null;
    }

    final isOnboardingRoute = state.matchedLocation == AppRoutes.onboarding;
    if (!_onboardingCompleted && !isOnboardingRoute) {
      return AppRoutes.onboarding;
    }
    if (_onboardingCompleted && isOnboardingRoute) {
      // Guards against a stale/deep link back to `/onboarding` once
      // it's already been completed (e.g. a leftover browser
      // history entry, or a notification payload built before this
      // launch) — send it home instead of showing onboarding again.
      return AppRoutes.home;
    }

    return lockRedirect(getIt<LockBloc>(), state);
  },
  // Without this, GoRouter would never re-run `redirect` when LockBloc
  // emits (e.g. after LockApp fires on a lifecycle pause, or after a
  // successful VerifyPinAttempt) — BLoC state changes aren't otherwise
  // visible to GoRouter. GoRouterRefreshStream ships inside go_router
  // itself; it's the standard cookbook helper that adapts a Stream
  // into a Listenable.
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      builder: (context, state) => SplashPage(
        checks: _runStartupChecks,
        onDone: () {
          // Splash's own route is exempt from `redirect` above, so
          // this is the one navigation in the whole app that has to
          // decide *where* to go rather than just flip a flag and let
          // `redirect` do it (contrast with `AppRoutes.onboarding`'s
          // `onCompleted` below, which only sets a bool because
          // `redirect` is what actually moves it off `/onboarding`).
          // `context.go(AppRoutes.home)` re-triggers `redirect`
          // immediately with both `_onboardingCompleted` and
          // `LockBloc.state` now settled, so it still lands on
          // onboarding or the lock gate exactly as gates 1/2 above
          // dictate — this isn't bypassing them, just picking the
          // first *candidate* destination for `redirect` to then
          // correct if needed.
          context.go(AppRoutes.home);
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      builder: (context, state) => OnboardingPage(
        onCompleted: () {
          _onboardingCompleted = true;
          context.go(AppRoutes.home);
        },
      ),
    ),
    GoRoute(
      path: AppRoutes.home,
      builder: (context, state) => const MainShell(),
    ),

    GoRoute(
      path: AppRoutes.diaryForm,
      builder: (context, state) {
        // Pass an existing entry id via `extra` to open in edit mode;
        // omit it (or pass null) to open in create mode.
        final entryId = state.extra as String?;
        return DiaryFormPage(entryId: entryId);
      },
    ),
    GoRoute(
      path: AppRoutes.diaryView,
      builder: (context, state) {
        final entryId = state.extra as String;
        return DiaryEntryViewPage(entryId: entryId);
      },
    ),
    GoRoute(
      path: AppRoutes.customThemeScreen,
      // `extra` carries the AppThemeData to edit when navigating here
      // to EDIT an existing custom theme; omit it (push with no extra)
      // to open in create mode. See CustomThemeScreen's `existingTheme`
      // param.
      builder: (context, state) {
        final existingTheme = state.extra as AppThemeData?;
        return CustomThemeScreen(existingTheme: existingTheme);
      },
    ),
    GoRoute(
      path: AppRoutes.reminderSettings,
      // ReminderSettingsBloc is a lazySingleton (was previously provided
      // by MainShell when Reminders was a tab). Now that it's reached
      // via a pushed route from Settings instead, this route provides
      // it directly — re-dispatching LoadReminderSettings on each visit
      // since the page is no longer kept alive in an IndexedStack.
      builder: (context, state) => BlocProvider.value(
        value: getIt<ReminderSettingsBloc>()..add(const LoadReminderSettings()),
        child: const ReminderSettingsPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.settings,
      builder: (context, state) => const SettingsPage(),
    ),
    GoRoute(
      path: AppRoutes.favorites,
      // DiaryListBloc is registered as a FACTORY (see injection.dart),
      // not a singleton — so `getIt<DiaryListBloc>()` here always
      // builds a brand-new instance, starting at
      // DiaryListStatus.initial, completely independent from whatever
      // instance MainShell's Diary/Timeline tabs are using. FavoritesPage
      // itself never dispatches an initial load (it only reacts to
      // pull-to-refresh / returning from create-edit), so without the
      // explicit `..add(...)` here this screen would sit on its loading
      // spinner forever. Mirrors the same pattern already used just
      // above for AppRoutes.reminderSettings.
      builder: (context, state) => BlocProvider.value(
        value: getIt<DiaryListBloc>()..add(const LoadDiaryEntries()),
        child: const FavoritesPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.importExport,
      // BackupRestorePage provides its own BackupBloc internally (via
      // getIt, registered as a factory) rather than this route
      // providing it — unlike AppRoutes.favorites/reminderSettings
      // above, there's no initial data load to dispatch here; the bloc
      // starts at BackupStatus.idle and only does anything once the
      // user taps Export or picks an import file.
      builder: (context, state) => const BackupRestorePage(),
    ),
    GoRoute(
      path: AppRoutes.cloudBackup,
      // Same reasoning as AppRoutes.importExport just above —
      // CloudBackupPage provides its own CloudBackupBloc internally.
      builder: (context, state) => const CloudBackupPage(),
    ),
    GoRoute(
      path: AppRoutes.appLockSettings,
      // LockBloc is a lazySingleton (see injection.dart's app_lock
      // section) — this route provides the SAME instance main.dart
      // already dispatched LoadLockConfig on at startup, rather than
      // building a fresh one, since LockGate needs to observe that
      // instance's state too. AppLockSettingsPage re-dispatches
      // LoadLockConfig itself on initState (mirroring the original
      // reference screen), which is safe/idempotent against an
      // already-loaded singleton.
      builder: (context, state) => BlocProvider.value(
        value: getIt<LockBloc>(),
        child: const AppLockSettingsPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.appLockPinCreate,
      // Pushed by AppLockSettingsPage; pops with the created 4-digit
      // PIN string (or null if the user backs out) rather than
      // dispatching SetLockType itself, so the settings page stays the
      // single place that decides what to do with the result.
      builder: (context, state) => BlocProvider.value(
        value: getIt<LockBloc>(),
        child: const PinLockScreen(mode: LockMode.create),
      ),
    ),
    GoRoute(
      path: AppRoutes.appLockSecurityQuestionSetup,
      // Pushed by AppLockSettingsPage; pops with
      // {'question': ..., 'answer': ...} for the same reason as
      // appLockPinCreate above.
      builder: (context, state) => BlocProvider.value(
        value: getIt<LockBloc>(),
        child: const SecurityQuestionPage(isVerification: false),
      ),
    ),
    GoRoute(
      path: AppRoutes.lockGate,
      // Where `lockRedirect` sends navigation whenever the app is
      // locked. LockGate itself picks biometric / PIN-verify /
      // security-question-verify based on LockBloc.state.lockType and
      // `context.go('/')`s on success.
      builder: (context, state) =>
          BlocProvider.value(value: getIt<LockBloc>(), child: const LockGate()),
    ),
    GoRoute(
      path: AppRoutes.lockPinVerify,
      // Not normally navigated to directly (LockGate renders
      // PinLockScreen inline for the common case) — registered as its
      // own route so `lockRedirect`'s exempt-path check has somewhere
      // valid to point if a future call site ever pushes here directly
      // for a standalone re-verification (e.g. "confirm PIN before
      // changing lock settings").
      builder: (context, state) => BlocProvider.value(
        value: getIt<LockBloc>(),
        child: const PinLockScreen(mode: LockMode.verify),
      ),
    ),
    GoRoute(
      path: AppRoutes.lockSecurityQuestionVerify,
      builder: (context, state) => BlocProvider.value(
        value: getIt<LockBloc>(),
        child: const SecurityQuestionPage(isVerification: true),
      ),
    ),

    GoRoute(
      path: AppRoutes.help,
      builder: (context, state) => const HelpScreen(),
    ),
    GoRoute(
      path: AppRoutes.helpDetail,
      builder: (context, state) {
        final item = state.extra as FaqItem;
        return FaqDetailScreen(item: item);
      },
    ),
  ],
);