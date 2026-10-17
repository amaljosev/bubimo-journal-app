// lib/features/plus/domain/repositories/plus_repository.dart

import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../entities/plus_plan.dart';
import '../entities/plus_product.dart';
import '../entities/plus_purchase_outcome.dart';
import '../entities/plus_status.dart';

abstract class PlusRepository {
  /// Results of purchases the user starts (and any the store delivers
  /// late, e.g. a pending payment that finally clears). A cancelled
  /// purchase is `Left(PurchaseCancelledFailure)`.
  Stream<Either<Failure, PlusPurchaseOutcome>> get purchaseOutcomes;

  /// The locally remembered entitlement — instant and works offline.
  /// Used at startup so the first frame is already correct.
  Future<Either<Failure, PlusStatus>> getCachedStatus();

  /// Asks Google Play what the user owns right now and updates the
  /// local cache. `Left(StoreUnavailableFailure)` means Play couldn't
  /// be reached — callers should keep the cached status in that case,
  /// NOT treat it as "no Plus". Also backs "Restore purchases".
  Future<Either<Failure, PlusStatus>> refreshStatus();

  /// Current store prices (and trial eligibility) for the paywall.
  Future<Either<Failure, List<PlusProduct>>> getProducts();

  /// Opens Google Play's purchase sheet for [plan]. `Right` only means
  /// the sheet opened — the actual result arrives on [purchaseOutcomes].
  Future<Either<Failure, void>> startPurchase(PlusPlan plan);
}
