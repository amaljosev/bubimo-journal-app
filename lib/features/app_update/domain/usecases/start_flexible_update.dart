// lib/features/app_update/domain/usecases/start_flexible_update.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../repositories/app_update_repository.dart';

/// Begins downloading an available update in the background.
///
/// Deliberately the ONLY update-starting use case in this feature —
/// there is no `StartImmediateUpdate` sibling. Play's "immediate"
/// flow (full-screen, blocks the user until the update finishes) is
/// for updates you want to force; this app only ever offers the
/// flexible flow, where the user keeps using the app while it
/// downloads in the background and is prompted to restart once it's
/// ready — see `AppUpdateStatus`'s doc comment for the same reasoning
/// applied on the read side. If a forced-update requirement ever
/// comes up, add the immediate variant then rather than building an
/// unused code path now.
///
/// The OS-native "restart to finish updating?" prompt is triggered
/// automatically once the download completes — see
/// `AppUpdateLocalDataSource.startFlexibleUpdate`'s doc comment for
/// where that listener lives. Nothing in the presentation layer needs
/// to poll for completion or show its own UI for that step.
///
/// Usage: `final result = await startFlexibleUpdate();`
class StartFlexibleUpdate {
  final AppUpdateRepository repository;

  const StartFlexibleUpdate(this.repository);

  Future<Either<Failure, Unit>> call() {
    return repository.startFlexibleUpdate();
  }
}