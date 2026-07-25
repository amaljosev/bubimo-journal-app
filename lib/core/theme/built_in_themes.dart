// lib/core/theme/built_in_themes.dart

import '../../../features/theme/domain/entities/app_theme_data.dart';
import '../../../features/theme/domain/entities/rgba_color.dart';
import '../../../features/theme/domain/entities/theme_type.dart';

/// The 6 built-in themes, defined as static in-memory data — these are
/// never read from or written to the database. `ThemeRepositoryImpl`
/// prepends this list ahead of the persisted custom themes whenever
/// `getAllThemes()` is called.
///
/// Built-in theme ids are stable string constants (not generated via
/// [IdGenerator]) since they're referenced permanently — e.g. as the
/// `theme_id` value persisted in `app_settings`, and as
/// [defaultBuiltInThemeId] for "Reset to Default".
///
/// All but one built-in theme are Light Mode ([AppThemeData.isDark] =
/// false); [nightfall] is the sole dark-mode built-in. [surfaceColor]
/// is a near-white/near-background tint for light themes (cards/app
/// bars sit just barely above [backgroundColor]) — [nightfall] mirrors
/// this with a near-black/near-background tint instead. [textColor] is
/// chosen for a comfortable >4.5:1 contrast ratio against both
/// [backgroundColor] and [surfaceColor] in every theme.
class BuiltInThemes {
  BuiltInThemes._();

  static const String duskId = 'builtin_dusk';
  static const String meadowId = 'builtin_meadow';
  static const String oceanId = 'builtin_ocean';
  static const String sunsetId = 'builtin_sunset';
  static const String bloomId = 'builtin_bloom';
  static const String nightfallId = 'builtin_nightfall';

  /// The theme "Reset to Default" applies, and the one used on very
  /// first launch before any selection has been persisted.
  static const String defaultBuiltInThemeId = duskId;

  /// Bundled asset paths for the built-in themes that ship a header
  /// image.
  ///
  /// Re-mapped to match what each reference image actually depicts:
  /// `theme_1.jpg` is a pastel pink/lavender cloudscape (Bloom, not
  /// Ocean); `theme_2.jpg` is a vivid blue sky over a city skyline
  /// (Ocean, not Sunset); `theme_3.jpg` is a dark violet wildflower
  /// field under a night sky, which doesn't match any existing light
  /// theme and instead backs the new dark-mode [nightfall] theme.
  /// Register these under `flutter: assets:` in pubspec.yaml.
  static const String bloomHeaderAsset = 'assets/theme/theme_1.jpg';
  static const String oceanHeaderAsset = 'assets/theme/theme_2.jpg';
  static const String nightfallHeaderAsset = 'assets/theme/theme_3.jpg';

  /// Dusk — the default theme. Violet/lilac palette, no header image
  /// (Type 1: Colors + Font). Primary/accent pulled from a twilight
  /// wildflower-field reference (deep violet-blue + soft lilac).
  /// Background stays light for text-contrast safety, since the
  /// reference art itself is a genuinely dark night palette.
  static final AppThemeData dusk = AppThemeData(
    id: duskId,
    name: 'Dusk',
    type: ThemeType.colorsAndFont,
    primaryColor: const RgbaColor(red: 88, green: 86, blue: 168),
    secondaryColor: const RgbaColor(red: 168, green: 138, blue: 214),
    surfaceColor: const RgbaColor(red: 245, green: 243, blue: 250),
    backgroundColor: const RgbaColor(red: 253, green: 252, blue: 255),
    textColor: const RgbaColor(red: 32, green: 28, blue: 44),
    isDark: false,
    fontFamily: 'Poppins',
    isBuiltIn: true,
    isDefault: true,
  );

  /// Meadow — fresh green palette, no header image (Type 1).
  static final AppThemeData meadow = AppThemeData(
    id: meadowId,
    name: 'Meadow',
    type: ThemeType.colorsAndFont,
    primaryColor: const RgbaColor(red: 58, green: 106, blue: 62),
    secondaryColor: const RgbaColor(red: 121, green: 134, blue: 41),
    surfaceColor: const RgbaColor(red: 240, green: 248, blue: 236),
    backgroundColor: const RgbaColor(red: 247, green: 253, blue: 242),
    textColor: const RgbaColor(red: 27, green: 34, blue: 24),
    isDark: false,
    fontFamily: 'Nunito',
    isBuiltIn: true,
  );

