// lib/features/theme/presentation/widgets/shared/theme_font_label.dart
//
// ⚠️ RECONSTRUCTED, NOT YOUR ORIGINAL FILE.
// I don't have your actual theme_font_label.dart — this was rebuilt
// purely from how built_in_theme_tile.dart, custom_theme_tile.dart,
// and current_theme_header.dart call it (positional `text`, named
// `fontFamily`/`fontSize`/`fontWeight`/`color`). Please diff this
// against your real file before replacing it — I may be missing
// something (animation, a semantics label, etc.) that only lives in
// the original. The one change that actually matters, wherever your
// real file ends up: route through SafeFontService instead of
// GoogleFonts directly, for the same reason theme_mapper.dart does —
// every theme tile on the Theme Switcher screen renders its name in
// its own font simultaneously, so this was a second, independent
// crash site for the exact same offline bug.

import 'package:flutter/material.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/font/safe_font_service.dart';

/// Renders [text] in [fontFamily], resolved safely via
/// [SafeFontService] — so a theme tile's name/font-name label can
/// never crash the Theme Switcher screen even when that specific
/// family hasn't been downloaded yet. It silently renders in the
/// system font instead, until the background precache sweep (or the
/// user applying that theme) secures the real one.
class ThemeFontLabel extends StatelessWidget {
  final String text;
  final String fontFamily;
  final double fontSize;
  final FontWeight? fontWeight;
  final Color color;
  final TextOverflow? overflow;
  final int? maxLines;

  const ThemeFontLabel(
    this.text, {
    super.key,
    required this.fontFamily,
    required this.fontSize,
    this.fontWeight,
    required this.color,
    this.overflow,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    final style = getIt<SafeFontService>().resolveTextStyle(
      fontFamily: fontFamily,
      base: TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      ),
    );

    return Text(
      text,
      style: style,
      overflow: overflow,
      maxLines: maxLines,
    );
  }
}