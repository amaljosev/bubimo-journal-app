// lib/features/onboarding/presentation/bloc/onboarding_bloc.dart

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/complete_onboarding.dart';

part 'onboarding_event.dart';
part 'onboarding_state.dart';

/// Holds onboarding's scroll/page position and persists completion.
///
/// [CompleteOnboarding] is the one durable side effect this bloc
/// performs — writing the onboarding-completed flag so the app
/// router's redirect logic won't send the user back here on the next
/// launch. `OnboardingPage.onCompleted` (the caller-supplied
/// callback) fires only after that write finishes, so it stays a
/// pure "now go somewhere else" navigation hook rather than also
/// needing to know how completion is persisted.
///
/// This bloc's event/state files are joined via `part`/`part of`
/// (see `onboarding_event.dart`/`onboarding_state.dart`), following
/// the standard flutter_bloc generator layout — unlike every other
/// bloc in this app (`ReminderSettingsBloc`, etc.), which keeps
/// event/state as separately-imported files. This is a deliberate,
/// scoped choice for the onboarding feature specifically, not a
/// codebase-wide convention change.
class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final CompleteOnboarding completeOnboarding;

  OnboardingBloc({required this.completeOnboarding})
    : super(const OnboardingState()) {
    on<OnboardingPageScrolled>(_onScrolled);
    on<OnboardingPageSettled>(_onSettled);
    on<OnboardingCompleted>(_onCompleted);
  }

  void _onScrolled(
    OnboardingPageScrolled event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(scrollPosition: event.page));
  }

  void _onSettled(
    OnboardingPageSettled event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(currentPage: event.index));
  }

  Future<void> _onCompleted(
    OnboardingCompleted event,
    Emitter<OnboardingState> emit,
  ) async {
    // Persist first, emit second — OnboardingPage's BlocListener
    // fires onCompleted() (navigation) off this state change, so the
    // completed flag is guaranteed durable before the caller
    // potentially disposes this bloc by navigating away.
    await completeOnboarding();
    emit(state.copyWith(isCompleted: true));
  }
}