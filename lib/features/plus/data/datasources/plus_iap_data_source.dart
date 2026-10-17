// lib/features/plus/data/datasources/plus_iap_data_source.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../domain/entities/plus_plan.dart';
import '../../domain/entities/plus_product.dart';
import '../../domain/entities/plus_status.dart';
import '../constants/plus_product_ids.dart';
import 'raw_purchase_result.dart';

/// Thrown by [PlusIapDataSource] when the store itself is the problem
/// (Play unavailable, product missing, purchase sheet wouldn't open).
/// The repository maps it to a Failure.
class PlusStoreException implements Exception {
  final String message;

  const PlusStoreException(this.message);

  @override
  String toString() => message;
}

/// The only class in the app that talks to the `in_app_purchase`
/// plugin / Google Play Billing.
///
/// Lazy singleton in GetIt. [init] must run as early as possible
/// (the repository calls it from its constructor, which runs when
/// `main.dart` creates `PlusBloc`) because Google can deliver a
/// purchase that was interrupted last session the moment the stream
/// is listened to — nothing should be listening any later than app
/// start.
///
/// Android only: on any other platform every method degrades to
/// "store unavailable" instead of touching the plugin.
class PlusIapDataSource {
  PlusIapDataSource();

  late final InAppPurchase _iap = InAppPurchase.instance;

  final StreamController<RawPurchaseResult> _results =
      StreamController<RawPurchaseResult>.broadcast();
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _initialized = false;

  /// Store details behind each plan, filled by [loadProducts] and used
  /// by [startPurchase] (the plugin needs the exact ProductDetails —
  /// including the chosen offer — to start a purchase).
  final Map<PlusPlan, ProductDetails> _details = {};

  bool get _storeSupported => defaultTargetPlatform == TargetPlatform.android;

  Stream<RawPurchaseResult> get results => _results.stream;

  /// Starts listening to Google's purchase stream. Safe to call many
  /// times.
  void init() {
    if (_initialized) return;
    _initialized = true;
    if (!_storeSupported) return;

    _subscription = _iap.purchaseStream.listen(
      _onPurchases,
      onError: (Object error) {
        _results.add(RawPurchaseFailed(error.toString()));
      },
    );
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    await _results.close();
  }

