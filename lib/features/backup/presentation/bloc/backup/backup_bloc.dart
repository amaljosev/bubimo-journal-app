// lib/features/backup/presentation/bloc/backup/backup_bloc.dart

import 'package:bubimo/core/error/failures.dart';
import 'package:bubimo/core/utils/downloads_directory_resolver.dart';
import 'package:bubimo/features/backup/domain/entities/export_result.dart';
import 'package:bubimo/features/backup/domain/entities/import_result.dart';
import 'package:bubimo/features/backup/domain/usecases/export_diary_backup.dart';
import 'package:bubimo/features/backup/domain/usecases/import_diary_backup.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';



part 'backup_event.dart';
part 'backup_state.dart';

/// Drives the Local Backup screen — creating and restoring `.bubimo`
/// backup files.
///
/// Readable exports (PDF / TXT) used to share this bloc but now live in
/// [ExportBloc] on their own screen: mixing a restorable backup with a
/// readable copy on one page confused users about which one to use.
class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final ExportDiaryBackup exportDiaryBackup;
  final ImportDiaryBackup importDiaryBackup;

  BackupBloc({
    required this.exportDiaryBackup,
    required this.importDiaryBackup,
  }) : super(const BackupState()) {
    on<BackupExportRequested>(_onExportRequested);
    on<BackupImportRequested>(_onImportRequested);
    on<BackupResultAcknowledged>(_onResultAcknowledged);
  }

  Future<void> _onExportRequested(
    BackupExportRequested event,
    Emitter<BackupState> emit,
  ) async {
    // Guard against a duplicate tap firing a second export while one is
    // already running — same guard pattern as DiaryFormBloc._onSubmitted.
    if (state.isBusy) return;

    emit(state.cleared(status: BackupStatus.exporting));

    final result = await exportDiaryBackup();

    result.match(
      (failure) => _emitFailureOrCancelled(failure, emit),
      (exportResult) => emit(
        state.copyWith(
          status: BackupStatus.exportSuccess,
          exportResult: exportResult,
        ),
      ),
    );
  }

  Future<void> _onImportRequested(
    BackupImportRequested event,
    Emitter<BackupState> emit,
  ) async {
    if (state.isBusy) return;

    emit(state.cleared(status: BackupStatus.importing));

    final result = await importDiaryBackup(event.filePath);

    result.match(
      (failure) => emit(
        state.copyWith(
          status: BackupStatus.failure,
          errorMessage: failure.message,
        ),
      ),
      (importResult) => emit(
        state.copyWith(
          status: BackupStatus.importSuccess,
          importResult: importResult,
        ),
      ),
    );
  }

  void _onResultAcknowledged(
    BackupResultAcknowledged event,
    Emitter<BackupState> emit,
  ) {
    emit(state.cleared(status: BackupStatus.idle));
  }

  /// Routes a failed export [Either] to the right state.
  ///
  /// [ExportCancelledException]'s message (surfaced here as
  /// [failure.message] after passing through [BackupRepositoryImpl]'s
  /// `ExportCancelledException` catch clause) means the user simply
  /// closed the save-file dialog — not a real error, so this quietly
  /// returns to idle instead of surfacing a red failure banner the way
  /// every other [Failure] does. String-matching the message is a bit
  /// fragile, but avoids introducing a dedicated Failure subclass just
  /// for this one bloc to special-case.
  void _emitFailureOrCancelled(Failure failure, Emitter<BackupState> emit) {
    if (failure.message == kExportCancelledMessage) {
      emit(state.cleared(status: BackupStatus.idle));
      return;
    }
    emit(
      state.copyWith(
        status: BackupStatus.failure,
        errorMessage: failure.message,
      ),
    );
  }
}