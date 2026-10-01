// lib/features/backup/presentation/bloc/export_bloc.dart

import 'package:bubimo/core/error/failures.dart';
import 'package:bubimo/core/utils/downloads_directory_resolver.dart';
import 'package:bubimo/features/backup/domain/entities/pdf_export_result.dart';
import 'package:bubimo/features/backup/domain/entities/text_export_result.dart';
import 'package:bubimo/features/backup/domain/usecases/export_diary_pdf.dart';
import 'package:bubimo/features/backup/domain/usecases/export_diary_text.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';



part 'export_event.dart';
part 'export_state.dart';

/// Drives the Export Diary screen — readable PDF and plain-text copies
/// of the diary. These are one-way exports, not backups; restorable
/// `.bubimo` backups live in [BackupBloc] on the Local Backup screen.
class ExportBloc extends Bloc<ExportEvent, ExportState> {
  final ExportDiaryPdf exportDiaryPdf;
  final ExportDiaryText exportDiaryText;

  ExportBloc({
    required this.exportDiaryPdf,
    required this.exportDiaryText,
  }) : super(const ExportState()) {
    on<ExportPdfRequested>(_onPdfRequested);
    on<ExportTextRequested>(_onTextRequested);
    on<ExportResultAcknowledged>(_onResultAcknowledged);
  }

  Future<void> _onPdfRequested(
    ExportPdfRequested event,
    Emitter<ExportState> emit,
  ) async {
    // Ignore a second tap while any export is already running.
    if (state.isBusy) return;

    emit(const ExportState(status: ExportStatus.exportingPdf));

    final result = await exportDiaryPdf();

    result.match(
      (failure) => _emitFailureOrCancelled(failure, emit),
      (pdfResult) => emit(
        ExportState(
          status: ExportStatus.pdfSuccess,
          pdfExportResult: pdfResult,
        ),
      ),
    );
  }

  Future<void> _onTextRequested(
    ExportTextRequested event,
    Emitter<ExportState> emit,
  ) async {
    if (state.isBusy) return;

    emit(const ExportState(status: ExportStatus.exportingText));

    final result = await exportDiaryText();

    result.match(
      (failure) => _emitFailureOrCancelled(failure, emit),
      (textResult) => emit(
        ExportState(
          status: ExportStatus.textSuccess,
          textExportResult: textResult,
        ),
      ),
    );
  }

  void _onResultAcknowledged(
    ExportResultAcknowledged event,
    Emitter<ExportState> emit,
  ) {
    emit(const ExportState());
  }

  /// A closed save dialog isn't a real error — return quietly to idle
  /// instead of showing a failure dialog. Same message-matching
  /// approach as [BackupBloc._emitFailureOrCancelled].
  void _emitFailureOrCancelled(Failure failure, Emitter<ExportState> emit) {
    if (failure.message == kExportCancelledMessage) {
      emit(const ExportState());
      return;
    }
    emit(
      ExportState(
        status: ExportStatus.failure,
        errorMessage: failure.message,
      ),
    );
  }
}