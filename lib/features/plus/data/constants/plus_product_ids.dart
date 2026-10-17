// lib/features/plus/data/constants/plus_product_ids.dart

/// Store identifiers. These MUST match what you create in Play Console
/// character-for-character — product IDs can never be changed after
/// creation, so double-check before pressing Create there.
class PlusProductIds {
  PlusProductIds._();

  /// The subscription product (Monetize with Play > Subscriptions).
  static const String subscription = 'bubimo_plus';

  /// Base plan IDs inside [subscription].
  static const String monthlyBasePlan = 'plus-monthly';
  static const String yearlyBasePlan = 'plus-yearly';

  /// The one-time product (Monetize with Play > One-time products).
  static const String lifetime = 'bubimo_plus_lifetime';

  /// Every product ID the app asks the store about.
  static const Set<String> all = {subscription, lifetime};
}
