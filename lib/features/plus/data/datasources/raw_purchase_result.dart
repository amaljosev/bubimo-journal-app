// lib/features/plus/data/datasources/raw_purchase_result.dart

import '../../domain/entities/plus_status.dart';

/// What [PlusIapDataSource] reports about a purchase, before the
/// repository turns it into `Either<Failure, PlusPurchaseOutcome>`.
sealed class RawPurchaseResult {
  const RawPurchaseResult();
}

final class RawPurchasePending extends RawPurchaseResult {
  const RawPurchasePending();
}

final class RawPurchaseSucceeded extends RawPurchaseResult {
  final PlusTier tier;

  const RawPurchaseSucceeded(this.tier);
}

/// The user closed Google's purchase sheet without paying.
final class RawPurchaseCancelled extends RawPurchaseResult {
  const RawPurchaseCancelled();
}

final class RawPurchaseFailed extends RawPurchaseResult {
  final String message;

  const RawPurchaseFailed(this.message);
}

/// Answer to "what does this Google account own right now?".
///
/// [reachable] is false when Play couldn't be asked at all (no Play
/// Store, billing client error). That is NOT the same as "owns
/// nothing" — only a reachable query with a null [tier] means the
/// user genuinely has no active Plus.
final class EntitlementQuery {
  final bool reachable;
  final PlusTier? tier;

  const EntitlementQuery.unreachable() : reachable = false, tier = null;

  const EntitlementQuery.reached(this.tier) : reachable = true;
}
