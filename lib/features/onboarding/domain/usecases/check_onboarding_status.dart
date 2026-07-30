// lib/features/onboarding/domain/usecases/check_onboarding_status.dart

import '../../data/datasources/onboarding_local_data_source.dart';

/// Whether the user has already completed (or skipped) onboarding.
///
/// Deliberately returns a plain `bool`, not `Either<Failure, bool>`
/// like most other use cases in this app (see `GetReminderSettings`
/// for the usual shape) — this is read synchronously-in-spirit by
/// `app_router.dart`'s `redirect` callback on every navigation, which
/// only needs a yes/no to decide where to send a fresh launch. A
/// database failure here is treated as "not completed" (fail open to
/// showing onboarding again) rather than surfacing a separate error
/// path a router redirect has no good way to display anyway.
///
/// Usage: `await checkOnboardingStatus()`.
class CheckOnboardingStatus {
  final OnboardingLocalDataSource dataSource;

  const CheckOnboardingStatus(this.dataSource);

  Future<bool> call() async {
    try {
      return await dataSource.isOnboardingCompleted();
    } catch (_) {
      return false;
    }
  }
}