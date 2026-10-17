// lib/features/plus/data/repositories/plus_repository_impl.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/plus_plan.dart';
import '../../domain/entities/plus_product.dart';
import '../../domain/entities/plus_purchase_outcome.dart';
import '../../domain/entities/plus_status.dart';
import '../../domain/repositories/plus_repository.dart';
import '../datasources/plus_iap_data_source.dart';
import '../datasources/plus_local_data_source.dart';
import '../datasources/raw_purchase_result.dart';

class PlusRepositoryImpl implements PlusRepository {
  final PlusIapDataSource _iapDataSource;
  final PlusLocalDataSource _localDataSource;

  /// How long a cached SUBSCRIPTION entitlement is trusted while Google
  /// Play can't be reached. Lifetime never expires, so it's exempt.
  static const Duration _subscriptionOfflineGrace = Duration(days: 14);

  late final Stream<Either<Failure, PlusPurchaseOutcome>> _outcomes;

  PlusRepositoryImpl({
    required this._iapDataSource,
    required this._localDataSource,
  }) {
    // Start listening to Google's purchase stream right away — see
    // PlusIapDataSource's doc comment for why this can't wait.
    _iapDataSource.init();
    _outcomes = _iapDataSource.results.asyncMap(_mapRawResult);
  }

  @override
  Stream<Either<Failure, PlusPurchaseOutcome>> get purchaseOutcomes =>
      _outcomes;

  Future<Either<Failure, PlusPurchaseOutcome>> _mapRawResult(
    RawPurchaseResult raw,
  ) async {
    switch (raw) {
      case RawPurchasePending():
        return const Right(PlusPurchasePending());
      case RawPurchaseSucceeded(:final tier):
        try {
          await _localDataSource.save(
            active: true,
            tier: tier,
            verifiedAt: DateTime.now(),
          );
        } catch (_) {
          // The purchase itself succeeded; failing to cache it only
          // means the next launch re-checks with Google Play.
        }
        return Right(PlusPurchaseCompleted(PlusStatus.active(tier)));
      case RawPurchaseCancelled():
        return const Left(PurchaseCancelledFailure());
      case RawPurchaseFailed(:final message):
        return Left(PurchaseFailure(message));
    }
  }

  @override
  Future<Either<Failure, PlusStatus>> getCachedStatus() async {
    try {
      final cached = await _localDataSource.read();
      final tier = cached.tier;

      if (!cached.active || tier == null) {
        return const Right(PlusStatus.free());
      }
      if (tier == PlusTier.lifetime) {
        return const Right(PlusStatus.active(PlusTier.lifetime));
      }

      final verifiedAt = cached.lastVerifiedAt;
      final stillTrusted =
          verifiedAt != null &&
          DateTime.now().difference(verifiedAt) <= _subscriptionOfflineGrace;
      return Right(
        stillTrusted
            ? const PlusStatus.active(PlusTier.subscription)
            : const PlusStatus.free(),
      );
    } catch (e) {
      return Left(CacheFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, PlusStatus>> refreshStatus() async {
    try {
      final query = await _iapDataSource.queryEntitlement();
      if (!query.reachable) return const Left(StoreUnavailableFailure());

      final tier = query.tier;
      await _localDataSource.save(
        active: tier != null,
        tier: tier,
        verifiedAt: DateTime.now(),
      );
      return Right(
        tier == null ? const PlusStatus.free() : PlusStatus.active(tier),
      );
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<PlusProduct>>> getProducts() async {
    try {
      return Right(await _iapDataSource.loadProducts());
    } on PlusStoreException catch (e) {
      return Left(StoreUnavailableFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> startPurchase(PlusPlan plan) async {
    try {
      await _iapDataSource.startPurchase(plan);
      return const Right(null);
    } on PlusStoreException catch (e) {
      return Left(PurchaseFailure(e.message));
    } catch (e) {
      return Left(UnexpectedFailure(e.toString()));
    }
  }
}
