// lib/main.dart

import 'dart:async';

import 'package:bubimo/core/config/secrets.dart';
import 'package:bubimo/core/router/app_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart'
    show FlutterQuillLocalizations;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/di/injection.dart';
import 'core/theme/font/safe_font_service.dart';
import 'features/app_lock/presentation/bloc/lock_bloc.dart';
import 'features/theme/presentation/cubit/app_theme_cubit.dart';

/// Kept alive for the app's lifetime — [AppLifecycleListener] stops
/// notifying once garbage collected, so this can't be a local
/// variable inside [main].
AppLifecycleListener? lifecycleListener;

void main() {
  // Guards the entire startup + app lifetime in one error zone.
  // This is deliberate, not incidental: `google_fonts` fetches a font
  // over HTTP the first time it's used, on a *detached* internal
  // Future nothing in this app ever gets a handle on — if that fetch
  // fails (typically because there's no internet), the resulting
  // exception is unhandled by definition, from wherever it happens to
  // fire, not just from code we wrote. SafeFontService's gating
  // prevents the vast majority of those attempts from ever being made
  // in a situation where they'd fail, but the one residual case it
  // can't see (its cached-fonts registry believes a font is available
  // but the on-disk cache file was removed out from under it — see
  // SafeFontService's doc comment) still needs a last-resort net. This
  // is that net — it's what actually makes "the app should not crash"
  // true regardless of which font-related edge case is hit.
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    await Supabase.initialize(
      url: Secrets.supabaseUrl,
      publishableKey: Secrets.supabaseAnonKey,
    );

    await configureDependencies();

    // Load the persisted "known-good fonts" registry before anything
    // reads it. Cheap (a single SharedPreferences read); every
    // SafeFontService method degrades gracefully even if this were
    // somehow still in flight, so there's no strict ordering
    // requirement beyond "as early as possible".
    await getIt<SafeFontService>().init();

    // Quicksand — the one font bundled as a native asset (see
    // pubspec.yaml) — ships under the SIL Open Font License; this is
    // what google_fonts' own docs recommend doing for any bundled
    // font so its license shows up in Settings' standard licenses
    // page like every other package's.
    LicenseRegistry.addLicense(() async* {
      final license = await rootBundle.loadString(
        'assets/fonts/quicksand/OFL.txt',
      );
      yield LicenseEntryWithLineBreaks(<String>['Quicksand'], license);
    });

    // Load the user's previously selected theme before the first frame,
    // so the app doesn't flash the fallback default theme on launch.
    await getIt<AppThemeCubit>().loadInitialTheme();

    // Load the persisted app-lock config before the first frame too, and
    // AWAIT it — appRouter's `redirect` (see lockRedirect in
    // app_router.dart) reads LockBloc.state synchronously on every
    // navigation, so it must already reflect the real lock type instead
    // of LockState.initial()'s `isLoading: false, lockType: none` before
    // GoRouter's very first redirect evaluation runs. Awaiting the
    // stream here (rather than firing LoadLockConfig and moving on, the
    // way AppThemeCubit's loadInitialTheme is itself awaited above) means
    // by the time runApp() executes, LockBloc.state.isLoading is already
    // back to false and lockType/isLocked are correct.
    // isColdStart: true is essential here — it's what tells LockBloc
    // this load should derive `isLocked` from whether a lock type is
    // configured. Any OTHER place that dispatches LoadLockConfig (e.g.
    // AppLockSettingsPage refreshing on mount) must NOT pass true, or it
    // would re-lock an already-unlocked session. See LoadLockConfig's
    // doc comment in lock_event.dart.
    getIt<LockBloc>().add(const LoadLockConfig(isColdStart: true));
    await getIt<LockBloc>().stream.firstWhere((state) => !state.isLoading);

    // Initialize local notifications (channel setup, timezone data,
    // permission request) before any reminder can be scheduled.
    //await getIt<LocalNotificationService>().initialize();

    // Everything from here down is background font caching — never
    // awaited, never allowed to delay first frame.
    //
    // 1. Sweep every built-in theme font + Font Picker catalog font
    //    right now, in case we're already online (no-ops instantly
    //    for anything already cached).
    // 2. Keep retrying every couple of minutes for whatever's still
    //    missing, so "download everything once the internet comes
    //    back" doesn't depend on the user reopening the app.
    // 3. Also retry the moment the app resumes from background — the
    //    most common real point connectivity actually changes (the
    //    user left to turn on Wi-Fi/data).
    unawaited(getIt<SafeFontService>().precacheAllKnownFonts());
    getIt<SafeFontService>().startBackgroundRetry();
    lifecycleListener = AppLifecycleListener(
      onResume: () => getIt<SafeFontService>().onAppResumed(),
    );

    runApp(const DiaryApp());
  }, (error, stack) {
    debugPrint('Uncaught async error (swallowed, not fatal): $error');
  });
}

class DiaryApp extends StatelessWidget {
  const DiaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AppThemeCubit>.value(value: getIt<AppThemeCubit>()),
        // Provided at the app root (not just inside individual
        // app_lock routes) because LockGate, the settings page, and
        // appRouter's `redirect` callback (which reads
        // getIt<LockBloc>() directly, not via context) all need the
        // one shared LockBloc instance loaded above.
        BlocProvider<LockBloc>.value(value: getIt<LockBloc>()),
      ],
      child: BlocBuilder<AppThemeCubit, ThemeData>(
        builder: (context, themeData) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(1.0),
          ),
            child: MaterialApp.router(
              title: 'Journal App',
              debugShowCheckedModeBanner: false,
              theme: themeData,
              routerConfig: appRouter,
              localizationsDelegates: const [
                FlutterQuillLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
            ),
          );
        },
      ),
    );
  }
}