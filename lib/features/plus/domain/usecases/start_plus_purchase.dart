// lib/features/plus/domain/usecases/start_plus_purchase.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/plus_plan.dart';
import '../repositories/plus_repository.dart';

class StartPlusPurchase {
  final PlusRepository repository;

  const StartPlusPurchase(this.repository);

  Future<Either<Failure, void>> call(PlusPlan plan) {
    return repository.startPurchase(plan);
  }
}
