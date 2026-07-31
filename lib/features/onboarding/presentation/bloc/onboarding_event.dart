// lib/features/onboarding/presentation/bloc/onboarding_event.dart

part of 'onboarding_bloc.dart';

sealed class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

/// Fired continuously by [PageView.onPageChanged]'s underlying
/// `PageController` listener as the user drags — carries a
/// fractional page value (e.g. 1.4 while swiping from page 1 to 2)
/// so the bloc can drive the gradient cross-fade smoothly rather
/// than snapping only once a page settles.
final class OnboardingPageScrolled extends OnboardingEvent {
  final double page;

  const OnboardingPageScrolled(this.page);

  @override
  List<Object?> get props => [page];
}

/// Fired when a page fully settles (`onPageChanged`'s integer
/// callback) — used for the dot indicator and the "Next"/"Get
/// started" label swap, which should snap rather than interpolate.
final class OnboardingPageSettled extends OnboardingEvent {
  final int index;

  const OnboardingPageSettled(this.index);

  @override
  List<Object?> get props => [index];
}

/// Fired only by the final page's "Get started" button. There is no
/// "skip past everything" control — "Skip" (shown only on the first
/// page) calls `PageController.animateToPage(1, ...)` directly rather
/// than dispatching any event here; that page transition then
/// triggers [OnboardingPageSettled] on its own once it settles, the
/// same as any other swipe. See `OnboardingPage`/`_goToSecondPage`.
final class OnboardingCompleted extends OnboardingEvent {
  const OnboardingCompleted();
}