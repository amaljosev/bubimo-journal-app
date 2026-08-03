// lib/features/app_update/domain/repositories/app_update_repository.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_update_status.dart';

/// Contract for checking and starting an in-app update.
///
/// Unlike `OnboardingLocalDataSource` (a plain SharedPreferences flag
/// with no real failure mode beyond "treat as false"), an update
/// check has genuine, distinct failure modes worth surfacing to the
/// caller — no Play Store on the device, no network, the Play Store
/// app itself erroring — so this follows the `Either<Failure, T>`
/// shape every other repository in the app uses (see
/// `ThemeRepository`, `BackupRepository`, etc.), not
/// `CheckOnboardingStatus`'s deliberately-plain-`bool` exception.
abstract class AppUpdateRepository {
  /// Asks the platform whether a newer version is available.
  ///
  /// Resolves to `Right(AppUpdateStatus.noUpdateAvailable)` — not a
  /// `Left(Failure)` — for every case where an update simply can't be
  /// offered (iOS, non-Play Android install, no update published):
  /// see `AppUpdateLocalDataSource.checkForUpdate`'s doc comment for
  /// the full reasoning. A `Left` here means the check itself broke
  /// (e.g. Play Store app missing/outdated on an otherwise-Play
  /// device), which is worth distinguishing from "checked, nothing
  /// to offer" if a caller ever wants to log or retry it.
  Future<Either<Failure, AppUpdateStatus>> checkForUpdate();

  /// Starts Play's flexible update flow: begins a background
  /// download and, once it completes, triggers the OS's own
  /// "Update downloaded, restart now?" bottom sheet.
  ///
  /// Only call this after `checkForUpdate` has returned
  /// `AppUpdateStatus.updateAvailable` — starting a flexible update
  /// with none available throws on the platform side, which this
  /// method surfaces as a `Left(Failure)` rather than silently
  /// no-oping, since a caller that gets here skipping the check is a
  /// real bug worth seeing.
  Future<Either<Failure, Unit>> startFlexibleUpdate();
}