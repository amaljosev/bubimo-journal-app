// lib/features/splash/presentation/pages/splash_page.dart

import 'dart:async';

import 'package:flutter/material.dart';

/// Static splash: app icon, "Bubimo" title, and a short tagline, with
/// a subtle continuous breathe/pulse loop on the icon (gentle
/// scale + opacity oscillation — never fully stops, never signals
/// "done" the way the old video's completion listener did).
///
/// Because the animation loops indefinitely rather than playing once
/// and finishing, there's no natural "the visual is done" signal to
/// race [checks] against anymore (contrast with the previous video
/// splash, which wired [VoidCallback onDone] to the video's own
/// `position >= duration` tick). In its place, [_minimumDisplay] is a
/// fixed floor — long enough for the pulse to read as an intentional
/// animation rather than a flash, short enough not to feel like an
/// artificial delay — and [onDone] fires once *both* that floor and
/// [checks] have elapsed/resolved, whichever finishes second. This
/// keeps the same "never navigate before startup work is actually
/// done" guarantee the video version had, just anchored to a timer
/// instead of a video's own runtime.
///
/// [checks] and [onDone] are unchanged in spirit from the video
/// version: [checks] is the async startup work (onboarding-status +
/// lock-config) the router needs resolved before it can decide where
/// to send the user, and [onDone] is a pure "now go somewhere else"
/// hook — this widget still only decides *when*, never *where*.
class SplashPage extends StatefulWidget {
  /// The async startup work to await before handing off — e.g.
  /// `Future.wait([checkOnboardingStatus(), loadLockConfig()])`
  /// wrapped by the caller into a single `Future<void>`.
  final Future<void> Function() checks;

  /// Fires exactly once, after both [_minimumDisplay] has elapsed and
  /// [checks] has resolved.
  final VoidCallback onDone;

  const SplashPage({super.key, required this.checks, required this.onDone});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  /// Floor on how long splash stays visible, independent of how fast
  /// [checks] resolves. Picked so the pulse gets roughly one full
  /// breathe cycle before the earliest possible navigation — tune
  /// freely; this is a design choice, not something derived from any
  /// hard requirement.
  static const _minimumDisplay = Duration(milliseconds: 1400);

  late final AnimationController _pulseController;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  bool _minimumDisplayElapsed = false;
  bool _checksSettled = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    final curved = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOut,
    );
    _scale = Tween<double>(begin: 0.94, end: 1.06).animate(curved);
    _opacity = Tween<double>(begin: 0.75, end: 1.0).animate(curved);

    // Runs in parallel with the timer below, same "start both
    // immediately, don't chain one after the other" reasoning as the
    // video version's `checks()` call — a slow onboarding/lock read
    // shouldn't delay when the minimum-display timer starts either.
    widget.checks().then((_) {
      _checksSettled = true;
      _maybeFinish();
    });

    Timer(_minimumDisplay, () {
      _minimumDisplayElapsed = true;
      _maybeFinish();
    });
  }

  void _maybeFinish() {
    if (_navigated || !_minimumDisplayElapsed || !_checksSettled) return;
    _navigated = true;
    // Note: `_pulseController` is intentionally left running via
    // `repeat(reverse: true)` right up until `dispose()` below — there
    // is no separate "stop the loop" step, since [onDone] navigates
    // away immediately and `dispose()` handles teardown.
    widget.onDone();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacity.value,
                  child: Transform.scale(scale: _scale.value, child: child),
                );
              },
              child: Image.asset(
                'assets/icons/bubimo_icon.png',
                width: 96,
                height: 96,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Bubimo',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your thoughts, your story, every day',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}