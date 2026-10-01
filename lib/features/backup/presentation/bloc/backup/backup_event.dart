// lib/features/backup/presentation/bloc/backup/backup_event.dart

part of 'backup_bloc.dart';

sealed class BackupEvent extends Equatable {
  const BackupEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the user taps "Create backup". Runs [ExportDiaryBackup]
/// end-to-end and reports the result via [BackupState.exportResult].
final class BackupExportRequested extends BackupEvent {
  const BackupExportRequested();
}

/// Fired once the user has picked a `.bubimo` file to import (the file
/// picker itself is a presentation-layer concern handled by the page,
/// not this bloc — this event only carries the already-resolved path).
final class BackupImportRequested extends BackupEvent {
  final String filePath;

  const BackupImportRequested(this.filePath);

  @override
  List<Object?> get props => [filePath];
}

/// Fired by the presentation layer once it has fully consumed
/// [BackupState.exportResult]/[BackupState.importResult]/
/// [BackupState.errorMessage] (e.g. shown its confirmation dialog),
/// resetting the bloc back to [BackupStatus.idle] so a stale result
/// isn't re-shown if the state is rebuilt for an unrelated reason.
final class BackupResultAcknowledged extends BackupEvent {
  const BackupResultAcknowledged();
}