// lib/core/ads/daily_ad_notice_page.dart

import 'dart:math' as math;

import 'package:bubimo/core/di/injection.dart';
import 'package:bubimo/features/ads/data/services/ads_preference_service.dart';
import 'package:bubimo/features/plus/domain/entities/plus_feature.dart';
import 'package:bubimo/features/plus/presentation/bloc/plus_bloc.dart';
import 'package:bubimo/features/plus/presentation/widgets/plus_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// One-time, full-screen notice shown in place of the very first ad.
///
/// The page is the diary's "entry saved" moment, so its one memorable
/// element is a date stamp — a scalloped seal carrying today's date,
/// which presses in once when the page opens. Everything else stays
/// quiet.
///
/// Below it, the user chooses how ads work for them as a two-row
/// choice list ("Keep ads" / "No ads") rather than a lone switch, so
/// each option can say what it means:
/// - Free users see "Keep ads" selected. Tapping "No ads" (marked
///   Plus) opens the Bubimo Plus paywall; if they become a member
///   there, ads switch off by themselves and this page updates.
/// - Plus members can pick either row freely.
///
/// There is NO auto-skip: the user leaves only via the "Go home"
/// button (or the system back gesture, which behaves the same way).
///
/// All colors and type come from the active [ThemeData], so it matches
/// whichever app theme and font are selected.
class DailyAdNoticePage extends StatelessWidget {
  const DailyAdNoticePage({super.key});

