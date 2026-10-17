// lib/features/plus/domain/usecases/watch_plus_purchase_outcomes.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/plus_purchase_outcome.dart';
import '../repositories/plus_repository.dart';

class WatchPlusPurchaseOutcomes {
  final PlusRepository repository;

  const WatchPlusPurchaseOutcomes(this.repository);

  Stream<Either<Failure, PlusPurchaseOutcome>> call() {
    return repository.purchaseOutcomes;
  }
}
