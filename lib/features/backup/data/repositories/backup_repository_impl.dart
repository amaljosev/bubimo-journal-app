// lib/features/backup/data/repositories/backup_repository_impl.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/utils/downloads_directory_resolver.dart';
import '../../domain/entities/export_result.dart';
import '../../domain/entities/import_result.dart';
import '../../domain/repositories/backup_repository.dart';
import '../datasources/backup_local_data_source.dart';

/// Implements [BackupRepository] by delegating to
/// [BackupLocalDataSource] and converting thrown exceptions into a
/// [Failure] — matches [DiaryRepositoryImpl]'s convention exactly.
///
/// [ImportExportException] (a bundle-level problem — bad manifest,
/// unreadable archive, incompatible format version) is mapped to
/// [ImportExportFailure] with its original message preserved, so the
/// presentation layer can show the specific reason rather than a
/// generic error. Any other exception (file I/O, unexpected parsing
/// error) falls back to a general [ImportExportFailure] message.
class BackupRepositoryImpl implements BackupRepository {
  final BackupLocalDataSource localDataSource;

  const BackupRepositoryImpl(this.localDataSource);

  @override
  Future<Either<Failure, ExportResult>> exportBackup() async {
    try {
      final result = await localDataSource.createBackup();
      return Right(result);
    } on ExportCancelledException catch (e) {
      // Not a real failure — the user just closed the save dialog. Kept
      // as its own catch (rather than falling into the generic one
      // below, which prefixes "Failed to create backup: ") so
      // BackupBloc can recognize kExportCancelledMessage exactly and
      // quietly return to idle instead of showing a red error.
      return Left(ImportExportFailure(e.toString()));
    } on MediaStorageException catch (e) {
      return Left(MediaStorageFailure(e.message));
    } catch (e) {
      return Left(ImportExportFailure('Failed to create backup: $e'));
    }
  }

  @override
  Future<Either<Failure, ImportResult>> importBackup(String filePath) async {
    try {
      final result = await localDataSource.importBackup(filePath);
      return Right(result);
    } on ImportExportException catch (e) {
      return Left(ImportExportFailure(e.message));
    } on MediaStorageException catch (e) {
      return Left(MediaStorageFailure(e.message));
    } catch (e) {
      return Left(ImportExportFailure('Failed to import backup: $e'));
    }
  }
}