// lib/features/backup/domain/entities/text_export_result.dart

import 'package:equatable/equatable.dart';

/// Outcome of a successful plain-text (`.txt`) diary export — same
/// shape as [PdfExportResult] so the presentation layer can report
/// both the same way.
class TextExportResult extends Equatable {
  /// Where the file ended up on disk.
  final String filePath;

  /// How many diary entries were written to the file.
  final int entryCount;

  /// True if the file went to the public Downloads folder, false if it
  /// fell back to the app's own storage.
  final bool savedToPublicDownloads;

  const TextExportResult({
    required this.filePath,
    required this.entryCount,
    required this.savedToPublicDownloads,
  });

  @override
  List<Object?> get props => [filePath, entryCount, savedToPublicDownloads];
}