  /// Ocean — teal/blue palette with a bundled header image (Type 2).
  /// Colors resampled directly from `theme_2.jpg` (vivid sky-blue
  /// cumulus clouds over a hazy city skyline): primary is the
  /// saturated cyan-blue of the open sky, secondary the deeper azure
  /// found in the cloud shadows and distant skyline haze.
  static final AppThemeData ocean = AppThemeData(
    id: oceanId,
    name: 'Ocean',
    type: ThemeType.colorsAndFontWithHeaderImage,
    primaryColor: const RgbaColor(red: 23, green: 168, blue: 229),
    secondaryColor: const RgbaColor(red: 38, green: 98, blue: 159),
    surfaceColor: const RgbaColor(red: 222, green: 242, blue: 253),
    backgroundColor: const RgbaColor(red: 235, green: 248, blue: 255),
    textColor: const RgbaColor(red: 12, green: 30, blue: 45),
    isDark: false,
    fontFamily: 'Quicksand',
    headerImagePath: oceanHeaderAsset,
    isHeaderImageAsset: true,
    isBuiltIn: true,
  );

  /// Sunset — warm amber/rose palette. No header image (Type 1: Colors
  /// + Font).
  ///
  /// Previously Type 2 with a bundled header image at `theme_2.jpg`,
  /// but that asset has been re-mapped to Ocean's blue-sky scene (see
  /// [oceanHeaderAsset] doc comment) since it was originally mismatched
  /// to Sunset. None of the 3 reference images supplied this round
  /// match Sunset's warm amber/rose palette, and reusing Ocean's photo
  /// here would show the identical image under two different theme
  /// names — so Sunset drops back to Type 1 until a real sunset
  /// reference image is supplied.
  static final AppThemeData sunset = AppThemeData(
    id: sunsetId,
    name: 'Sunset',
    type: ThemeType.colorsAndFont,
    primaryColor: const RgbaColor(red: 199, green: 120, blue: 0),
    secondaryColor: const RgbaColor(red: 180, green: 67, blue: 108),
    surfaceColor: const RgbaColor(red: 255, green: 240, blue: 234),
    backgroundColor: const RgbaColor(red: 255, green: 248, blue: 246),
    textColor: const RgbaColor(red: 43, green: 24, blue: 20),
    isDark: false,
    fontFamily: 'Merriweather',
    isBuiltIn: true,
  );

  /// Bloom — soft rose/lavender palette with a bundled header image
  /// (Type 2). Colors resampled directly from `theme_1.jpg` (a pastel
  /// pink-and-lavender cloudscape at dusk): primary is the warm rose
  /// pink of the sunlit cloud edges, secondary the cooler
  /// periwinkle-lavender of the shadowed cloud faces.
  static final AppThemeData bloom = AppThemeData(
    id: bloomId,
    name: 'Bloom',
    type: ThemeType.colorsAndFontWithHeaderImage,
    primaryColor: const RgbaColor(red: 214, green: 110, blue: 163),
    secondaryColor: const RgbaColor(red: 121, green: 115, blue: 177),
    surfaceColor: const RgbaColor(red: 250, green: 238, blue: 243),
    backgroundColor: const RgbaColor(red: 255, green: 247, blue: 250),
    textColor: const RgbaColor(red: 40, green: 24, blue: 32),
    isDark: false,
    fontFamily: 'Quicksand',
    headerImagePath: bloomHeaderAsset,
    isHeaderImageAsset: true,
    isBuiltIn: true,
  );

  /// Nightfall — deep indigo/violet palette with a bundled header
  /// image (Type 2). The only dark-mode built-in theme
  /// ([AppThemeData.isDark] = true). Colors resampled directly from
  /// `theme_3.jpg` (a field of violet wildflowers under a starry
  /// night sky): primary is the mid-tone periwinkle-violet of the
  /// flower petals, secondary the deep indigo of the night sky.
  /// [surfaceColor]/[backgroundColor] mirror the light themes'
  /// near-white pattern but inverted to near-black, and [textColor] is
  /// a pale lavender-white for contrast against both.
  static final AppThemeData nightfall = AppThemeData(
    id: nightfallId,
    name: 'Nightfall',
    type: ThemeType.colorsAndFontWithHeaderImage,
    primaryColor: const RgbaColor(red: 128, green: 148, blue: 220),
    secondaryColor: const RgbaColor(red: 39, green: 51, blue: 137),
    surfaceColor: const RgbaColor(red: 32, green: 33, blue: 66),
    backgroundColor: const RgbaColor(red: 20, green: 21, blue: 48),
    textColor: const RgbaColor(red: 228, green: 229, blue: 245),
    isDark: true,
    fontFamily: 'Cormorant Garamond',
    headerImagePath: nightfallHeaderAsset,
    isHeaderImageAsset: true,
    isBuiltIn: true,
  );

  static final List<AppThemeData> all = [
    bloom,
    dusk,
    meadow,
    ocean,
    sunset,

    nightfall,
  ];

  static AppThemeData get defaultTheme => bloom;
}
