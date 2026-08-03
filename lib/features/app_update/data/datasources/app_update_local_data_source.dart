// lib/features/app_update/data/datasources/app_update_local_data_source.dart

import 'dart:io' show Platform;

import 'package:in_app_update/in_app_update.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/app_update_status.dart';

/// Thin wrapper around the `in_app_update` package — the ONLY file in
/// this feature (or the app) that imports it. Everything above this
/// layer (repository, use cases, blocs) works with
/// `AppUpdateStatus`/`Failure` instead, so swapping the underlying
/// package later never touches domain or presentation code.
///
/// `in_app_update` wraps Android's Play Core in-app-update API. It is
/// unconditionally Android-only — there's no iOS implementation to
/// even call into, and on Android it further requires the app to be
/// a real Play Store install (a debug build or side loaded APK has no
/// "current version per Play" to compare against, so the plugin
/// throws instead of just returning "no update"). Both cases are
/// handled by `Platform.isAndroid` gating below rather than a
/// try/catch, per 's explicit choice: skip entirely and silently
/// on iOS/non-Play, never surface it as an error or a blocked UI
/// state.
class AppUpdateLocalDataSource {
  const AppUpdateLocalDataSource();

  /// Returns `AppUpdateStatus.noUpdateAvailable` immediately, without
  /// touching the platform channel at all, on any non-Android
  /// platform. On Android, asks Play what it knows and maps the
  /// result down to the two-value `AppUpdateStatus` — see that
  /// entity's doc comment for why `updatePriority` /
  /// `availableVersionCode` etc. aren't threaded through.
  ///
  /// Can throw [AppUpdateException] — a real Android/Play-Store
  /// device where the Play Store app itself is missing, disabled, or
  /// too outdated to answer is a genuine, distinct failure the
  /// repository maps to a `Left(AppUpdateFailure)`, not folded into
  /// `noUpdateAvailable` here. That folding already happens for the
  /// "no update / not Play-eligible" cases above; this is
  /// specifically for "the check itself broke".
  Future<AppUpdateStatus> checkForUpdate() async {
    if (!Platform.isAndroid) {
      return AppUpdateStatus.noUpdateAvailable;
    }

    try {
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();

      final bool isAvailable =
          info.updateAvailability == UpdateAvailability.updateAvailable;

      // flexibleUpdateAllowed can be false even when an update
      // exists — Play can restrict a given release to immediate-
      // only. This app never offers immediate (see
      // StartFlexibleUpdate's doc comment), so a flexible-blocked
      // update collapses into "nothing to offer" here rather than a
      // status the presentation layer has no action for.
      if (isAvailable && info.flexibleUpdateAllowed) {
        return AppUpdateStatus.updateAvailable;
      }

      return AppUpdateStatus.noUpdateAvailable;
    } catch (e) {
      // Catches whatever the raw plugin throws (typically a
      // PlatformException — Play Store app missing/disabled/
      // outdated) and re-throws as the typed exception this feature
      // owns, so AppUpdateRepositoryImpl only ever needs to catch
      // AppUpdateException, the same one-exception-type-per-layer-
      // boundary convention every other data source in this app
      // follows (see AppDatabaseException, MediaStorageException,
      // etc. in exceptions.dart).
      throw AppUpdateException(
        message: 'Failed to check for update: ${e.toString()}',
      );
    }
  }

  /// Starts the flexible download and arranges for the OS's own
  /// "restart to finish updating?" bottom sheet to appear once it's
  /// done.
  ///
  /// `in_app_update` does not fire that prompt on its own — it fires
  /// only when something calls `InAppUpdate.completeFlexibleUpdate()`
  /// after the download has actually finished. The `.then(...)` below
  /// is that something: `startFlexibleUpdate()`'s returned Future
  /// resolves once the user has responded to Play's own "start this
  /// download?" consent dialog AND the background download completes,
  /// so checking `AppUpdateResult.success` there and immediately
  /// calling `completeFlexibleUpdate()` is sufficient — no separate
  /// progress-polling loop needed. **Verify this against the
  /// `in_app_update` version actually in pubspec.yaml when pasting
  /// this in**: `AppUpdateResult` has been a stable 3-value enum
  /// (`success` / `userDeniedUpdate` / `inAppUpdateFailed`) across the
  /// versions I'm confident about, but package internals can shift
  /// between majors and I don't have live access to pub.dev/GitHub
  /// from here to confirm the exact version pinned in this project. If
  /// `flutter analyze` flags this block, the enum values or method
  /// name are the first place to check. If the user dismisses the
  /// resulting native "restart to finish updating?" sheet, Play
  /// re-shows it automatically the next time the app foregrounds with
  /// the update still pending — Play Core's responsibility, not this
  /// code's.
  ///
  /// Deliberately no-op on non-Android — see class doc comment.
  /// Calling this without having first observed
  /// `AppUpdateStatus.updateAvailable` from `checkForUpdate` throws
  /// [AppUpdateException] on the Android side; that is intentional,
  /// not guarded against here, so a misuse bug is visible instead of
  /// silently swallowed.
  Future<void> startFlexibleUpdate() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      final AppUpdateResult result = await InAppUpdate.startFlexibleUpdate();
      if (result == AppUpdateResult.success) {
        // Fire-and-forget by design: this is the terminal step of
        // the flow — the resulting native prompt asks the user to
        // restart, and nothing in this app needs to react to
        // whatever the user chooses there.
        InAppUpdate.completeFlexibleUpdate();
      }
    } catch (e) {
      throw AppUpdateException(
        message: 'Failed to start update: ${e.toString()}',
      );
    }
  }
}