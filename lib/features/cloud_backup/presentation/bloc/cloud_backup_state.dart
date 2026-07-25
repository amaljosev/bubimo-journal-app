// lib/features/cloud_backup/presentation/bloc/cloud_backup_state.dart

part of 'cloud_backup_bloc.dart';

enum CloudBackupStatus {
  /// No operation in progress.
  idle,

  /// Sign-in, backup, restore, delete, or status check in progress.
  busy,

  /// The most recent operation succeeded — see whichever result field
  /// is relevant to what just ran.
  success,

  /// The most recent operation failed — see [CloudBackupState.message].
  failure,
}

extension CloudBackupPhaseLabel on CloudBackupPhase {
  String get label {
    switch (this) {
      case CloudBackupPhase.buildingArchive:
        return 'Preparing your diary…';
      case CloudBackupPhase.uploading:
        return 'Uploading to Google Drive…';
      case CloudBackupPhase.downloading:
        return 'Downloading from Google Drive…';
      case CloudBackupPhase.restoring:
        return 'Restoring entries…';
    }
  }
}

class CloudBackupState extends Equatable {
  final CloudBackupStatus status;
  final bool isSignedIn;

  /// Email of the linked Google account, once known — set after an
  /// interactive sign-in, or after [CloudBackupBloc] restores a
  /// previously-saved session on page open. Used to show the user
  /// which account is linked without prompting them again.
  final String? signedInEmail;

  /// The current cloud backup, if one exists — refreshed after sign-in
  /// and after every successful backup/restore/delete.
  final CloudBackupMetadata? currentBackup;

  /// Set after a successful restore, so the UI can show "Restored N
  /// entries."
  final int? restoredCount;

  final String? message;
  final CloudBackupPhase? phase;

  const CloudBackupState({
    this.status = CloudBackupStatus.idle,
    this.isSignedIn = false,
    this.signedInEmail,
    this.currentBackup,
    this.restoredCount,
    this.message,
    this.phase,
  });

  bool get isBusy => status == CloudBackupStatus.busy;

  CloudBackupState copyWith({
    CloudBackupStatus? status,
    bool? isSignedIn,
    String? signedInEmail,
    CloudBackupMetadata? currentBackup,
    bool clearCurrentBackup = false,
    int? restoredCount,
    String? message,
    CloudBackupPhase? phase,
  }) {
    return CloudBackupState(
      status: status ?? this.status,
      isSignedIn: isSignedIn ?? this.isSignedIn,
      signedInEmail: signedInEmail ?? this.signedInEmail,
      currentBackup: clearCurrentBackup
          ? null
          : (currentBackup ?? this.currentBackup),
      restoredCount: restoredCount ?? this.restoredCount,
      message: message,
      phase: phase,
    );
  }

  @override
  List<Object?> get props => [
        status,
        isSignedIn,
        signedInEmail,
        currentBackup,
        restoredCount,
        message,
        phase,
      ];
}