  /// Pushes the page and completes when the user leaves it.
  static Future<void> show(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => const DailyAdNoticePage(),
      ),
    );
  }

  static Future<void> _onChoice(
    BuildContext context, {
    required bool wantsAds,
    required bool isPlus,
  }) async {
    if (!isPlus) {
      // Free users can't turn ads off — show the paywall. Nothing
      // changes unless they become members there (the choice list then
      // updates on its own via AdsPreferenceService.applyPlusStatus).
      if (!wantsAds) {
        HapticFeedback.selectionClick();
        await PlusGate.require(context, PlusFeature.removeAds);
      }
      return;
    }
    HapticFeedback.selectionClick();
    await getIt<AdsPreferenceService>().setAdsEnabled(wantsAds);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isPlus = context.select<PlusBloc, bool>((b) => b.state.isPlus);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    // Rebuilds when ads are switched off/on, or a free
                    // user becomes a member from the paywall.
                    child: ValueListenableBuilder<bool>(
                      valueListenable:
                          getIt<AdsPreferenceService>().adsEnabled,
                      builder: (context, adsEnabled, _) {
                        // True once ads are actually off for a member —
                        // e.g. right after buying Plus from this screen.
                        final adsAreOff = isPlus && !adsEnabled;

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(child: _DateSeal(date: DateTime.now())),
                            const SizedBox(height: 28),
                            Text(
                              'Entry saved',
                              textAlign: TextAlign.center,
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              child: Text(
                                adsAreOff
                                    ? 'Ads are off. Thank you for '
                                          'supporting Bubimo.'
                                    : 'Today is ad-free. Your first ad '
                                          'comes tomorrow.',
                                key: ValueKey<bool>(adsAreOff),
                                textAlign: TextAlign.center,
                                style: textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 36),
                            Text(
                              'Ads in Bubimo',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _ChoiceList(
                              children: [
                                _ChoiceRow(
                                  title: 'Keep ads',
                                  subtitle:
                                      'One ad a day, shown after you save '
                                      'an entry. It keeps Bubimo free.',
                                  selected: adsEnabled,
                                  onTap: () => _onChoice(
                                    context,
                                    wantsAds: true,
                                    isPlus: isPlus,
                                  ),
                                ),
                                _ChoiceRow(
                                  title: 'No ads',
                                  subtitle: isPlus
                                      ? 'Turn ads off. You can switch back '
                                            'anytime in Settings.'
                                      : 'Remove ads completely with '
                                            'Bubimo Plus.',
                                  selected: !adsEnabled,
                                  locked: !isPlus,
                                  onTap: () => _onChoice(
                                    context,
                                    wantsAds: false,
                                    isPlus: isPlus,
                                  ),
                                ),
                              ],
                            ),
                            if (!isPlus) ...[
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => PlusGate.require(
                                    context,
                                    PlusFeature.removeAds,
                                  ),
                                  icon: const Icon(
                                    Icons.workspace_premium_rounded,
                                    size: 18,
                                  ),
                                  label: const Text(
                                    'See what Bubimo Plus includes',
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            // Pinned bottom button — the only way out (no auto-skip).
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: const Text(
                        'Go home',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Date seal — the page's one memorable element
// ─────────────────────────────────────────────────────────────────────

/// A scalloped, slightly tilted seal stamped with today's date, with a
/// small check badge. Presses in once when the page opens (the page's
/// single orchestrated motion); skipped when the system asks for
/// reduced motion.
class _DateSeal extends StatelessWidget {
  final DateTime date;

  const _DateSeal({required this.date});

  static const List<String> _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final seal = SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: const Size(132, 132),
            painter: _SealPainter(
              fill: colorScheme.primary,
              ring: colorScheme.onPrimary.withValues(alpha: 0.35),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${date.day}',
                style: textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _months[date.month - 1],
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onPrimary,
                ),
              ),
            ],
          ),
          Positioned(
            right: 6,
            bottom: 8,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: colorScheme.primary, width: 2),
              ),
              child: Icon(
                Icons.check_rounded,
                size: 18,
                color: colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      label: 'Entry saved on ${_months[date.month - 1]} ${date.day}',
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: reduceMotion ? 1 : 0, end: 1),
        duration: reduceMotion
            ? Duration.zero
            : const Duration(milliseconds: 650),
        curve: Curves.easeOutBack,
        builder: (context, t, child) {
          // Starts large and tilted, then presses down into place.
          final scale = 1.3 - 0.3 * t;
          final angle = -0.14 + 0.09 * t;
          return Opacity(
            opacity: t.clamp(0.0, 1.0).toDouble(),
            child: Transform.rotate(
              angle: angle,
              child: Transform.scale(scale: scale, child: child),
            ),
          );
        },
        child: seal,
      ),
    );
  }
}

/// Draws the scalloped seal: a circle whose edge ripples 18 times,
/// plus a thin inner ring.
class _SealPainter extends CustomPainter {
  final Color fill;
  final Color ring;

  const _SealPainter({required this.fill, required this.ring});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final baseRadius = size.width / 2 - 5;
    const scallops = 18;
    const amplitude = 3.5;

    final path = Path();
    for (var degrees = 0; degrees <= 360; degrees++) {
      final t = degrees * math.pi / 180;
      final r = baseRadius + amplitude * math.cos(scallops * t);
      final point = Offset(
        center.dx + r * math.cos(t),
        center.dy + r * math.sin(t),
      );
      if (degrees == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();

    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawCircle(
      center,
      baseRadius - 11,
      Paint()
        ..color = ring
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SealPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.ring != ring;
}

// ─────────────────────────────────────────────────────────────────────
// Ad choice list
// ─────────────────────────────────────────────────────────────────────

/// One outlined container holding the choice rows, separated by a
/// hairline — a single grouped control rather than separate cards.
class _ChoiceList extends StatelessWidget {
  final List<Widget> children;

  const _ChoiceList({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, color: colorScheme.outlineVariant),
            children[i],
          ],
        ],
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;

  /// Shows the "Plus" tag — tapping still calls [onTap], which opens
  /// the paywall for free users.
  final bool locked;
  final VoidCallback onTap;

  const _ChoiceRow({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
    this.locked = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: locked ? '$title, requires Bubimo Plus. $subtitle' : '$title. $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.08)
            : Colors.transparent,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: _RadioDot(selected: selected),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                title,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (locked) ...[
                              const SizedBox(width: 8),
                              _PlusTag(),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: textTheme.bodySmall?.copyWith(
                            height: 1.4,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RadioDot extends StatelessWidget {
  final bool selected;

  const _RadioDot({required this.selected});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? colorScheme.primary : colorScheme.outline,
          width: 2,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _PlusTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 12, color: colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            'Plus',
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  } 
}