  PlusTier _tierFor(String productId) {
    return productId == PlusProductIds.lifetime
        ? PlusTier.lifetime
        : PlusTier.subscription;
  }

  Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      try {
        await _handlePurchase(purchase);
      } catch (e) {
        debugPrint('PlusIapDataSource: error handling purchase: $e');
        _results.add(RawPurchaseFailed(e.toString()));
      }
    }
  }

  Future<void> _handlePurchase(PurchaseDetails purchase) async {
    if (!PlusProductIds.all.contains(purchase.productID)) {
      // Not ours — still has to be completed or Google keeps
      // redelivering it.
      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
      return;
    }

    switch (purchase.status) {
      case PurchaseStatus.pending:
        _results.add(const RawPurchasePending());
      case PurchaseStatus.purchased:
      case PurchaseStatus.restored:
        // Acknowledge, or Google refunds the purchase after ~3 days.
        // A failure here must not take Plus away from someone who
        // paid — the next refresh retries the acknowledgement.
        if (purchase.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchase);
          } catch (e) {
            debugPrint('PlusIapDataSource: acknowledge failed: $e');
          }
        }
        _results.add(RawPurchaseSucceeded(_tierFor(purchase.productID)));
      case PurchaseStatus.canceled:
        _results.add(const RawPurchaseCancelled());
      case PurchaseStatus.error:
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
        _results.add(
          RawPurchaseFailed(
            purchase.error?.message ?? 'The purchase could not be completed.',
          ),
        );
    }
  }

  // ---------------------------------------------------------------
  // Products
  // ---------------------------------------------------------------

  /// Fetches the three plans. For each subscription base plan, an
  /// offer with a free-trial first phase is preferred over the plain
  /// base plan — Google only returns offers the user is eligible for,
  /// so a returning subscriber automatically gets the plain price.
  Future<List<PlusProduct>> loadProducts() async {
    if (!_storeSupported) {
      throw const PlusStoreException(
        'Purchases are only available on Android.',
      );
    }
    if (!await _iap.isAvailable()) {
      throw const PlusStoreException(
        'Google Play is not available right now. Please try again later.',
      );
    }

    final response = await _iap.queryProductDetails(PlusProductIds.all);
    if (response.error != null) {
      throw PlusStoreException(response.error!.message);
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint(
        'PlusIapDataSource: products not found in Play: '
        '${response.notFoundIDs}',
      );
    }

    GooglePlayProductDetails? lifetime;
    final chosen = <PlusPlan, _ChosenOffer>{};

    for (final details in response.productDetails) {
      if (details is! GooglePlayProductDetails) continue;

      if (details.id == PlusProductIds.lifetime) {
        lifetime = details;
        continue;
      }
      if (details.id != PlusProductIds.subscription) continue;

      final offers = details.productDetails.subscriptionOfferDetails;
      final index = details.subscriptionIndex;
      if (offers == null || index == null || index >= offers.length) {
        continue;
      }
      final offer = offers[index];

      final plan = switch (offer.basePlanId) {
        PlusProductIds.monthlyBasePlan => PlusPlan.monthly,
        PlusProductIds.yearlyBasePlan => PlusPlan.yearly,
        _ => null,
      };
      if (plan == null) continue;

      final hasTrial = _hasFreeTrial(offer);
      final current = chosen[plan];
      if (current == null || (hasTrial && !current.hasTrial)) {
        chosen[plan] = _ChosenOffer(details, offer, hasTrial);
      }
    }

    _details.clear();
    final products = <PlusProduct>[];

    for (final plan in const [PlusPlan.yearly, PlusPlan.monthly]) {
      final pick = chosen[plan];
      if (pick == null) continue;

      final phases = pick.offer.pricingPhases;
      if (phases.isEmpty) continue;
      // Last phase is the ongoing price; a trial, if any, is first.
      final recurring = phases.last;

      _details[plan] = pick.details;
      products.add(
        PlusProduct(
          plan: plan,
          productId: PlusProductIds.subscription,
          formattedPrice: recurring.formattedPrice,
          priceMicros: recurring.priceAmountMicros,
          currencyCode: recurring.priceCurrencyCode,
          freeTrialLabel:
              pick.hasTrial ? _trialLabel(phases.first.billingPeriod) : null,
        ),
      );
    }

    if (lifetime != null) {
      _details[PlusPlan.lifetime] = lifetime;
      products.add(
        PlusProduct(
          plan: PlusPlan.lifetime,
          productId: PlusProductIds.lifetime,
          formattedPrice: lifetime.price,
          priceMicros: (lifetime.rawPrice * 1000000).round(),
          currencyCode: lifetime.currencyCode,
        ),
      );
    }

    if (products.isEmpty) {
      throw const PlusStoreException(
        'Bubimo Plus is not available to buy right now. Please try again '
        'later.',
      );
    }

    return products;
  }

  bool _hasFreeTrial(SubscriptionOfferDetailsWrapper offer) {
    final phases = offer.pricingPhases;
    return phases.length > 1 && phases.first.priceAmountMicros == 0;
  }

  /// "P7D" -> "7-day", "P1W" -> "7-day", "P1M" -> "1-month".
  /// Returns an empty string for a shape we don't format, so the UI
  /// can fall back to plain "free trial".
  String _trialLabel(String isoPeriod) {
    final match = RegExp(
      r'^P(?:(\d+)Y)?(?:(\d+)M)?(?:(\d+)W)?(?:(\d+)D)?$',
    ).firstMatch(isoPeriod);
    if (match == null) return '';

    int part(int group) => int.tryParse(match.group(group) ?? '') ?? 0;
    final years = part(1);
    final months = part(2);
    final days = part(4) + part(3) * 7;

    if (years > 0 && months == 0 && days == 0) return '$years-year';
    if (months > 0 && years == 0 && days == 0) return '$months-month';
    if (days > 0 && years == 0 && months == 0) return '$days-day';
    return '';
  }

  // ---------------------------------------------------------------
  // Buying
  // ---------------------------------------------------------------

  /// Opens Google's purchase sheet. Completing normally only means the
  /// sheet opened; the real result arrives on [results].
  Future<void> startPurchase(PlusPlan plan) async {
    var details = _details[plan];
    if (details == null) {
      await loadProducts();
      details = _details[plan];
    }
    if (details == null) {
      throw const PlusStoreException(
        'This plan is not available right now.',
      );
    }

    // Subscriptions are bought with buyNonConsumable too; the plugin
    // reads the chosen offer from the ProductDetails.
    final started = await _iap.buyNonConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
    if (!started) {
      throw const PlusStoreException(
        'Could not open the purchase screen. Please try again.',
      );
    }
  }

  // ---------------------------------------------------------------
  // Entitlement
  // ---------------------------------------------------------------

  /// Asks Google what this account owns right now. Lifetime wins over
  /// a subscription. Also acknowledges any owned purchase that was
  /// never acknowledged (e.g. the app was killed mid-purchase).
  Future<EntitlementQuery> queryEntitlement() async {
    if (!_storeSupported) return const EntitlementQuery.unreachable();
    if (!await _iap.isAvailable()) return const EntitlementQuery.unreachable();

    final addition = _iap
        .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
    final response = await addition.queryPastPurchases();
    if (response.error != null) return const EntitlementQuery.unreachable();

    PlusTier? tier;
    for (final purchase in response.pastPurchases) {
      if (!PlusProductIds.all.contains(purchase.productID)) continue;
      // A still-pending payment is not an entitlement.
      if (purchase.status == PurchaseStatus.pending) continue;

      if (purchase.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(purchase);
        } catch (e) {
          debugPrint('PlusIapDataSource: acknowledge failed: $e');
        }
      }

      final found = _tierFor(purchase.productID);
      if (found == PlusTier.lifetime || tier == null) tier = found;
    }

    return EntitlementQuery.reached(tier);
  }
}

class _ChosenOffer {
  final GooglePlayProductDetails details;
  final SubscriptionOfferDetailsWrapper offer;
  final bool hasTrial;

  const _ChosenOffer(this.details, this.offer, this.hasTrial);
}
