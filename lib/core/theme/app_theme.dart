// lib/core/theme/app_theme.dart

import 'package:flutter/material.dart';

import 'font/safe_font_service.dart';
import 'theme_data_builder.dart';

/// Builds the app's base/default ThemeData.
///
/// This is the fallback theme used before AppThemeCubit (theme feature)
/// loads the user's selected theme, and the template default preset
/// themes are derived from. Uses current Material 3 conventions
/// (ColorScheme.fromSeed) rather than deprecated primarySwatch/accentColor
/// fields.
///
/// Uses [SafeFontService.bundledDefaultFamily] directly (not
/// `GoogleFonts`, and not [SafeFontService] itself, which isn't
/// necessarily constructed yet at the exact moment `AppThemeCubit`'s
/// `super(...)` initializer runs) — this ThemeData exists specifically
/// to render correctly before anything else in the app has had a
/// chance to load, so it can only lean on the one font guaranteed to
/// be a plain native asset with zero network/service dependency.
///
/// The actual `ThemeData` shape (card/appBar/input decoration shapes)
/// is shared with `theme_mapper.dart` via [ThemeDataBuilder] so the two
/// theme-construction paths can't drift apart.
class AppTheme {
  AppTheme._();

  static ThemeData light({Color seedColor = const Color(0xFF6750A4)}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeDataBuilder.build(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: ThemeData(brightness: Brightness.light)
          .textTheme
          .apply(fontFamily: SafeFontService.bundledDefaultFamily),
    );
  }

  static ThemeData dark({Color seedColor = const Color(0xFF6750A4)}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return ThemeDataBuilder.build(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      textTheme: ThemeData(brightness: Brightness.dark)
          .textTheme
          .apply(fontFamily: SafeFontService.bundledDefaultFamily),
    );
  }
}