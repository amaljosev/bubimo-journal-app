// lib/features/plus/domain/entities/plus_product.dart

import 'package:equatable/equatable.dart';

import 'plus_plan.dart';

/// One purchasable Plus plan as the store currently prices it, already
/// reduced to what the paywall needs to show.
class PlusProduct extends Equatable {
  final PlusPlan plan;

  /// Store product ID (not the base plan ID).
  final String productId;

  /// Localized price for display, e.g. "₹399.00". For a subscription
  /// with a free trial this is the price AFTER the trial.
  final String formattedPrice;

  /// Price in micro-units (1,000,000 = one rupee), used to compute the
  /// "save X%" badge without parsing [formattedPrice].
  final int priceMicros;

  final String currencyCode;

  /// Set only when the user is eligible for a free trial on this plan.
  /// Holds the duration phrase, e.g. "7-day" (empty if the store sent
  /// a period shape we don't format). `null` = no trial.
  final String? freeTrialLabel;

  const PlusProduct({
    required this.plan,
    required this.productId,
    required this.formattedPrice,
    required this.priceMicros,
    required this.currencyCode,
    this.freeTrialLabel,
  });

  bool get hasFreeTrial => freeTrialLabel != null;

  @override
  List<Object?> get props => [
    plan,
    productId,
    formattedPrice,
    priceMicros,
    currencyCode,
    freeTrialLabel,
  ];
}
