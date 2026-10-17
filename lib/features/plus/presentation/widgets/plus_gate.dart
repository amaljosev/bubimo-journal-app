// lib/features/plus/presentation/widgets/plus_gate.dart

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../domain/entities/plus_feature.dart';
import '../bloc/plus_bloc.dart';
import '../routing/plus_route_paths.dart';

/// The single place every Plus-only action asks "may I proceed?".
///
/// ```dart
/// final allowed = await PlusGate.require(context, PlusFeature.pdfExport);
/// if (!allowed || !context.mounted) return;
/// // ...do the Plus-only thing
/// ```
///
/// Plus members pass instantly. Everyone else is shown the paywall,
/// opened with a line about [feature]; the result is `true` only if
/// they became a Plus member there.
class PlusGate {
  PlusGate._();

  /// Synchronous read of the shared [PlusBloc] — fine for one-off
  /// checks inside callbacks. In `build`, prefer
  /// `context.select<PlusBloc, bool>((b) => b.state.isPlus)` so the
  /// widget rebuilds when Plus changes.
  static bool get isPlus => getIt<PlusBloc>().state.isPlus;

  static Future<bool> require(BuildContext context, PlusFeature feature) async {
    if (isPlus) return true;

    final result = await context.push<bool>(
      PlusRoutePaths.paywall,
      extra: feature,
    );
    return result == true || isPlus;
  }
}
