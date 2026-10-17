// lib/features/plus/domain/entities/plus_purchase_outcome.dart

import 'plus_status.dart';

/// What happened to a purchase the user started. Cancellations and
/// errors are NOT here — they travel as `Left(Failure)` on the same
/// stream (see `PlusRepository.purchaseOutcomes`).
sealed class PlusPurchaseOutcome {
  const PlusPurchaseOutcome();
}

/// Google is still processing the payment (e.g. a slow payment method).
/// Plus is NOT active yet; a later [PlusPurchaseCompleted] follows.
final class PlusPurchasePending extends PlusPurchaseOutcome {
  const PlusPurchasePending();
}

/// The purchase went through and [status] is the new entitlement.
final class PlusPurchaseCompleted extends PlusPurchaseOutcome {
  final PlusStatus status;

  const PlusPurchaseCompleted(this.status);
}
