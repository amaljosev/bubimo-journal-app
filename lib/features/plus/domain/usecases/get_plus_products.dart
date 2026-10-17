// lib/features/plus/domain/usecases/get_plus_products.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/plus_product.dart';
import '../repositories/plus_repository.dart';

class GetPlusProducts {
  final PlusRepository repository;

  const GetPlusProducts(this.repository);

  Future<Either<Failure, List<PlusProduct>>> call() {
    return repository.getProducts();
  }
}
