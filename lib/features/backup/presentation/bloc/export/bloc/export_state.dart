// lib/features/backup/presentation/bloc/export_state.dart

part of 'export_bloc.dart';

enum ExportStatus {
  /// Nothing running, no result to show.
  idle,

  /// PDF export in progress.
  exportingPdf,

  /// Text export in progress.
  exportingText,

  /// A PDF export just succeeded — see [ExportState.pdfExportResult].
  pdfSuccess,

  /// A text export just succeeded — see [ExportState.textExportResult].
  textSuccess,

  /// An export failed — see [ExportState.errorMessage].
  failure,
}

class ExportState extends Equatable {
  final ExportStatus status;
  final PdfExportResult? pdfExportResult;
  final TextExportResult? textExportResult;
  final String? errorMessage;

  const ExportState({
    this.status = ExportStatus.idle,
    this.pdfExportResult,
    this.textExportResult,
    this.errorMessage,
  });

  bool get isBusy =>
      status == ExportStatus.exportingPdf ||
      status == ExportStatus.exportingText;

  @override
  List<Object?> get props =>
      [status, pdfExportResult, textExportResult, errorMessage];
}