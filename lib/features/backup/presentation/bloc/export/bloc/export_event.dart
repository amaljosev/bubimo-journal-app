// lib/features/backup/presentation/bloc/export_event.dart

part of 'export_bloc.dart';

sealed class ExportEvent extends Equatable {
  const ExportEvent();

  @override
  List<Object?> get props => [];
}

/// Fired when the user taps "Download PDF".
final class ExportPdfRequested extends ExportEvent {
  const ExportPdfRequested();
}

/// Fired when the user taps "Download TXT".
final class ExportTextRequested extends ExportEvent {
  const ExportTextRequested();
}

/// Fired once the page has shown the result/error dialog, returning
/// the bloc to [ExportStatus.idle] so a stale result isn't re-shown.
final class ExportResultAcknowledged extends ExportEvent {
  const ExportResultAcknowledged();
}