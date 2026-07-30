// lib/features/onboarding/data/datasources/onboarding_local_data_source.dart

import 'package:shared_preferences/shared_preferences.dart';

/// Reads/writes whether the user has completed onboarding, via
/// SharedPreferences rather than the `app_settings` SQLite table.
///
/// Onboarding completion is a one-shot device flag ("has this device
/// seen the intro flow"), not app data that needs to live alongside
/// reminders/theme/lock config in the shared singleton row — so it
/// gets its own, simpler storage mechanism instead of a schema column
/// and migration. (An earlier version of this feature did store it in
/// `app_settings.onboarding_completed`; that column is no longer read
/// or written by anything — see `AppDatabase`'s doc comment for why
/// it's left in place, unused, for installs that already migrated
/// past it.)
class OnboardingLocalDataSource {
  static const String _onboardingCompletedKey = 'onboarding_completed';

  const OnboardingLocalDataSource();

  Future<bool> isOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingCompletedKey) ?? false;
  }

  Future<void> setOnboardingCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingCompletedKey, true);
  }
}