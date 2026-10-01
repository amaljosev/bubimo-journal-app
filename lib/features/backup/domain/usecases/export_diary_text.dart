// lib/features/backup/domain/usecases/export_diary_text.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/text_export_result.dart';
import '../repositories/text_export_repository.dart';

/// Generates a human-readable plain-text file (date, title, body — no
/// images) of every diary entry and saves it to disk.
///
/// Usage: `await exportDiaryText()`.
class ExportDiaryText {
  final TextExportRepository repository;

  const ExportDiaryText(this.repository);

  Future<Either<Failure, TextExportResult>> call() {
    return repository.exportText();
  }
}