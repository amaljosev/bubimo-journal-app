// lib/features/onboarding/presentation/bloc/onboarding_state.dart

part of 'onboarding_bloc.dart';


class OnboardingState extends Equatable {
  /// Fractional scroll position across all pages (e.g. 1.35), used to
  /// interpolate the background gradient smoothly as the user drags.
  final double scrollPosition;

  /// The last page index to fully settle — drives the dot indicator
  /// and the bottom button label/behavior.
  final int currentPage;

  /// True once [OnboardingCompleted] has fired. The page listens for
  /// this to navigate away; the bloc itself never navigates.
  final bool isCompleted;

  const OnboardingState({
    this.scrollPosition = 0,
    this.currentPage = 0,
    this.isCompleted = false,
  });

  OnboardingState copyWith({
    double? scrollPosition,
    int? currentPage,
    bool? isCompleted,
  }) {
    return OnboardingState(
      scrollPosition: scrollPosition ?? this.scrollPosition,
      currentPage: currentPage ?? this.currentPage,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  @override
  List<Object?> get props => [scrollPosition, currentPage, isCompleted];
}