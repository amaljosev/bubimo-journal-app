// lib/features/diary_entry/presentation/widgets/diary_list_item.dart

import 'package:bubimo/core/navigation/debounced_tap.dart';
import 'package:bubimo/core/utils/date_utils.dart';
import 'package:bubimo/features/diary_entry/domain/entities/diary_entry.dart';
import 'package:flutter/material.dart';

/// List tile for a single diary entry on the Home Screen.
///
/// Lives under diary_entry/presentation/widgets/ (intentional deviation
/// from the original plan's home/presentation/widgets/ location). If
/// `home` still has its own copy of this widget, delete it there and
/// import this file instead to avoid two diverging implementations.
///
/// Layout: a plain (no background) date column on the left — day number
/// large, weekday abbreviation small and muted below it — and a single
/// rounded card on the right showing mood emoji + label + score on the
/// first line, then a 2-line preview. Uses `date` (the date the entry is
/// about) rather than `updatedAt` (a DB modification timestamp).
///
/// NOTE on assumed fields (confirm/adjust if your model differs):
///   - `entry.mood!.emoji`  -> String
///   - `entry.mood!.label`  -> String, e.g. "Happy"
///   - `entry.moodScore`    -> double? (0.0–10.0), shown as "x.x/10"
/// `title`/`content`/`preview`/`moodScore` are treated as nullable.
///
/// Card color: reads `colorScheme.surfaceContainerHighest`, which
/// `theme_mapper.dart` explicitly maps from `AppThemeData.surfaceColor`
/// — this is the same field the Create/Edit Custom Theme form's
/// "Surface" tile edits and the live preview (`HomePreviewCard`)
/// renders directly. Previously this read `colorScheme.primaryContainer`,
/// which Flutter auto-derives from `primary` when not explicitly set,
/// producing a tile color completely disconnected from the user's
/// Surface pick (see theme_mapper.dart's ColorScheme construction —
/// primaryContainer is never set there). Do not revert to
/// primaryContainer without also explicitly setting it in
/// theme_mapper.dart.
///
/// Tap handling uses [DebouncedTap] (not a plain `InkWell`) so a fast
/// double-tap on the same tile can't push [onTap]'s destination route
/// twice — see [DebouncedTap]'s doc comment for why this was needed
/// app-wide, not just here.
///
/// RESPONSIVE NOTES:
/// This widget is rendered inside [HomePage]'s day-grouped list, which
/// (as of the responsive pass on that file) now hands this widget's
/// parent `Row` a width computed from the *actual* space available to
/// that row on the current device/window — not an assumed full-screen
/// width. Two consequences for this file specifically:
///
/// 1. The date column (`showDateColumn: true` case) has a fixed pixel
///    width here, but that width interacts with system text-scale: at
///    large accessibility text sizes, "31" (day-of-month) or a 3-letter
///    weekday abbreviation can grow wider than the column while a
///    plain `Text` has no fallback other than to clip/wrap unexpectedly.
///    [MediaQuery.textScalerOf] is used (a screen-global fact — no
///    per-widget LayoutBuilder constraint can tell this widget "the
///    user turned on large text", only MediaQuery can) to widen that
///    column proportionally so the numerals/weekday keep fitting rather
///    than overflowing past their `SizedBox`.
/// 2. The mood-label `Row` (emoji + uppercase label + spacer + favorite
///    icon) previously had no wrap/shrink fallback: a long mood label
///    on a narrow card had nothing stopping a horizontal overflow. It's
///    now wrapped in `Flexible` with an ellipsis fallback, so on a
///    narrow card (small phone, or split-screen) a long label degrades
///    to a truncated label instead of an overflow error — this mirrors
///    how the preview text below it already truncates via
///    maxLines/overflow, so the whole card now degrades consistently
///    under space pressure instead of just the preview line doing so.
class DiaryListItem extends StatelessWidget {
  final DiaryEntry entry;
  final VoidCallback onTap;

  /// Whether to render the built-in day-number/weekday column on the
  /// left. Defaults to true for standalone use. Pass `false` when a
  /// parent list (e.g. [HomePage]'s date-grouped list) already shows
  /// its own date tile once per day, to avoid the date rendering
  /// twice for the same entry.
  final bool showDateColumn;

  const DiaryListItem({
    super.key,
    required this.entry,
    required this.onTap,
    this.showDateColumn = true,
  });

  /// Object Replacement Character (U+FFFC) — the standard placeholder
  /// rich-text editors (e.g. Quill/`flutter_quill`, and most delta- or
  /// document-model-based editors generally) substitute into their
  /// plain-text extraction wherever a non-text embed (most commonly an
  /// inline image) sits in the document. `entry.preview`/`entry.content`
  /// are plain strings by the time they reach this widget, so if the
  /// entry's rich body contained an inline image, this is what shows up
  /// in that string at the image's position — Flutter's default `Text`
  /// then renders it as a visible ".not def"/tofu box (the dashed "OBJ"
  /// glyph), since no font has a real glyph for it and a bare `Text`
  /// widget has no way to know it should be substituted with something
  /// else instead.
  ///
  /// [_sanitizePreview] strips every occurrence of this character out of
  /// the raw preview text and reports how many were found, so the
  /// visible text never shows the raw placeholder — see [build] for how
  /// the count becomes a trailing "🖼️ N photos" indicator instead.
  static const String _objectReplacementChar = '\uFFFC';

  static final RegExp _whitespaceRun = RegExp(r'\s+');

  /// Base date-column width at 1.0x text scale. Actual rendered width
  /// scales up from this with [MediaQuery.textScalerOf] (see [build]),
  /// clamped to a sane ceiling so an extreme system text size widens
  /// the column enough to fit its content without letting it balloon
  /// far enough to meaningfully steal space back from the card next to
  /// it.
  static const double _dateColumnBaseWidth = 56.0;
  static const double _dateColumnMaxWidth = 80.0;

