// lib/features/cloud_backup/presentation/bloc/cloud_backup_event.dart

part of 'cloud_backup_bloc.dart';

sealed class CloudBackupEvent extends Equatable {
  const CloudBackupEvent();

  @override
  List<Object?> get props => [];
}

/// Interactive sign-in — shows the Google account picker.
final class CloudBackupSignInRequested extends CloudBackupEvent {
  const CloudBackupSignInRequested();
}

/// Fired once on app/page start to silently restore a previous
/// session without prompting.
final class CloudBackupSilentSignInRequested extends CloudBackupEvent {
  const CloudBackupSilentSignInRequested();
}

final class CloudBackupSignOutRequested extends CloudBackupEvent {
  const CloudBackupSignOutRequested();
}

/// Builds a fresh archive and uploads it, replacing any existing cloud
/// backup.
final class CloudBackupNowRequested extends CloudBackupEvent {
  const CloudBackupNowRequested();
}

/// Refreshes [CloudBackupState.currentBackup] from Drive.
final class CloudBackupStatusRequested extends CloudBackupEvent {
  const CloudBackupStatusRequested();
}

final class CloudBackupRestoreRequested extends CloudBackupEvent {
  const CloudBackupRestoreRequested();
}

final class CloudBackupDeleteRequested extends CloudBackupEvent {
  const CloudBackupDeleteRequested();
}

/// Signs out and immediately opens the account picker again — offered
/// when the linked account's Drive has no space left.
final class CloudBackupSwitchAccountRequested extends CloudBackupEvent {
  const CloudBackupSwitchAccountRequested();
}

/// Fired internally by the bloc as the repository reports progress.
final class _CloudBackupProgressUpdated extends CloudBackupEvent {
  final CloudBackupPhase phase;

  const _CloudBackupProgressUpdated(this.phase);

  @override
  List<Object?> get props => [phase];
}