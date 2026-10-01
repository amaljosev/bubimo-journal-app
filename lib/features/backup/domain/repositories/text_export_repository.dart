// lib/features/backup/domain/repositories/text_export_repository.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/text_export_result.dart';

/// Contract for generating a human-readable plain-text file of every
/// diary entry, implemented by `TextExportRepositoryImpl` in the data
/// layer. Separate from [PdfExportRepository] and [BackupRepository]
/// for the same reason those two are separate from each other: one
/// repository per distinct output.
abstract class TextExportRepository {
  /// Generates a UTF-8 `.txt` file containing every non-deleted diary
  /// entry's date, title, and plain-text body (no images), and saves
  /// it to disk.
  Future<Either<Failure, TextExportResult>> exportText();
}