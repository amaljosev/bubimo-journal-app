// lib/features/app_update/domain/usecases/check_for_update.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/app_update_status.dart';
import '../repositories/app_update_repository.dart';

/// Whether a newer version of the app is available to install.
///
/// Mirrors `CheckOnboardingStatus`'s role in the splash-time
/// `Future.wait([...])` (see `splash_page.dart`'s doc comment and
/// `app_router.dart`'s `redirect`), but keeps the normal
/// `Either<Failure, T>` shape — see `AppUpdateRepository`'s doc
/// comment for why this use case does NOT collapse failures into a
/// plain bool the way `CheckOnboardingStatus` does.
///
/// Usage: `final result = await checkForUpdate();`
class CheckForUpdate {
  final AppUpdateRepository repository;

  const CheckForUpdate(this.repository);

  Future<Either<Failure, AppUpdateStatus>> call() {
    return repository.checkForUpdate();
  }
}