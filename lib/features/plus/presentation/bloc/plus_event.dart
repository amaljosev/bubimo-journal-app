part of 'plus_bloc.dart';

sealed class PlusEvent extends Equatable {
  const PlusEvent();

  @override
  List<Object?> get props => [];
}

/// Fired once from main.dart: loads the cached entitlement (fast,
/// offline-safe) and then re-checks with Google Play in the background.
final class PlusStarted extends PlusEvent {
  const PlusStarted();
}

/// Silent re-check with Google Play (app resumed from background).
final class PlusRefreshRequested extends PlusEvent {
  const PlusRefreshRequested();
}

/// Loads plan prices for the paywall.
final class PlusProductsRequested extends PlusEvent {
  const PlusProductsRequested();
}

final class PlusPurchaseRequested extends PlusEvent {
  final PlusPlan plan;

  const PlusPurchaseRequested(this.plan);

  @override
  List<Object?> get props => [plan];
}

/// "Restore purchases" button.
final class PlusRestoreRequested extends PlusEvent {
  const PlusRestoreRequested();
}

/// Internal: a result arrived on the repository's purchase stream.
final class _PlusOutcomeReceived extends PlusEvent {
  final Either<Failure, PlusPurchaseOutcome> outcome;

  const _PlusOutcomeReceived(this.outcome);

  @override
  List<Object?> get props => [outcome];
}
