// lib/features/plus/domain/entities/plus_plan.dart

/// The three ways a user can get Bubimo Plus.
///
/// [monthly] and [yearly] are base plans of ONE Play subscription;
/// [lifetime] is a separate one-time (non-consumable) product. See
/// `PlusProductIds` in the data layer for the store IDs behind each.
enum PlusPlan { monthly, quarterly, yearly, lifetime }
