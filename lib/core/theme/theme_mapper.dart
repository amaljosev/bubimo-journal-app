// lib/core/theme/theme_mapper.dart

import 'package:flutter/material.dart';

import '../../../features/theme/domain/entities/app_theme_data.dart';
import 'background_image_theme_extension.dart';
import 'font/safe_font_service.dart';
import 'theme_data_builder.dart';

/// Converts a domain [AppThemeData] into a Flutter [ThemeData].
///
/// Kept as a standalone pure function (not a method on [AppThemeData]
/// itself, and not inlined into `AppThemeCubit`) so the domain layer
/// stays free of `ThemeData`/`Color` concerns and this conversion logic
/// is independently readable/testable.
///
/// Colors come from [AppThemeData]'s [RgbaColor] value objects via
/// `.toColor()` — the domain layer never imports `dart:ui`/`material`
/// directly (see `rgba_color.dart`).
///
/// Builds a fully manual [ColorScheme] from the theme's 5 explicit
/// color roles, rather than deriving one via `ColorScheme.fromSeed`.
/// Each of the user's picks maps onto exactly the `ColorScheme` slot
/// its name promises, so what a user sees in the Create/Edit Custom
/// Theme preview is exactly what's applied app-wide — no seed
/// algorithm silently reinterpreting a "Secondary" pick into a
/// different generated tone:
/// - [AppThemeData.primaryColor] -> `primary` (+ `onPrimary`)
/// - [AppThemeData.secondaryColor] -> `secondary` (+ `onSecondary`),
///   and also stands in for `tertiary` (+ `onTertiary`) — this app's
///   forms only ever collect 5 colors, so any widget that reaches for
///   a third accent role gets the same, real, user-picked secondary
///   color rather than an unrelated Material default.
/// - [AppThemeData.surfaceColor] -> `surface` AND every
///   `surfaceContainer*` tone (`surfaceContainerLowest` through
///   `surfaceContainerHighest`), `outline`/`outlineVariant` (as
///   semi-transparent tints of [AppThemeData.textColor]), since
///   `theme_mapper` previously left these unset, meaning they fell
///   back to `ColorScheme.light()`/`.dark()`'s generic defaults —
///   defaults that have no relationship to a custom theme's actual
///   picked colors and could coincidentally match `backgroundColor`,
///   making entire widgets (e.g. the Analytics heatmap/mood chart)
///   visually disappear against the page background.
/// - [AppThemeData.backgroundColor] -> scaffold background, plus
///   `surfaceDim`/`surfaceBright` (both derived from it) and
///   `inverseSurface`/`onInverseSurface`/`inversePrimary` (derived by
///   flipping brightness, so a tooltip or snackbar using these roles
///   still contrasts correctly against the theme rather than reverting
///   to Material's fixed almost-black/almost-white).
/// - [AppThemeData.textColor] -> `onSurface`, `onPrimary`/`onSecondary`
///   is computed separately for contrast against the (possibly
///   differently-toned) primary/secondary colors, since a theme's
///   chosen text color is meant for body text on background/surface,
///   not necessarily readable on top of a saturated primary color.
///
/// [AppThemeData.isDark] is an explicit user choice (Light/Dark Mode
/// toggle in the form) rather than derived from background luminance —
/// this is what [Brightness] is set from here.
///
/// [AppThemeData.fontFamily] is a Google Fonts family name applied
/// across the entire generated `TextTheme` — every text style
/// (headings through body) uses the theme's font. Resolution goes
/// through [fontService] (see [SafeFontService]) rather than calling
/// `GoogleFonts.getTextTheme` directly: `google_fonts` fetches over
/// HTTP the first time a family is used, on a detached Future this
/// call site has no handle on, so a plain try/catch here can't
/// protect against an offline failure — [SafeFontService] only ever
/// calls into `google_fonts` for a family it has already confirmed is
/// cached, and falls back to the system font instead of guessing
/// otherwise. See that class's doc comment for the full reasoning.
///
/// The rest of the `ThemeData` shape (card/appBar/input decoration
/// shapes) is shared with `AppTheme` via [ThemeDataBuilder] so the two
/// theme-construction paths can't drift apart.
ThemeData buildThemeData(AppThemeData theme, SafeFontService fontService) {
  final primaryColor = theme.primaryColor.toColor();
  final secondaryColor = theme.secondaryColor.toColor();
  final surfaceColor = theme.surfaceColor.toColor();
  final backgroundColor = theme.backgroundColor.toColor();
  final textColor = theme.textColor.toColor();

  final brightness = theme.isDark ? Brightness.dark : Brightness.light;
  final isDark = brightness == Brightness.dark;

  // Every `surfaceContainer*` tone is derived from the theme's own
  // surfaceColor, stepped slightly lighter/darker so cards nested atop
  // other cards (e.g. a chart's bar background sitting on its own
  // card) remain visually distinguishable — but always as a tint of
  // the theme's real surfaceColor, never an unrelated Material
  // default that could coincidentally equal backgroundColor.
  final surfaceContainerLowest =
      _tone(surfaceColor, backgroundColor, isDark ? -0.4 : 0.35);
  final surfaceContainerLow =
      _tone(surfaceColor, backgroundColor, isDark ? -0.2 : 0.18);
  final surfaceContainer = surfaceColor;
  final surfaceContainerHigh =
      _tone(surfaceColor, textColor, isDark ? 0.06 : 0.05);
  final surfaceContainerHighest =
      _tone(surfaceColor, textColor, isDark ? 0.12 : 0.09);

  // surfaceDim/surfaceBright bracket backgroundColor slightly
  // darker/lighter, matching Material 3's intent (dim < surface <
  // bright) without ever leaving the theme's own hue.
  final surfaceDim = _tone(backgroundColor, textColor, isDark ? 0.0 : 0.08);
  final surfaceBright =
      _tone(backgroundColor, textColor, isDark ? 0.14 : 0.0);

  // outline/outlineVariant: semi-transparent tints of textColor, so
  // dividers/borders always read as "muted text color" against this
  // theme's surfaces specifically, rather than a fixed gray that may
  // not suit a saturated or dark custom palette.
  final outline = textColor.withValues(alpha: 0.4);
  final outlineVariant = textColor.withValues(alpha: 0.18);

  // inverseSurface/onInverseSurface/inversePrimary: flip brightness so
  // a tooltip/snackbar using these roles still contrasts correctly
  // against the theme, instead of Material's fixed near-black/
  // near-white (which can clash with a strongly-tinted custom theme).
  final inverseSurface = isDark ? const Color(0xFFF5F5F5) : const Color(0xFF1A1A1A);
  final onInverseSurface = isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F5F5);
  final inversePrimary = _onColorFor(primaryColor) == Colors.white
      ? primaryColor
      : secondaryColor;

  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: primaryColor,
    onPrimary: _onColorFor(primaryColor),
    secondary: secondaryColor,
    onSecondary: _onColorFor(secondaryColor),
    tertiary: secondaryColor,
    onTertiary: _onColorFor(secondaryColor),
    surface: surfaceColor,
    onSurface: textColor,
    onSurfaceVariant: textColor.withValues(alpha: 0.7),
    surfaceContainerLowest: surfaceContainerLowest,
    surfaceContainerLow: surfaceContainerLow,
    surfaceContainer: surfaceContainer,
    surfaceContainerHigh: surfaceContainerHigh,
    surfaceContainerHighest: surfaceContainerHighest,
    surfaceDim: surfaceDim,
    surfaceBright: surfaceBright,
    outline: outline,
    outlineVariant: outlineVariant,
    inverseSurface: inverseSurface,
    onInverseSurface: onInverseSurface,
    inversePrimary: inversePrimary,
    error: const Color(0xFFB3261E),
    onError: Colors.white,
  );

  // Base text theme (correct default weights/sizes) first, then swap
  // in the theme's font family AND the theme's explicit text color
  // across all styles — GoogleFonts.getTextTheme's base theme would
  // otherwise supply its own on-surface color derived from brightness,
  // which could disagree with the user's explicit [textColor] pick.
  final baseTextTheme = brightness == Brightness.dark
      ? ThemeData(brightness: Brightness.dark).textTheme
      : ThemeData(brightness: Brightness.light).textTheme;
  final themedTextTheme = fontService
      .resolveTextTheme(fontFamily: theme.fontFamily, base: baseTextTheme)
      .apply(bodyColor: textColor, displayColor: textColor);

  return ThemeDataBuilder.build(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: backgroundColor,
    textTheme: themedTextTheme,
    transparentAppBar: true,
    extensions: [
      BackgroundImageTheme(
        imagePath: theme.headerImagePath,
        isAsset: theme.isHeaderImageAsset,
      ),
    ],
  );
}

/// Blends [base] toward [target] by [amount] (0.0 = pure [base], 1.0 =
/// pure [target]) — used to derive every `surfaceContainer*`/
/// `surfaceDim`/`surfaceBright` tone as a small, visible step away from
/// the theme's own surface/background color, so nested surfaces (e.g.
/// a bar chart's background bar sitting on its own card) stay
/// distinguishable from one another without ever drifting to an
Color _tone(Color base, Color target, double amount) {
  return Color.lerp(base, target, amount.clamp(0.0, 1.0)) ?? base;
}

/// A readable on-color (black or white) for content painted on top of
/// [background] — used for `onPrimary`/`onSecondary`/`onTertiary`,
/// since a theme's user-picked [AppThemeData.textColor] is meant for
/// body text on background/surface, not necessarily a saturated
/// primary/secondary color, and forcing it there could produce
/// unreadable button labels.
Color _onColorFor(Color background) {
  return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
      ? Colors.white
      : Colors.black87;
}