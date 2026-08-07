// lib/features/backup/presentation/bloc/backup/backup_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/downloads_directory_resolver.dart';
import '../../domain/entities/export_result.dart';
import '../../domain/entities/import_result.dart';
import '../../domain/entities/pdf_export_result.dart';
import '../../domain/usecases/export_diary_backup.dart';
import '../../domain/usecases/export_diary_pdf.dart';
import '../../domain/usecases/import_diary_backup.dart';

part 'backup_event.dart';
part 'backup_state.dart';

/// Drives the combined Import & Export screen.
///
/// Deliberately one bloc for both `.bubimo` backup/restore AND PDF
/// export rather than separate blocs per operation — all three share
/// the exact same idle/running/success/failure state shape, and the
/// screen presents them as actions on one page (not separate routes),
/// so splitting them would mean multiple blocs independently
/// reinventing identical status-tracking for no separation-of-concerns
/// benefit.
class BackupBloc extends Bloc<BackupEvent, BackupState> {
  final ExportDiaryBackup exportDiaryBackup;
  final ImportDiaryBackup importDiaryBackup;
  final ExportDiaryPdf exportDiaryPdf;

  BackupBloc({
    required this.exportDiaryBackup,
    required this.importDiaryBackup,
    required this.exportDiaryPdf,
  }) : super(const BackupState()) {
    on<BackupExportRequested>(_onExportRequested);
    on<BackupImportRequested>(_onImportRequested);
    on<PdfExportRequested>(_onPdfExportRequested);
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

  Future<void> _onPdfExportRequested(
    PdfExportRequested event,
    Emitter<BackupState> emit,
  ) async {
    if (state.isBusy) return;

    emit(state.cleared(status: BackupStatus.exportingPdf));

    final result = await exportDiaryPdf();

    result.match(
      (failure) => _emitFailureOrCancelled(failure, emit),
      (pdfExportResult) => emit(
        state.copyWith(
          status: BackupStatus.pdfExportSuccess,
          pdfExportResult: pdfExportResult,
        ),
      ),
    );
  }

  /// Routes a failed export/import [Either] to the right state.
  ///
  /// [ExportCancelledException]'s message (surfaced here as
  /// [failure.message] after passing through
  /// [BackupRepositoryImpl]/[PdfExportRepositoryImpl]'s
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