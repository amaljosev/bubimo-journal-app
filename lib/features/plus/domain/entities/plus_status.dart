// lib/features/plus/domain/entities/plus_status.dart

import 'package:equatable/equatable.dart';

/// How the user got Plus. The store doesn't tell us WHICH subscription
/// base plan (monthly/yearly) is active on the client, and the app
/// never needs to know — only "subscription" vs "lifetime" matters
/// (lifetime never expires; a subscription can lapse).
enum PlusTier { subscription, lifetime }

/// Whether the user currently has Bubimo Plus.
class PlusStatus extends Equatable {
  final bool isPlus;
  final PlusTier? tier;

  const PlusStatus.free() : isPlus = false, tier = null;

  const PlusStatus.active(PlusTier this.tier) : isPlus = true;

  @override
  List<Object?> get props => [isPlus, tier];
}
