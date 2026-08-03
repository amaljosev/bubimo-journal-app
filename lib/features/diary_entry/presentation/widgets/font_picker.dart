// lib/features/diary_entry/presentation/widgets/font_picker.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/theme/font/safe_font_service.dart';
import '../../../../core/theme/google_fonts_catalog.dart';
import '../../../../core/widgets/needs_internet_inline.dart';

/// A single selectable font option: a display label and the resolved
/// Google Fonts family name — `null` means "Default" (no font
/// override; the entry's text renders in whatever the surrounding
/// theme/style already provides).
class _FontOption {
  final String label;
  final String? fontFamily;

  const _FontOption(this.label, this.fontFamily);
}

/// Font options offered to the user: 'Default' (no override) followed
/// by every family in [GoogleFontsCatalog] — the same list the
/// custom-theme Font Picker draws from, so a font available in one
/// picker is available in the other. Previews are resolved through
/// [SafeFontService.resolveTextStyle], not `GoogleFonts` directly —
/// this list used to hold its own curated subset with a
/// `GoogleFonts.<family>()` accessor call baked into each entry, which
/// meant opening this sheet built several live font previews at once,
/// each one an unhandled-exception risk if that family wasn't cached
/// and the device was offline (google_fonts fetches over HTTP on a
/// detached Future nothing here could catch). Routing through
/// [SafeFontService] instead means an uncached family just renders in
/// the system font until it's available.
///
/// Kept as a single flat list (no category grouping) — the redesigned
/// picker favors a short, scannable list over a filterable grid, so
/// there's no tab row spending vertical space on a sheet that's meant
/// to feel lightweight.
final List<_FontOption> _fontOptions = [
  const _FontOption('Default', null),
  for (final family in GoogleFontsCatalog.families) _FontOption(family, family),
];

/// Minimal, single-list font picker: a small heading and a scrollable
/// column of font rows, each previewed in its own font. No search/
/// filter row, no category tabs, no close button — the sheet is
/// dismissed the same way every other inline panel in
/// `DiaryBottomToolbar` is (tapping the "Aa" button again, tapping the
/// editor area, or opening a different panel), so a dedicated close
/// affordance would just be a second, redundant way to do the same
/// thing.
///
/// Selection state lives in a [ValueNotifier] scoped to the list, so
/// picking a font only rebuilds the previously-selected row and the
/// newly-selected row — not the whole sheet.
class FontPicker extends StatefulWidget {
  final String? selectedFontFamily;
  final ValueChanged<String?> onFontSelected;

  /// Optional callback called immediately after `onFontSelected` to
  /// reassert unfocus on the editor, preventing the keyboard from
  /// popping up while the panel is still open.
  final VoidCallback? onAfterFormat;

  const FontPicker({
    super.key,
    required this.selectedFontFamily,
    required this.onFontSelected,
    this.onAfterFormat,
  });

  @override
  State<FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<FontPicker> {
  late final ValueNotifier<String?> _selectedFamily =
      ValueNotifier<String?>(widget.selectedFontFamily);

  /// Checked once when the panel opens (fonts are typically browsed
  /// for a few seconds, not left open — a live connectivity stream
  /// would be overkill here). This never blocks the list the way the
  /// sticker/background pickers' full-body gate does — it only warns
  /// that fonts NOT already cached won't render their real typeface
  /// until back online (Flutter falls back to the platform default
  /// silently otherwise, which reads as "the font just didn't apply"
  /// rather than explaining why).
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final hasInternet = await getIt<SafeFontService>().isOnline;
    if (!mounted) return;
    setState(() => _isOffline = !hasInternet);
  }

  @override
  void didUpdateWidget(covariant FontPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFontFamily != widget.selectedFontFamily) {
      _selectedFamily.value = widget.selectedFontFamily;
    }
  }

  @override
  void dispose() {
    _selectedFamily.dispose();
    super.dispose();
  }

  Future<void> _handleFontTap(String? resolvedFamily) async {
    _selectedFamily.value = resolvedFamily;

    if (resolvedFamily != null) {
      // Same principle as the Custom Theme screen's Font Picker sheet
      // (see FontPickerSheet._handleFontTap): secure the real font
      // FIRST, and only report the pick to the page once that attempt
      // has settled — rather than applying the pick immediately and
      // relying on a fire-and-forget download to quietly finish and
      // somehow get picked up later. That's what made this picker
      // behave differently from the (working) Custom Theme one: the
      // Custom Theme sheet never hands its result back until
      // `ensureFontAvailable` has already resolved, so by the time
      // anything renders the new font, it's guaranteed to actually be
      // there.
      final result = await getIt<SafeFontService>().ensureFontAvailable(
        resolvedFamily,
      );
      if (!mounted) return;
      result.match(
        (failure) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        ),
        (_) {},
      );
      if (!mounted) return;
    }

    widget.onFontSelected(resolvedFamily);
    // Reassert unfocus after the format operation that may have refocused
    widget.onAfterFormat?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fontService = getIt<SafeFontService>();

    // No outer Container/rounded sheet chrome here — this widget is
    // rendered as an inline panel docked above the toolbar (see
    // `DiaryBottomToolbar._buildActivePanel`), which already provides
    // the panel's surface/height; adding a second nested surface here
    // would double up the background and look heavier than intended.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            'Font',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
        ),
        if (_isOffline)
          const NeedsInternetBanner(
            message:
                "You're offline — fonts you haven't used before won't "
                'load until you reconnect. Already-used fonts still work.',
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            itemCount: _fontOptions.length,
            itemBuilder: (context, index) {
              final option = _fontOptions[index];
              final family = option.fontFamily;
              final style = family == null
                  ? const TextStyle()
                  : fontService.resolveTextStyle(
                      fontFamily: family,
                      base: const TextStyle(),
                    );

              return _FontRow(
                label: option.label,
                style: style,
                resolvedFamily: family,
                selectedFamily: _selectedFamily,
                onTap: () => _handleFontTap(family),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A single font row: label previewed in its own font, with a subtle
/// selected state (tinted background + check) instead of the previous
/// grid tile's border/shadow treatment — flatter and quieter, in
/// keeping with a "lightweight" picker.
class _FontRow extends StatelessWidget {
  final String label;
  final TextStyle style;
  final String? resolvedFamily;
  final ValueNotifier<String?> selectedFamily;
  final VoidCallback onTap;

  const _FontRow({
    required this.label,
    required this.style,
    required this.resolvedFamily,
    required this.selectedFamily,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ValueListenableBuilder<String?>(
      valueListenable: selectedFamily,
      builder: (context, currentFamily, _) {
        final isSelected = currentFamily == resolvedFamily;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 2),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.primary.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: style.copyWith(
                        fontSize: 16,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}