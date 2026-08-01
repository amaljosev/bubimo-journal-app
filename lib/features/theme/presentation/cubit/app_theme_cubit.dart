// lib/features/theme/presentation/cubit/app_theme_cubit.dart

import 'package:bubimo/core/theme/app_theme.dart';
import 'package:bubimo/core/theme/theme_mapper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/theme/font/safe_font_service.dart';
import '../../domain/entities/app_theme_data.dart';
import '../../domain/usecases/get_selected_theme.dart';
import '../../domain/usecases/reset_to_default_theme.dart';
import '../../domain/usecases/select_theme.dart';

/// Holds the app's CURRENT active [ThemeData] and is provided ABOVE
/// `MaterialApp`, so any theme change rebuilds the whole app live — no
/// restart required.
///
/// Registered as a lazy singleton in GetIt (not a factory), since it
/// must persist for the app's entire lifetime.
///
/// [ThemeData] construction (color scheme, font, header image
/// extension) is delegated to [buildThemeData] in `theme_mapper.dart`
/// rather than built inline here, so that conversion logic stays
/// independently readable/testable and isn't duplicated.
///
/// Deliberately NOT used by the Theme Switcher's list items to render
/// each theme's own font preview — those read [AppThemeData.fontFamily]
/// directly per-item via `SafeFontService.resolveTextStyle` (see
/// `ThemeFontLabel`), independent of whichever theme is currently
/// active here. See `built_in_theme_tile.dart` / `custom_theme_tile.dart`.
class AppThemeCubit extends Cubit<ThemeData> {
  final GetSelectedTheme getSelectedTheme;
  final SelectTheme selectTheme;
  final ResetToDefaultTheme resetToDefaultTheme;
  final SafeFontService fontService;

  /// The domain data behind the current [state], kept alongside it so
  /// screens (e.g. Theme Screen's "currently applied theme" header) can
  /// read which theme id/name/font is active without a separate query.
  AppThemeData? currentTheme;

  AppThemeCubit({
    required this.getSelectedTheme,
    required this.selectTheme,
    required this.resetToDefaultTheme,
    required this.fontService,
  }) : super(AppTheme.light()) {
    // Live-refresh the active theme if the font it's using finishes a
    // background download after the theme was already applied with a
    // fallback font — e.g. it was applied while offline, and the
    // periodic retry / reconnect sweep in main.dart later succeeds.
    // Without this, the user would only ever see the real font by
    // re-applying the theme themselves.
    fontService.onFontBecameAvailable = _onFontBecameAvailable;
  }

  void _onFontBecameAvailable(String family) {
    final theme = currentTheme;
    if (theme != null && theme.fontFamily == family) {
      emit(buildThemeData(theme, fontService));
    }
  }

  /// Loads the user's previously selected theme. Call this once during
  /// app startup, before `runApp`, so the correct theme is active on
  /// first frame instead of flashing the fallback default.
  ///
  /// Deliberately does NOT await font availability the way
  /// [_applyResolvedTheme] does for an explicit theme change — this
  /// runs before `runApp`, and startup should never be held up
  /// waiting on a network fetch. [buildThemeData] already renders
  /// safely regardless (bundled font, a previously-cached font, or a
  /// graceful system-font fallback); if the theme's font isn't cached
  /// yet, [SafeFontService.onFontBecameAvailable] upgrades the live
  /// theme automatically the moment the background precache sweep
  /// (started in `main.dart`) secures it.
  Future<void> loadInitialTheme() async {
    final result = await getSelectedTheme();
    result.match(
      (_) {
        // Fall back silently to the default ThemeData already set as
        // this cubit's initial state — there's nothing meaningful to
        // show the user for a startup theme-load failure.
      },
      (theme) {
        currentTheme = theme;
        emit(buildThemeData(theme, fontService));
      },
    );
  }

  /// Persists [themeId] as the selection and applies it immediately —
  /// this is what the Theme Switcher's "Apply Theme" button (custom
  /// themes) and instant-tap (built-in themes) both call.
  ///
  /// A `Left` result here does NOT necessarily mean nothing happened —
  /// see [_applyResolvedTheme]'s doc comment. A `Left` from
  /// [selectTheme] itself (persistence genuinely failed) is the one
  /// case where the theme was NOT applied at all.
  Future<Either<Failure, void>> changeTheme(String themeId) async {
    final selectResult = await selectTheme(themeId);
    if (selectResult.isLeft()) return selectResult;

    return _refreshFromRepository();
  }

  /// Applies the default built-in theme — backs the "Reset to Default"
  /// button on the Theme Switcher screen. Same `Left`-doesn't-mean-
  /// nothing-happened caveat as [changeTheme].
  Future<Either<Failure, void>> resetToDefault() async {
    final resetResult = await resetToDefaultTheme();
    if (resetResult.isLeft()) return resetResult;

    return _refreshFromRepository();
  }

  Future<Either<Failure, void>> _refreshFromRepository() async {
    final selectedResult = await getSelectedTheme();
    return selectedResult.match(
      (failure) async => Left(failure),
      (theme) => _applyResolvedTheme(theme),
    );
  }

  /// Applies [theme]'s colors/layout immediately and separately
  /// ensures its font is actually available, awaiting that check so a
  /// freshly-downloaded font shows up in this same emit rather than
  /// needing a second rebuild later.
  ///
  /// The theme's `ThemeData` is emitted regardless of the font
  /// outcome — colors, spacing, and header image all apply either
  /// way, using [SafeFontService]'s safe fallback for text if the
  /// font isn't ready. The returned `Either` reports the font
  /// specifically: `Right(null)` if it was already available or just
  /// downloaded successfully, `Left(NoInternetFailure)` /
  /// `Left(FontDownloadFailure)` if not — callers (see
  /// `ThemeListBloc`) should treat that `Left` as "applied, with a
  /// font caveat to show the user", not as "the whole action failed".
  Future<Either<Failure, void>> _applyResolvedTheme(
    AppThemeData theme,
  ) async {
    currentTheme = theme;

    final fontResult = await fontService.ensureFontAvailable(
      theme.fontFamily,
    );

    emit(buildThemeData(theme, fontService));

    return fontResult;
  }
}