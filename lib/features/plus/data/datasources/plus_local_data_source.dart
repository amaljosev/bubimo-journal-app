// lib/features/plus/data/datasources/plus_local_data_source.dart

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/plus_status.dart';

/// What was last confirmed about the user's Plus entitlement.
class CachedPlusEntitlement {
  final bool active;
  final PlusTier? tier;
  final DateTime? lastVerifiedAt;

  const CachedPlusEntitlement({
    required this.active,
    required this.tier,
    required this.lastVerifiedAt,
  });
}

/// Remembers the last verified entitlement so Plus works offline and
/// the first frame after launch is already correct.
///
/// Deliberately SharedPreferences, NOT the SQLite database: a diary
/// backup/restore must never be able to carry "Plus is active" from
/// one install to another. Same lightweight-flag storage the ads
/// preference and onboarding already use.
class PlusLocalDataSource {
  static const _activeKey = 'plus_active';
  static const _tierKey = 'plus_tier';
  static const _verifiedKey = 'plus_last_verified_ms';

  Future<CachedPlusEntitlement> read() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_activeKey) ?? false;
    final tierName = prefs.getString(_tierKey);
    final verifiedMs = prefs.getInt(_verifiedKey);

    PlusTier? tier;
    for (final t in PlusTier.values) {
      if (t.name == tierName) tier = t;
    }

    return CachedPlusEntitlement(
      active: active,
      tier: tier,
      lastVerifiedAt: verifiedMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(verifiedMs),
    );
  }

  Future<void> save({
    required bool active,
    required PlusTier? tier,
    required DateTime verifiedAt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_activeKey, active);
    if (tier == null) {
      await prefs.remove(_tierKey);
    } else {
      await prefs.setString(_tierKey, tier.name);
    }
    await prefs.setInt(_verifiedKey, verifiedAt.millisecondsSinceEpoch);
  }
}