  /// Removes every [_objectReplacementChar] from [raw], collapses any
  /// whitespace left behind where an embed used to sit (so removing an
  /// embed from the middle of a sentence doesn't leave a visible double
  /// space), and reports how many embeds were found.
  ///
  /// This is a display-layer fix only: it cleans up whatever string
  /// [entry.preview]/[entry.content] already contains by the time it
  /// reaches this widget. It does not change how those fields are
  /// computed upstream — if the raw string itself should never have
  /// contained U+FFFC in the first place, that's a separate change in
  /// wherever that string gets built (not in this widget).
  static ({String text, int imageCount}) _sanitizePreview(String raw) {
    final imageCount = _objectReplacementChar.allMatches(raw).length;
    if (imageCount == 0) return (text: raw, imageCount: 0);

    final withoutEmbeds = raw.replaceAll(_objectReplacementChar, '');
    final cleaned = withoutEmbeds.replaceAll(_whitespaceRun, ' ').trim();
    return (text: cleaned, imageCount: imageCount);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final title = entry.title?.isNotEmpty == true ? entry.title! : '(Untitled)';
    final rawPreview = entry.preview?.isNotEmpty == true
        ? entry.preview!
        : (entry.content ?? '');
    final sanitizedPreview = _sanitizePreview(rawPreview);

    // Surface color, straight from the theme — matches what the user
    // picked in the Colors > Surface field and sees in the live
    // preview. No alpha dilution: the preview shows this color at
    // full strength, so the real tile should match exactly.
    final cardColor = colorScheme.surface;
    final onCardColor = colorScheme.onSurfaceVariant;

    final previewBaseStyle = theme.textTheme.bodyMedium?.copyWith(
      color: onCardColor,
    );

    // Screen-global accessibility fact (system text-scale factor),
    // read once here rather than deep inside a nested builder — this
    // is exactly what MediaQuery is for per current Flutter responsive
    // guidance (global device-level facts), as opposed to LayoutBuilder
    // (which answers "how much space do I have", not "did the user
    // turn on large text").
    final textScaleFactor = MediaQuery.textScalerOf(context).scale(1.0);
    final dateColumnWidth = (_dateColumnBaseWidth * textScaleFactor).clamp(
      _dateColumnBaseWidth,
      _dateColumnMaxWidth,
    );

    final card = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (entry.mood != null)
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        entry.mood!.emoji,
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(width: 4),
                      // Flexible + ellipsis: without this, a long mood label
                      // (or the same label at a large system text-scale
                      // factor) had nothing to stop this Row from overflowing
                      // horizontally on a narrow card — there was no
                      // wrap/shrink fallback at all on the label itself, only
                      // on the preview text further down. Wrapping just the
                      // label (not the emoji or the trailing favorite icon,
                      // both of which are fixed-size and should never be the
                      // thing that shrinks) means space pressure is absorbed
                      // by truncating the label text first, which is the
                      // least visually disruptive place for it to happen.
                      Flexible(
                        child: Text(
                          entry.mood!.label.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: onCardColor,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              if (entry.isFavorite)
                Icon(Icons.favorite, size: 14, color: colorScheme.primary),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 2),
          // Rendered as Text.rich rather than a plain Text so the
          // "🖼️ N photos" indicator (see _sanitizePreview) can be
          // appended as its own, slightly-muted TextSpan after the
          // real body text — rather than being string-concatenated
          // into the same span, which would make it indistinguishable
          // from text the user actually typed. maxLines/overflow still
          // apply to the whole thing exactly as they did on the
          // original Text(preview, ...), so long previews still clip
          // to 2 lines with a trailing ellipsis. Whether the indicator
          // itself survives that clipping depends on how much real
          // text precedes it on those 2 lines — if the body text alone
          // already fills both, the indicator is pushed off, same as
          // any other trailing word would be. No special-cased "always
          // show the indicator" logic is added: this preview was
          // already routinely truncated before this change (see the
          // "iw er u ui"/"op iu" entries in the reported screenshot, both
          // already ending in "…"), so letting the indicator truncate
          // like everything else is consistent, not a regression.
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: sanitizedPreview.text, style: previewBaseStyle),
                if (sanitizedPreview.imageCount > 0)
                  TextSpan(
                    // Leading space only when there's real text before
                    // it, so an image-only entry (empty cleaned text)
                    // doesn't show a stray leading space before the
                    // emoji.
                    text:
                        '${sanitizedPreview.text.isEmpty ? '' : ' '}'
                        '🖼️ ${sanitizedPreview.imageCount} '
                        '${sanitizedPreview.imageCount == 1 ? 'photo' : 'photos'}',
                    style: previewBaseStyle?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: onCardColor.withValues(alpha: 0.75),
                    ),
                  ),
              ],
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return DebouncedTap(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date column — omitted when a parent list already renders
            // its own date tile (see [showDateColumn] doc above).
            //
            // Width is now dateColumnWidth (base 56, scaled up to a
            // clamped max of 80 at large system text sizes) rather than
            // a bare fixed 56 — see the class-level RESPONSIVE NOTES
            // doc and the [_dateColumnBaseWidth]/[_dateColumnMaxWidth]
            // fields above for why a fixed width risked the day number
            // or weekday abbreviation clipping/overflowing once the
            // user scales up system text.
            if (showDateColumn) ...[
              SizedBox(
                width: dateColumnWidth,
                child: Column(
                  children: [
                    Text(
                      AppDateUtils.dayOfMonthPadded(entry.date),
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      AppDateUtils.weekdayNameShort(entry.date.weekday),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: card),
          ],
        ),
      ),
    );
  }
}
