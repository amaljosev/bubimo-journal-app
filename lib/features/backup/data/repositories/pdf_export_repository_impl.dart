// lib/features/backup/data/repositories/pdf_export_repository_impl.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/utils/downloads_directory_resolver.dart';
import '../../domain/entities/pdf_export_result.dart';
import '../../domain/repositories/pdf_export_repository.dart';
import '../datasources/pdf_export_data_source.dart';

/// Implements [PdfExportRepository] by delegating to
/// [PdfExportDataSource] and converting thrown exceptions into a
/// [Failure] — matches [BackupRepositoryImpl]'s convention.
class PdfExportRepositoryImpl implements PdfExportRepository {
  final PdfExportDataSource dataSource;

  const PdfExportRepositoryImpl(this.dataSource);

  @override
  Future<Either<Failure, PdfExportResult>> exportPdf() async {
    try {
      final result = await dataSource.createPdf();
      return Right(result);
    } on ExportCancelledException catch (e) {
      // Not a real failure — see BackupRepositoryImpl.exportBackup's
      // matching catch clause for why this is kept separate from the
      // generic catch below.
      return Left(ImportExportFailure(e.toString()));
    } catch (e) {
      return Left(ImportExportFailure('Failed to create PDF: $e'));
    }
  }
}