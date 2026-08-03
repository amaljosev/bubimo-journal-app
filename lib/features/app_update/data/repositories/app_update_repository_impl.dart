// lib/features/app_update/data/repositories/app_update_repository_impl.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/exceptions.dart';
import '../../../../core/error/failures.dart';
import '../../domain/entities/app_update_status.dart';
import '../../domain/repositories/app_update_repository.dart';
import '../datasources/app_update_local_data_source.dart';

class AppUpdateRepositoryImpl implements AppUpdateRepository {
  final AppUpdateLocalDataSource localDataSource;

  const AppUpdateRepositoryImpl(this.localDataSource);

  @override
  Future<Either<Failure, AppUpdateStatus>> checkForUpdate() async {
    try {
      final status = await localDataSource.checkForUpdate();
      return Right(status);
    } on AppUpdateException catch (e) {
      // Reached only on a genuinely broken check on a real
      // Android/Play device (see AppUpdateLocalDataSource's doc
      // comment) — the "not on Android" / "not a Play install" /
      // "no update published" cases all already resolve to
      // AppUpdateStatus.noUpdateAvailable inside the data source and
      // never throw, so they never reach this catch.
      return Left(AppUpdateFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, Unit>> startFlexibleUpdate() async {
    try {
      await localDataSource.startFlexibleUpdate();
      return const Right(unit);
    } on AppUpdateException catch (e) {
      return Left(AppUpdateFailure(e.message));
    }
  }
}