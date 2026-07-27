// lib/features/rich_editor/presentation/widgets/font_picker.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// A single selectable font option: a display label and a function
/// that builds its Google Fonts TextStyle (used both for the tile
/// preview and to resolve the actual font family string).
class _FontOption {
  final String label;
  final TextStyle Function() styleBuilder;

  const _FontOption(this.label, this.styleBuilder);
}

/// Font options offered to the user, backed by `google_fonts` — no
/// bundled font assets or `flutter: fonts:` pubspec entries needed.
/// Fonts are fetched on first use and cached by the package afterward;
/// the very first render of each font may require a brief network
/// fetch (falls back to the default font if offline and not yet
/// cached).
///
/// Kept as a single flat list (no category grouping) — the redesigned
/// picker favors a short, scannable list over a filterable grid, so
/// there's no tab row spending vertical space on a sheet that's meant
/// to feel lightweight.
final List<_FontOption> _fontOptions = [
  _FontOption('Default', () => const TextStyle()),

  // ── Handwriting / script — personal, diary-like ──────────────────
  _FontOption('Caveat', () => GoogleFonts.caveat()),
  _FontOption('Dancing Script', () => GoogleFonts.dancingScript()),
  _FontOption('Kalam', () => GoogleFonts.kalam()),
  _FontOption('Shadows Into Light', () => GoogleFonts.shadowsIntoLight()),
  _FontOption('Indie Flower', () => GoogleFonts.indieFlower()),
  _FontOption('Patrick Hand', () => GoogleFonts.patrickHand()),
  _FontOption('Satisfy', () => GoogleFonts.satisfy()),
  _FontOption('Sacramento', () => GoogleFonts.sacramento()),
  _FontOption('Great Vibes', () => GoogleFonts.greatVibes()),
  _FontOption('Homemade Apple', () => GoogleFonts.homemadeApple()),
  _FontOption('Reenie Beanie', () => GoogleFonts.reenieBeanie()),
  _FontOption('Amatic SC', () => GoogleFonts.amaticSc()),
  _FontOption('Caveat Brush', () => GoogleFonts.caveatBrush()),

  // ── Serif — classic, reflective ──────────────────────────────────
  _FontOption('Merriweather', () => GoogleFonts.merriweather()),
  _FontOption('Lora', () => GoogleFonts.lora()),
  _FontOption('Playfair Display', () => GoogleFonts.playfairDisplay()),
  _FontOption('EB Garamond', () => GoogleFonts.ebGaramond()),
  _FontOption('Crimson Text', () => GoogleFonts.crimsonText()),
  _FontOption('Cormorant Garamond', () => GoogleFonts.cormorantGaramond()),
  _FontOption('PT Serif', () => GoogleFonts.ptSerif()),
  _FontOption('Libre Baskerville', () => GoogleFonts.libreBaskerville()),
  _FontOption('Bitter', () => GoogleFonts.bitter()),
  _FontOption('Spectral', () => GoogleFonts.spectral()),

  // ── Sans-serif — clean, easy everyday reading ────────────────────
  _FontOption('Nunito', () => GoogleFonts.nunito()),
  _FontOption('Poppins', () => GoogleFonts.poppins()),
  _FontOption('Quicksand', () => GoogleFonts.quicksand()),
  _FontOption('Lato', () => GoogleFonts.lato()),
  _FontOption('Inter', () => GoogleFonts.inter()),
  _FontOption('Roboto', () => GoogleFonts.roboto()),
  _FontOption('Open Sans', () => GoogleFonts.openSans()),
  _FontOption('Montserrat', () => GoogleFonts.montserrat()),
  _FontOption('Raleway', () => GoogleFonts.raleway()),
  _FontOption('Work Sans', () => GoogleFonts.workSans()),
  _FontOption('Karla', () => GoogleFonts.karla()),

  // ── Playful / display — lighter, expressive entries ──────────────
  _FontOption('Pacifico', () => GoogleFonts.pacifico()),
  _FontOption('Comic Neue', () => GoogleFonts.comicNeue()),
  _FontOption('Fredoka', () => GoogleFonts.fredoka()),
  _FontOption('Baloo 2', () => GoogleFonts.baloo2()),
  _FontOption('Righteous', () => GoogleFonts.righteous()),
  _FontOption('Lobster', () => GoogleFonts.lobster()),

  // ── Monospace — for a typewriter-diary feel ──────────────────────
  _FontOption('Roboto Mono', () => GoogleFonts.robotoMono()),
  _FontOption('Space Mono', () => GoogleFonts.spaceMono()),
  _FontOption('JetBrains Mono', () => GoogleFonts.jetBrainsMono()),
  _FontOption('Source Code Pro', () => GoogleFonts.sourceCodePro()),
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

  const FontPicker({
    super.key,
    required this.selectedFontFamily,
    required this.onFontSelected,
  });

  @override
  State<FontPicker> createState() => _FontPickerState();
}

class _FontPickerState extends State<FontPicker> {
  late final ValueNotifier<String?> _selectedFamily =
      ValueNotifier<String?>(widget.selectedFontFamily);

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

  void _handleFontTap(String? resolvedFamily) {
    _selectedFamily.value = resolvedFamily;
    widget.onFontSelected(resolvedFamily);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
            itemCount: _fontOptions.length,
            itemBuilder: (context, index) {
              final option = _fontOptions[index];
              final style = option.styleBuilder();
              final isDefault = option.label == 'Default';
              final resolvedFamily = isDefault ? null : style.fontFamily;

              return _FontRow(
                label: option.label,
                style: style,
                resolvedFamily: resolvedFamily,
                selectedFamily: _selectedFamily,
                onTap: () => _handleFontTap(resolvedFamily),
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