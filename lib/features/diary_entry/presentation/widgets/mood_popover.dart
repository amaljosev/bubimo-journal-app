// lib/features/diary_entry/presentation/widgets/mood_popover.dart

import 'package:flutter/material.dart';

import '../../domain/entities/mood.dart';

/// Shows a speech-bubble style mood popover anchored below [anchorKey],
/// matching the reference screenshot: a soft rounded card with a small
/// triangular pointer connecting it to the mood avatar, containing a
/// grid of [Mood.values].
///
/// Mirrors [MoodPicker]'s selection semantics: tapping the
/// already-selected mood deselects it; tapping any other mood selects
/// it. Returns a [MoodPopoverResult] describing what happened, or null
/// if the popover was dismissed (barrier tap) without any choice —
/// callers should only act on a non-null result.
Future<MoodPopoverResult?> showMoodPopover(
  BuildContext context, {
  required GlobalKey anchorKey,
  required Mood? selectedMood,
}) async {
  final renderBox =
      anchorKey.currentContext?.findRenderObject() as RenderBox?;
  final overlay =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (renderBox == null || overlay == null) return null;

  final anchorTopLeft = renderBox.localToGlobal(
    Offset.zero,
    ancestor: overlay,
  );
  final anchorSize = renderBox.size;
  final anchorCenterX = anchorTopLeft.dx + anchorSize.width / 2;
  final anchorBottom = anchorTopLeft.dy + anchorSize.height;

  return showGeneralDialog<MoodPopoverResult>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Mood picker',
    barrierColor: Colors.black.withValues(alpha: 0.15),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return _MoodPopoverContent(
        anchorCenterX: anchorCenterX,
        anchorBottom: anchorBottom,
        overlaySize: overlay.size,
        selectedMood: selectedMood,
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeIn,
      );
      return FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
  );
}

/// Wraps the resolved mood so callers can distinguish "user tapped the
/// selected mood to clear it" (mood: null, but a real result) from
/// "user dismissed the popover without choosing anything" (the
/// [showMoodPopover] future itself resolves to null).
class MoodPopoverResult {
  final Mood? mood;
  const MoodPopoverResult(this.mood);
}

class _MoodPopoverContent extends StatelessWidget {
  final double anchorCenterX;
  final double anchorBottom;
  final Size overlaySize;
  final Mood? selectedMood;

  const _MoodPopoverContent({
    required this.anchorCenterX,
    required this.anchorBottom,
    required this.overlaySize,
    required this.selectedMood,
  });

  static const double _cardWidth = 320;
  static const double _pointerSize = 14;
  static const double _pointerRightInset = 28;
  static const double _edgeMargin = 12;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bubbleColor =
        isDark ? const Color(0xFF3A2E33) : const Color(0xFFFCE9EC);

    // On screens narrower than `_cardWidth + 2 * _edgeMargin` (small
    // phones, split-screen, etc.), the card itself has to shrink to
    // fit — otherwise the left/right clamp below has no valid range at
    // all (lower bound > upper bound), which is what was crashing this
    // popover with `ArgumentError (Invalid argument(s): 12.0)`.
    final cardWidth = (overlaySize.width - _edgeMargin * 2)
        .clamp(0.0, _cardWidth)
        .toDouble();

    // Clamp the card so it never runs off the left/right edges. The
    // upper bound is floored at `_edgeMargin` so it's never less than
    // the lower bound — `num.clamp` throws if `lower > upper`, which
    // is exactly what happened before `cardWidth` was capped to the
    // available width above.
    double left = anchorCenterX + _pointerRightInset - (cardWidth - 60);
    final maxLeft = overlaySize.width - cardWidth - _edgeMargin;
    left = left.clamp(_edgeMargin, maxLeft < _edgeMargin ? _edgeMargin : maxLeft);
    final pointerCenterOffsetFromLeft =
        (anchorCenterX - _pointerRightInset / 2) - left;

    final top = anchorBottom + 12;

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: cardWidth,
          child: Material(
            color: Colors.transparent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Pointer triangle
                Padding(
                  padding: EdgeInsets.only(
                    left: (pointerCenterOffsetFromLeft - _pointerSize / 2)
                        .clamp(
                          16.0,
                          (cardWidth - _pointerSize - 16.0) < 16.0
                              ? 16.0
                              : cardWidth - _pointerSize - 16.0,
                        ),
                  ),
                  child: CustomPaint(
                    size: const Size(_pointerSize, 8),
                    painter: _PointerPainter(color: bubbleColor),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _MoodGrid(selectedMood: selectedMood),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PointerPainter extends CustomPainter {
  final Color color;
  _PointerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PointerPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Colorful round background per mood, purely a presentational touch
/// layered behind each emoji to match the reference screenshot's
/// colored-circle mood avatars. Cycles through a fixed palette by
/// enum index so it stays stable without needing per-mood config.
const List<Color> _moodCircleColors = [
  Color(0xFFE0A45C),
  Color(0xFFE0B93D),
  Color(0xFFF2CB3E),
  Color(0xFFF0A3B8),
  Color(0xFFC9A2E0),
  Color(0xFFF0CB3E),
  Color(0xFFE0813D),
  Color(0xFF8FB8E8),
  Color(0xFF8590D9),
  Color(0xFF6FCBBE),
];

class _MoodGrid extends StatelessWidget {
  final Mood? selectedMood;

  const _MoodGrid({required this.selectedMood});

  @override
  Widget build(BuildContext context) {
    final moods = Mood.values;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: moods.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1,
      ),
      itemBuilder: (context, index) {
        final mood = moods[index];
        final isSelected = mood == selectedMood;
        final color = _moodCircleColors[index % _moodCircleColors.length];

        return GestureDetector(
          // Tapping the already-selected mood deselects it, matching
          // MoodPicker's toggle behavior.
          onTap: () => Navigator.of(context).pop(
            MoodPopoverResult(isSelected ? null : mood),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 2.5)
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            alignment: Alignment.center,
            child: Text(mood.emoji, style: const TextStyle(fontSize: 22)),
          ),
        );
      },
    );
  }
}