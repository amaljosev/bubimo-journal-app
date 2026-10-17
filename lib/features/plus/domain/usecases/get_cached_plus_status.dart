// lib/features/plus/domain/usecases/get_cached_plus_status.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/plus_status.dart';
import '../repositories/plus_repository.dart';

class GetCachedPlusStatus {
  final PlusRepository repository;

  const GetCachedPlusStatus(this.repository);

  Future<Either<Failure, PlusStatus>> call() {
    return repository.getCachedStatus();
  }
}
