// lib/features/backup/presentation/bloc/backup/backup_state.dart

part of 'backup_bloc.dart';

enum BackupStatus {
  /// No operation in progress, no result to show.
  idle,

  /// Export in progress — presentation layer should show a blocking
  /// progress indicator, since a large media library could take a
  /// noticeable amount of time to zip.
  exporting,

  /// Import in progress.
  importing,

  /// An export just completed successfully — see
  /// [BackupState.exportResult].
  exportSuccess,

  /// An import just completed successfully — see
  /// [BackupState.importResult]. Note this state is reached even if
  /// [ImportResult.skippedCount] is greater than zero; a nonzero
  /// skipped count is a partial-success detail for the presentation
  /// layer to mention, not a failure state on its own — the operation
  /// as a whole still succeeded.
  importSuccess,

  /// Either operation failed outright — see [BackupState.errorMessage].
  failure,
}

class BackupState extends Equatable {
  final BackupStatus status;
  final ExportResult? exportResult;
  final ImportResult? importResult;
  final String? errorMessage;

  const BackupState({
    this.status = BackupStatus.idle,
    this.exportResult,
    this.importResult,
    this.errorMessage,
  });

  bool get isBusy =>
      status == BackupStatus.exporting || status == BackupStatus.importing;

  BackupState copyWith({
    BackupStatus? status,
    ExportResult? exportResult,
    ImportResult? importResult,
    String? errorMessage,
  }) {
    return BackupState(
      status: status ?? this.status,
      exportResult: exportResult ?? this.exportResult,
      importResult: importResult ?? this.importResult,
      errorMessage: errorMessage,
    );
  }

  /// Returns a state with every result/error field cleared, used both
  /// when starting a new operation (so a stale previous result can't
  /// leak into the new one) and when [BackupResultAcknowledged] fires.
  BackupState cleared({required BackupStatus status}) {
    return BackupState(status: status);
  }

  @override
  List<Object?> get props => [status, exportResult, importResult, errorMessage];
}
