// lib/features/onboarding/domain/usecases/complete_onboarding.dart

import '../../data/datasources/onboarding_local_data_source.dart';

/// Marks onboarding as completed so it won't be shown again on
/// future launches. Called once — from `OnboardingPage.onCompleted`,
/// via "Skip" or the last page's "Get started" — never re-checked or
/// reversible from within the app itself.
///
/// Usage: `await completeOnboarding()`.
class CompleteOnboarding {
  final OnboardingLocalDataSource dataSource;

  const CompleteOnboarding(this.dataSource);

  Future<void> call() => dataSource.setOnboardingCompleted();
}