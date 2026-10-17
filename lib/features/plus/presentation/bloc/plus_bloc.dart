// lib/features/plus/presentation/bloc/plus_bloc.dart

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../domain/entities/plus_plan.dart';
import '../../domain/entities/plus_product.dart';
import '../../domain/entities/plus_purchase_outcome.dart';
import '../../domain/entities/plus_status.dart';
import '../../domain/usecases/get_cached_plus_status.dart';
import '../../domain/usecases/get_plus_products.dart';
import '../../domain/usecases/refresh_plus_status.dart';
import '../../domain/usecases/start_plus_purchase.dart';
import '../../domain/usecases/watch_plus_purchase_outcomes.dart';

part 'plus_event.dart';
part 'plus_state.dart';

/// App-wide source of truth for "does this user have Bubimo Plus?".
///
/// Registered as a lazy singleton (NOT a factory) and provided at the
/// app root — mirrors `LockBloc`/`AppThemeCubit`: every screen's gate
/// reads the one shared instance, and `main.dart` loads it before the
/// first frame so gated UI is correct from the start.
///
/// Subscribes to the repository's purchase stream in its constructor
/// so purchases Google delivers late (a pending payment clearing, an
/// interrupted purchase from last session) are never missed.
class PlusBloc extends Bloc<PlusEvent, PlusState> {
  final GetCachedPlusStatus getCachedPlusStatus;
  final RefreshPlusStatus refreshPlusStatus;
  final GetPlusProducts getPlusProducts;
  final StartPlusPurchase startPlusPurchase;
  final WatchPlusPurchaseOutcomes watchPlusPurchaseOutcomes;

  StreamSubscription<Either<Failure, PlusPurchaseOutcome>>? _outcomeSub;
  int _feedbackCounter = 0;

  PlusBloc({
    required this.getCachedPlusStatus,
    required this.refreshPlusStatus,
    required this.getPlusProducts,
    required this.startPlusPurchase,
    required this.watchPlusPurchaseOutcomes,
  }) : super(const PlusState()) {
    on<PlusStarted>(_onStarted);
    on<PlusRefreshRequested>(_onRefreshRequested);
    on<PlusProductsRequested>(_onProductsRequested);
    on<PlusPurchaseRequested>(_onPurchaseRequested);
    on<PlusRestoreRequested>(_onRestoreRequested);
    on<_PlusOutcomeReceived>(_onOutcomeReceived);

    _outcomeSub = watchPlusPurchaseOutcomes().listen(
      (outcome) => add(_PlusOutcomeReceived(outcome)),
    );
  }

  PlusFeedback _feedback(PlusFeedbackType type, String message) {
    _feedbackCounter++;
    return PlusFeedback(id: _feedbackCounter, type: type, message: message);
  }

  Future<void> _onStarted(
    PlusStarted event,
    Emitter<PlusState> emit,
  ) async {
    // 1. Cached entitlement first — instant, works offline. Emitting
    //    `loaded` here is what lets main.dart continue to runApp.
    final cached = await getCachedPlusStatus();
    cached.fold(
      (_) => emit(state.copyWith(loadStatus: PlusLoadStatus.loaded)),
      (status) => emit(
        state.copyWith(loadStatus: PlusLoadStatus.loaded, plus: status),
      ),
    );

    // 2. Then confirm with Google Play. A failure (offline, Play
    //    unavailable) deliberately keeps whatever the cache said.
    final refreshed = await refreshPlusStatus();
    refreshed.fold((_) {}, (status) {
      if (status != state.plus) emit(state.copyWith(plus: status));
    });
  }

  Future<void> _onRefreshRequested(
    PlusRefreshRequested event,
    Emitter<PlusState> emit,
  ) async {
    final refreshed = await refreshPlusStatus();
    refreshed.fold((_) {}, (status) {
      if (status != state.plus) emit(state.copyWith(plus: status));
    });
  }

  Future<void> _onProductsRequested(
    PlusProductsRequested event,
    Emitter<PlusState> emit,
  ) async {
    if (state.productsStatus == PlusProductsStatus.loading) return;
    emit(
      state.copyWith(
        productsStatus: PlusProductsStatus.loading,
        clearProductsError: true,
      ),
    );

    final result = await getPlusProducts();
    result.fold(
      (failure) => emit(
        state.copyWith(
          productsStatus: PlusProductsStatus.failure,
          productsError: failure.message,
        ),
      ),
      (products) => emit(
        state.copyWith(
          productsStatus: PlusProductsStatus.loaded,
          products: products,
        ),
      ),
    );
  }

  Future<void> _onPurchaseRequested(
    PlusPurchaseRequested event,
    Emitter<PlusState> emit,
  ) async {
    if (state.isBusy) return;
    emit(
      state.copyWith(
        purchaseStatus: PlusPurchaseStatus.purchasing,
        clearFeedback: true,
      ),
    );

    final result = await startPlusPurchase(event.plan);
    result.fold(
      (failure) => emit(
        state.copyWith(
          purchaseStatus: PlusPurchaseStatus.idle,
          feedback: _feedback(PlusFeedbackType.error, failure.message),
        ),
      ),
      // Sheet opened. The outcome (paid / cancelled / failed) arrives
      // on the purchase stream -> _onOutcomeReceived, which resets
      // purchaseStatus. Nothing to emit here.
      (_) {},
    );
  }

  Future<void> _onRestoreRequested(
    PlusRestoreRequested event,
    Emitter<PlusState> emit,
  ) async {
    if (state.isBusy) return;
    emit(
      state.copyWith(
        purchaseStatus: PlusPurchaseStatus.restoring,
        clearFeedback: true,
      ),
    );

    final result = await refreshPlusStatus();
    result.fold(
      (failure) => emit(
        state.copyWith(
          purchaseStatus: PlusPurchaseStatus.idle,
          feedback: _feedback(PlusFeedbackType.error, failure.message),
        ),
      ),
      (status) => emit(
        state.copyWith(
          plus: status,
          purchaseStatus: PlusPurchaseStatus.idle,
          feedback: status.isPlus
              ? _feedback(PlusFeedbackType.success, 'Bubimo Plus restored.')
              : _feedback(
                  PlusFeedbackType.info,
                  'No Bubimo Plus purchase found for this Google account.',
                ),
        ),
      ),
    );
  }

  void _onOutcomeReceived(
    _PlusOutcomeReceived event,
    Emitter<PlusState> emit,
  ) {
    event.outcome.fold(
      (failure) {
        if (failure is PurchaseCancelledFailure) {
          // User closed the sheet — back to idle, no error to show.
          emit(state.copyWith(purchaseStatus: PlusPurchaseStatus.idle));
          return;
        }
        emit(
          state.copyWith(
            purchaseStatus: PlusPurchaseStatus.idle,
            feedback: _feedback(PlusFeedbackType.error, failure.message),
          ),
        );
      },
      (outcome) {
        switch (outcome) {
          case PlusPurchasePending():
            emit(
              state.copyWith(
                purchaseStatus: PlusPurchaseStatus.pending,
                feedback: _feedback(
                  PlusFeedbackType.info,
                  'Your payment is pending. Plus unlocks as soon as it '
                  'completes.',
                ),
              ),
            );
          case PlusPurchaseCompleted(:final status):
            emit(
              state.copyWith(
                plus: status,
                purchaseStatus: PlusPurchaseStatus.idle,
                feedback: _feedback(
                  PlusFeedbackType.success,
                  'Welcome to Bubimo Plus!',
                ),
              ),
            );
        }
      },
    );
  }

  @override
  Future<void> close() async {
    await _outcomeSub?.cancel();
    return super.close();
  }
}
