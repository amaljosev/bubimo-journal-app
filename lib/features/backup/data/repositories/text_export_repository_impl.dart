// lib/features/backup/data/repositories/text_export_repository_impl.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/downloads_directory_resolver.dart';
import '../../domain/entities/text_export_result.dart';
import '../../domain/repositories/text_export_repository.dart';
import '../datasources/text_export_data_source.dart';

/// Implements [TextExportRepository] by delegating to
/// [TextExportDataSource] and converting thrown exceptions into a
/// [Failure] — same convention as [PdfExportRepositoryImpl].
class TextExportRepositoryImpl implements TextExportRepository {
  final TextExportDataSource dataSource;

  const TextExportRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, TextExportResult>> exportText() async {
    try {
      final result = await dataSource.createText();
      return Right(result);
    } on ExportCancelledException catch (e) {
      // Not a real failure — the user closed the save dialog. Kept
      // separate from the generic catch below so ExportBloc can detect
      // it by message (see ExportBloc._emitFailureOrCancelled).
      return Left(ImportExportFailure(e.toString()));
    } catch (e) {
      return Left(ImportExportFailure('Failed to create text file: $e'));
    }
  }
}