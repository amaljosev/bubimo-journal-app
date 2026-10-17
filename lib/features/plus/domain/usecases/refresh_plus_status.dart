// lib/features/plus/domain/usecases/refresh_plus_status.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/plus_status.dart';
import '../repositories/plus_repository.dart';

/// Re-checks what the user owns on Google Play. Used for the startup /
/// app-resume refresh AND for the "Restore purchases" button — they're
/// the same operation.
class RefreshPlusStatus {
  final PlusRepository repository;

  const RefreshPlusStatus(this.repository);

  Future<Either<Failure, PlusStatus>> call() {
    return repository.refreshStatus();
  }
}
