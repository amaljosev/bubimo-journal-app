// lib/features/theme/presentation/bloc/custom_theme_form/custom_theme_form_state.dart

part of 'custom_theme_form_bloc.dart';

enum CustomThemeFormStatus { initial, ready, submitting, success, failure }

/// WCAG AA minimum contrast ratio for normal-size body text against its
/// background. Applied to the active palette's [textColor] against
/// both [backgroundColor] and [surfaceColor], since text renders on
/// both.
const double kMinTextContrastRatio = 4.5;

class CustomThemeFormState extends Equatable {
  final CustomThemeFormStatus status;

  /// Non-null once editing an existing custom theme — `null` in create
  /// mode. Kept as the id string (not a bool flag) so the bloc's submit
  /// handler can build the correct [AppThemeData.id] for the upsert.
  final String? editingThemeId;

  final String name;

  /// True for Dark Mode, false for Light Mode. Determines which of
  /// [lightPalette] / [darkPalette] is currently active and rendered
  /// by every color field + the live preview.
  final bool isDark;

  /// This theme's Light Mode colors. Always populated (falls back to
  /// Dusk's defaults if the theme has never had a Light Mode palette).
  final ThemePalette lightPalette;

  /// This theme's Dark Mode colors. Always populated (falls back to
  /// Nightfall's defaults if the theme has never had a Dark Mode
  /// palette).
  final ThemePalette darkPalette;

  final String fontFamily;
  final String? headerImagePath;

  final String? errorMessage;

  const CustomThemeFormState({
    this.status = CustomThemeFormStatus.initial,
    this.editingThemeId,
    this.name = '',
    this.isDark = false,
    ThemePalette? lightPalette,
    ThemePalette? darkPalette,
    this.fontFamily = 'Poppins',
    this.headerImagePath,
    this.errorMessage,
  }) : lightPalette = lightPalette ?? _defaultLightPalette,
       darkPalette = darkPalette ?? _defaultDarkPalette;

  /// Default Light Mode palette — matches the previous hard-coded
  /// defaults on this state (Dusk-like violet), used when a brand-new
  /// form is created before [CustomThemeFormInitialized] fires and as
  /// the ultimate fallback if a theme has no saved Light palette.
  static const ThemePalette _defaultLightPalette = ThemePalette(
    primaryColor: RgbaColor(red: 103, green: 80, blue: 164),
    secondaryColor: RgbaColor(red: 125, green: 82, blue: 96),
    surfaceColor: RgbaColor(red: 245, green: 243, blue: 250),
    backgroundColor: RgbaColor(red: 255, green: 251, blue: 254),
    textColor: RgbaColor(red: 29, green: 25, blue: 32),
  );

  /// Default Dark Mode palette — mirrors [_defaultLightPalette]'s role
  /// but inverted for dark backgrounds, used as the ultimate fallback
  /// if a theme has no saved Dark palette yet (before the bloc has a
  /// chance to substitute Nightfall's real colors in via
  /// `_defaultPaletteFor`).
  static const ThemePalette _defaultDarkPalette = ThemePalette(
    primaryColor: RgbaColor(red: 128, green: 148, blue: 220),
    secondaryColor: RgbaColor(red: 39, green: 51, blue: 137),
    surfaceColor: RgbaColor(red: 32, green: 33, blue: 66),
    backgroundColor: RgbaColor(red: 20, green: 21, blue: 48),
    textColor: RgbaColor(red: 228, green: 229, blue: 245),
  );

  bool get isEditing => editingThemeId != null;
  bool get isSubmitting => status == CustomThemeFormStatus.submitting;

  /// The palette for whichever mode is currently active — every color
  /// field and the live preview read through this rather than picking
  /// between [lightPalette]/[darkPalette] themselves.
  ThemePalette get activePalette => isDark ? darkPalette : lightPalette;

  RgbaColor get primaryColor => activePalette.primaryColor;
  RgbaColor get secondaryColor => activePalette.secondaryColor;
  RgbaColor get surfaceColor => activePalette.surfaceColor;
  RgbaColor get backgroundColor => activePalette.backgroundColor;
  RgbaColor get textColor => activePalette.textColor;

  /// Contrast ratio of the active palette's [textColor] against its
  /// [backgroundColor].
  double get textVsBackgroundRatio =>
      textColor.contrastRatioWith(backgroundColor);

  /// Contrast ratio of the active palette's [textColor] against its
  /// [surfaceColor].
  double get textVsSurfaceRatio => textColor.contrastRatioWith(surfaceColor);

  /// True when [textColor] fails WCAG AA contrast against either
  /// [backgroundColor] or [surfaceColor] — text renders on both, so
  /// both need to stay readable.
  ///
  /// This is now advisory only: it drives a non-blocking warning
  /// banner, NOT [canSubmit]. The text-color picker itself already
  /// steers users away from low-contrast picks (it only offers swatches
  /// that pass contrast against the current background/surface), so
  /// this mainly catches the case where background/surface changed
  /// AFTER text color was picked.
  bool get hasTextContrastIssue =>
      textVsBackgroundRatio < kMinTextContrastRatio ||
      textVsSurfaceRatio < kMinTextContrastRatio;

  /// Human-readable, non-blocking warning for the text color field, or
  /// `null` if contrast is fine. Shown inline under the Text color
  /// field — the user can still save the theme even when this is
  /// non-null.
  String? get textColorWarning {
    if (hasTextContrastIssue) {
      return 'Low contrast — this text may be hard to read against the '
          'background or surface color.';
    }
    return null;
  }

  /// Saving is only blocked by an empty name or an in-flight submit —
  /// contrast issues are surfaced as a warning (see [textColorWarning])
  /// but never prevent saving.
  bool get canSubmit => name.trim().isNotEmpty && !isSubmitting;

  CustomThemeFormState copyWith({
    CustomThemeFormStatus? status,
    String? editingThemeId,
    String? name,
    bool? isDark,
    ThemePalette? lightPalette,
    ThemePalette? darkPalette,
    String? fontFamily,
    String? headerImagePath,
    bool clearHeaderImage = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return CustomThemeFormState(
      status: status ?? this.status,
      editingThemeId: editingThemeId ?? this.editingThemeId,
      name: name ?? this.name,
      isDark: isDark ?? this.isDark,
      lightPalette: lightPalette ?? this.lightPalette,
      darkPalette: darkPalette ?? this.darkPalette,
      fontFamily: fontFamily ?? this.fontFamily,
      headerImagePath: clearHeaderImage
          ? null
          : (headerImagePath ?? this.headerImagePath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  /// Convenience for updating just one field of the ACTIVE palette
  /// (i.e. whichever of [lightPalette]/[darkPalette] matches [isDark])
  /// without the caller needing to branch on mode first.
  CustomThemeFormState copyWithActivePaletteColor({
    RgbaColor? primaryColor,
    RgbaColor? secondaryColor,
    RgbaColor? surfaceColor,
    RgbaColor? backgroundColor,
    RgbaColor? textColor,
  }) {
    final updated = activePalette.copyWith(
      primaryColor: primaryColor,
      secondaryColor: secondaryColor,
      surfaceColor: surfaceColor,
      backgroundColor: backgroundColor,
      textColor: textColor,
    );
    return isDark
        ? copyWith(darkPalette: updated)
        : copyWith(lightPalette: updated);
  }

  @override
  List<Object?> get props => [
    status,
    editingThemeId,
    name,
    isDark,
    lightPalette,
    darkPalette,
    fontFamily,
    headerImagePath,
    errorMessage,
  ];
}
