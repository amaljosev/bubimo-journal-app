// lib/features/onboarding/presentation/pages/onboarding_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/theme/app_colors.dart';
import '../../widgets/onboarding_dots.dart';
import '../../widgets/onboarding_page_view_item.dart';
import '../../widgets/onboarding_pages_data.dart';
import '../bloc/onboarding_bloc.dart';


/// The 3-page onboarding flow. Provides its own [OnboardingBloc] since
/// this screen owns that state exclusively and nothing else in the
/// app needs it to survive past this screen — contrast with
/// `ReminderSettingsBloc`, which `MainShell` provides above the tab so
/// it survives tab switches.
///
/// [onCompleted] is called once, only from the final page's "Get
/// started" button, and is the caller's responsibility — e.g.
/// persisting a first-run flag and popping/replacing the route via
/// `GoRouter`. This widget only decides *when* onboarding is done,
/// never *what happens next*.
///
/// There is deliberately no way to skip past the whole flow — "Skip"
/// (shown only on the first page) advances straight to the second
/// page rather than completing onboarding; see `_goToSecondPage`.
class OnboardingPage extends StatelessWidget {
  final VoidCallback onCompleted;

  const OnboardingPage({super.key, required this.onCompleted});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => getIt<OnboardingBloc>(),
      child: BlocListener<OnboardingBloc, OnboardingState>(
        listenWhen: (previous, current) => current.isCompleted && !previous.isCompleted,
        listener: (context, state) => onCompleted(),
        child: const _OnboardingView(),
      ),
    );
  }
}

class _OnboardingView extends StatefulWidget {
  const _OnboardingView();

  @override
  State<_OnboardingView> createState() => _OnboardingViewState();
}

class _OnboardingViewState extends State<_OnboardingView> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    // `onPageChanged` alone only fires once a page settles — it can't
    // drive a smooth cross-fade while mid-drag. Listening to the
    // controller directly gives the fractional page value every
    // frame during a drag, which OnboardingPageScrolled forwards to
    // the bloc for the gradient interpolation in build() below.
    _pageController.addListener(_onScrollChanged);
  }

  void _onScrollChanged() {
    if (!_pageController.hasClients) return;
    final page = _pageController.page;
    if (page != null) {
      context.read<OnboardingBloc>().add(OnboardingPageScrolled(page));
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onScrollChanged);
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextOrComplete(int currentPage) {
    if (currentPage == kOnboardingPages.length - 1) {
      context.read<OnboardingBloc>().add(const OnboardingCompleted());
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  /// "Skip" always lands on the second page (index 1) — it's a
  /// shortcut past the first page specifically, not a general escape
  /// from onboarding. Only shown while `currentPage == 0` (see
  /// build() below), so this is never reachable from page 2 or 3.
  void _goToSecondPage() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedTextColor =
        (isDark ? AppColors.textDark : AppColors.textLight)[4].toColor();

    return Scaffold(
      body: BlocBuilder<OnboardingBloc, OnboardingState>(
        builder: (context, state) {
          final canSkip = state.currentPage == 0||state.currentPage == 1;
          final isLastPage = state.currentPage == kOnboardingPages.length - 1;

          return Stack(
            children: [
              _OnboardingBackground(scrollPosition: state.scrollPosition, isDark: isDark),
              SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        // "Skip" only makes sense on the first page —
                        // it jumps to the second (see
                        // `_goToSecondPage`), which is a no-op or a
                        // step backward from page 2 or 3, so it
                        // disappears there instead of staying present
                        // but confusing.
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: canSkip ? 1.0 : 0.0,
                          child: IgnorePointer(
                            ignoring: !canSkip,
                            child: TextButton(
                              onPressed: _goToSecondPage,
                              child: Text('Skip', style: TextStyle(color: mutedTextColor)),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        onPageChanged: (index) => context.read<OnboardingBloc>().add(
                          OnboardingPageSettled(index),
                        ),
                        children: [
                          for (final page in kOnboardingPages) OnboardingPageViewItem(data: page),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      child: _OnboardingControls(
                        currentPage: state.currentPage,
                        isLastPage: isLastPage,
                        onNext: () => _goToNextOrComplete(state.currentPage),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Background gradient that smoothly cross-fades between each page's
/// accent tint as [scrollPosition] moves — tied directly to drag
/// position (not just the settled page) so the color shift feels
/// continuous under the user's thumb, not like a slide transition
/// with a color cut hidden inside it. This is the flow's one
/// deliberate signature animation; everything else (dots, hero
/// breathing, button fade) stays quieter by comparison.
class _OnboardingBackground extends StatelessWidget {
  final double scrollPosition;
  final bool isDark;

  const _OnboardingBackground({required this.scrollPosition, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final pageCount = kOnboardingPages.length;
    final clamped = scrollPosition.clamp(0.0, (pageCount - 1).toDouble());
    final lowerIndex = clamped.floor();
    final upperIndex = (lowerIndex + 1).clamp(0, pageCount - 1);
    final t = clamped - lowerIndex;

    final background =
        (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)[0].toColor();

    final lowerAccent = kOnboardingPages[lowerIndex].accentIndex;
    final upperAccent = kOnboardingPages[upperIndex].accentIndex;

    final lowerTint = AppColors.onboardingGradientForPrimary(lowerAccent, isDark: isDark).toColor();
    final upperTint = AppColors.onboardingGradientForPrimary(upperAccent, isDark: isDark).toColor();
    final tint = Color.lerp(lowerTint, upperTint, t)!;

    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tint, background],
          ),
        ),
      ),
    );
  }
}

/// Bottom row: dot indicator + the "Next" / "Get started" button,
/// whose label and action swap on the last page rather than needing
/// a separate button hierarchy per page.
class _OnboardingControls extends StatelessWidget {
  final int currentPage;
  final bool isLastPage;
  final VoidCallback onNext;

  const _OnboardingControls({
    required this.currentPage,
    required this.isLastPage,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentIndex = kOnboardingPages[currentPage].accentIndex;
    final accent =
        (isDark ? AppColors.primaryDark : AppColors.primaryLight)[accentIndex].toColor();
    // The button fill is always the saturated `accent` swatch (light
    // or dark variant), never a near-white/near-black surface color —
    // so its label needs a color chosen for contrast against *that*,
    // not against the page background. Both primaryLight and
    // primaryDark entries are mid-to-deep saturation (see AppColors'
    // "Primary" doc comment), so a consistent near-white label reads
    // clearly on either.
    final onAccent = AppColors.surfaceLight[0].toColor();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        OnboardingDots(
          count: kOnboardingPages.length,
          currentIndex: currentPage,
          accentIndex: accentIndex,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: FilledButton(
            key: ValueKey(isLastPage),
            onPressed: onNext,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: onAccent,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            child: Text(isLastPage ? 'Get started' : 'Next'),
          ),
        ),
      ],
    );
  }
}