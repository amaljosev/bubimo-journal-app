// lib/core/theme/app_colors.dart

import '../../features/theme/domain/entities/rgba_color.dart';

/// Centralized, curated color palettes used across the app wherever a
/// predefined/preset color list is needed.
///
/// This replaces ad-hoc, generic preset lists (previously duplicated —
/// and inconsistent — inside individual picker widgets) with a single
/// source of truth. Each palette is purpose-built for the role it
/// serves in [AppThemeData] (primary / secondary / surface /
/// background / text), so the swatches offered to the user are always
/// relevant to what they're actually picking, rather than one generic
/// "presets" grab-bag reused everywhere regardless of context.
///
/// Every role is further split into `xLight` / `xDark` variants, since
/// a single shared list mixes colors tuned for opposite ends of the
/// brightness spectrum (e.g. a light-mode background needs to sit near
/// white; a dark-mode background needs to sit near black — offering
/// both in the same picker means half the swatches are always wrong
/// for the mode the user is actually editing). Use [forRole] to fetch
/// the right list given [AppThemeData.isDark] / [CustomThemeFormState.
/// isDark], rather than reaching for `xLight`/`xDark` directly, so call
/// sites don't have to duplicate the light/dark branch themselves.
///
/// All values are [RgbaColor] (not [Color]) since that's the type the
/// theming domain layer works in — call `.toColor()` when a Flutter
/// [Color] is needed for rendering.
class AppColors {
  AppColors._();

  // ── Primary ─────────────────────────────────────────────────────
  // The app's main interactive color: buttons, FAB, active tab
  // indicator. Skews toward saturated, confident, brand-able hues;
  // avoids near-neutrals since a washed-out primary reads as a design
  // mistake rather than a deliberate choice. Dark-mode variants are
  // lifted in lightness/desaturated slightly so they don't glare
  // against a near-black background.

  static const List<RgbaColor> primaryLight = [
    RgbaColor(red: 88, green: 86, blue: 168), // Dusk violet
    RgbaColor(red: 23, green: 168, blue: 229), // Ocean blue
    RgbaColor(red: 58, green: 106, blue: 62), // Meadow green
    RgbaColor(red: 199, green: 120, blue: 0), // Sunset amber
    RgbaColor(red: 214, green: 110, blue: 163), // Bloom rose
    RgbaColor(red: 25, green: 118, blue: 210), // Classic blue
    RgbaColor(red: 123, green: 31, blue: 162), // Purple
    RgbaColor(red: 211, green: 47, blue: 47), // Red
    RgbaColor(red: 0, green: 137, blue: 123), // Teal
    RgbaColor(red: 245, green: 124, blue: 0), // Orange
    RgbaColor(red: 46, green: 125, blue: 50), // Green
    RgbaColor(red: 21, green: 101, blue: 192), // Deep sky blue
  ];

  static const List<RgbaColor> primaryDark = [
    RgbaColor(red: 128, green: 148, blue: 220), // Nightfall periwinkle
    RgbaColor(red: 144, green: 202, blue: 249), // Soft sky blue
    RgbaColor(red: 165, green: 214, blue: 167), // Soft green
    RgbaColor(red: 255, green: 183, blue: 77), // Soft amber
    RgbaColor(red: 244, green: 143, blue: 177), // Soft rose
    RgbaColor(red: 179, green: 157, blue: 219), // Soft purple
    RgbaColor(red: 239, green: 154, blue: 154), // Soft red
    RgbaColor(red: 128, green: 203, blue: 196), // Soft teal
    RgbaColor(red: 255, green: 204, blue: 128), // Soft orange
    RgbaColor(red: 174, green: 213, blue: 129), // Soft lime green
    RgbaColor(red: 158, green: 194, blue: 255), // Periwinkle blue
    RgbaColor(red: 206, green: 147, blue: 216), // Soft violet
  ];

  // ── Secondary ───────────────────────────────────────────────────
  // Accent highlights, like the colored bar on diary entries.
  // Complements primary rather than repeating it: softer/muted
  // variants and contrasting hues that read well as a supporting
  // color rather than competing with the primary.

  // Each entry is index-matched to the primaryLight entry at the same
  // position, so swatch i here is a deliberately-chosen companion for
  // primaryLight[i] (analogous where the primary is already a "theme"
  // hue like Dusk/Ocean/Meadow/Sunset/Bloom, complementary/split-
  // complementary for the generic Material-ish hues that follow).
  static const List<RgbaColor> secondaryLight = [
    RgbaColor(red: 168, green: 138, blue: 214), // Dusk lilac — w/ Dusk violet (analogous)
    RgbaColor(red: 38, green: 98, blue: 159), // Ocean deep azure — w/ Ocean blue (analogous)
    RgbaColor(red: 121, green: 134, blue: 41), // Meadow olive — w/ Meadow green (analogous)
    RgbaColor(red: 180, green: 67, blue: 108), // Sunset rose — w/ Sunset amber (split-complementary)
    RgbaColor(red: 121, green: 115, blue: 177), // Bloom lavender — w/ Bloom rose (complementary-ish)
    RgbaColor(red: 230, green: 159, blue: 0), // Golden amber — w/ Classic blue (complementary)
    RgbaColor(red: 194, green: 24, blue: 132), // Vivid magenta — w/ Purple (analogous)
    RgbaColor(red: 0, green: 121, blue: 107), // Deep teal — w/ Red (complementary)
    RgbaColor(red: 92, green: 107, blue: 192), // Indigo accent — w/ Teal (complementary-ish)
    RgbaColor(red: 57, green: 73, blue: 171), // Deep indigo blue — w/ Orange (complementary)
    RgbaColor(red: 183, green: 90, blue: 54), // Rust terracotta — w/ Green (complementary)
    RgbaColor(red: 106, green: 27, blue: 154), // Deep purple accent — w/ Deep sky blue (analogous)
  ];

  // Index-matched to primaryDark the same way secondaryLight is matched
  // to primaryLight — see the comment above secondaryLight.
  static const List<RgbaColor> secondaryDark = [
    RgbaColor(red: 179, green: 197, blue: 255), // Nightfall-adjacent periwinkle — w/ Nightfall periwinkle
    RgbaColor(red: 129, green: 212, blue: 250), // Light azure — w/ Soft sky blue
    RgbaColor(red: 220, green: 231, blue: 117), // Light olive — w/ Soft green
    RgbaColor(red: 240, green: 164, blue: 191), // Light rose — w/ Soft amber (split-complementary)
    RgbaColor(red: 181, green: 177, blue: 219), // Light lavender — w/ Soft rose
    RgbaColor(red: 128, green: 203, blue: 196), // Light teal — w/ Soft purple (complementary)
    RgbaColor(red: 162, green: 222, blue: 208), // Soft mint — w/ Soft red (complementary)
    RgbaColor(red: 255, green: 213, blue: 128), // Light amber — w/ Soft teal (complementary)
    RgbaColor(red: 159, green: 168, blue: 218), // Light indigo — w/ Soft orange (complementary)
    RgbaColor(red: 233, green: 150, blue: 122), // Soft coral — w/ Soft lime green (complementary)
    RgbaColor(red: 176, green: 190, blue: 197), // Light slate — w/ Periwinkle blue
    RgbaColor(red: 216, green: 196, blue: 140), // Soft champagne gold — w/ Soft violet (complementary)
  ];

  // ── Surface ─────────────────────────────────────────────────────
  // Cards, sheets, and app bars. Restricted to near-white/near-black
  // neutrals with subtle tints, since surfaces need to sit just
  // barely above background without introducing a jarring hue shift.

  static const List<RgbaColor> surfaceLight = [
    RgbaColor(red: 255, green: 255, blue: 255), // Pure white
    RgbaColor(red: 250, green: 250, blue: 250), // Off-white
    RgbaColor(red: 245, green: 243, blue: 250), // Dusk tint
    RgbaColor(red: 240, green: 248, blue: 236), // Meadow tint
    RgbaColor(red: 222, green: 242, blue: 253), // Ocean tint
    RgbaColor(red: 255, green: 240, blue: 234), // Sunset tint
    RgbaColor(red: 250, green: 238, blue: 243), // Bloom tint
    RgbaColor(red: 245, green: 245, blue: 248), // Neutral light grey
    RgbaColor(red: 237, green: 237, blue: 240), // Soft grey
    RgbaColor(red: 248, green: 246, blue: 240), // Warm off-white
  ];

  static const List<RgbaColor> surfaceDark = [
    RgbaColor(red: 32, green: 33, blue: 66), // Nightfall surface
    RgbaColor(red: 38, green: 38, blue: 42), // Neutral dark
    RgbaColor(red: 28, green: 27, blue: 34), // Deep charcoal violet
    RgbaColor(red: 24, green: 30, blue: 28), // Deep charcoal green
    RgbaColor(red: 30, green: 27, blue: 24), // Deep charcoal amber
    RgbaColor(red: 26, green: 32, blue: 36), // Deep charcoal teal
    RgbaColor(red: 34, green: 30, blue: 34), // Deep charcoal rose
    RgbaColor(red: 22, green: 22, blue: 26), // Near-black neutral
    RgbaColor(red: 40, green: 40, blue: 45), // Lighter charcoal
    RgbaColor(red: 18, green: 20, blue: 26), // Deep charcoal blue
  ];

  // ── Background ──────────────────────────────────────────────────
  // The main page background behind everything. Similar intent to
  // surface but even closer to the extremes (near-white for light
  // themes, near-black for dark) since background should recede the
  // most of any color role.

  static const List<RgbaColor> backgroundLight = [
    RgbaColor(red: 255, green: 255, blue: 255), // Pure white
    RgbaColor(red: 253, green: 252, blue: 255), // Dusk background
    RgbaColor(red: 247, green: 253, blue: 242), // Meadow background
    RgbaColor(red: 235, green: 248, blue: 255), // Ocean background
    RgbaColor(red: 255, green: 248, blue: 246), // Sunset background
    RgbaColor(red: 255, green: 247, blue: 250), // Bloom background
    RgbaColor(red: 250, green: 250, blue: 250), // Neutral off-white
    RgbaColor(red: 252, green: 251, blue: 248), // Warm white
    RgbaColor(red: 248, green: 250, blue: 253), // Cool white
    RgbaColor(red: 245, green: 245, blue: 245), // Soft grey-white
  ];

  static const List<RgbaColor> backgroundDark = [
    RgbaColor(red: 20, green: 21, blue: 48), // Nightfall background
    RgbaColor(red: 18, green: 18, blue: 20), // Neutral near-black
    RgbaColor(red: 15, green: 17, blue: 15), // Deep near-black green
    RgbaColor(red: 17, green: 15, blue: 20), // Deep near-black violet
    RgbaColor(red: 12, green: 12, blue: 12), // True near-black
    RgbaColor(red: 16, green: 13, blue: 12), // Deep near-black amber
    RgbaColor(red: 12, green: 16, blue: 18), // Deep near-black teal
    RgbaColor(red: 19, green: 14, blue: 17), // Deep near-black rose
    RgbaColor(red: 10, green: 10, blue: 14), // Cool near-black
    RgbaColor(red: 14, green: 14, blue: 12), // Warm near-black
  ];

  // ── Text ────────────────────────────────────────────────────────
  // Titles, body text, and icons. [TextColorSwatchPickerSheet] filters
  // whichever list below by contrast ratio against the current
  // background/surface at picker time, so the curation goal here is
  // "plausible for this mode," not "guaranteed to pass" — light-mode
  // text skews dark, dark-mode text skews light, each with enough
  // spread across neutrals and hues to survive filtering.

  static const List<RgbaColor> textLight = [
    // Neutrals — near-black through mid-grey.
    RgbaColor(red: 10, green: 10, blue: 12),
    RgbaColor(red: 24, green: 24, blue: 27),
    RgbaColor(red: 38, green: 38, blue: 42),
    RgbaColor(red: 55, green: 55, blue: 60),
    RgbaColor(red: 90, green: 90, blue: 96),
    // Warm neutrals.
    RgbaColor(red: 32, green: 28, blue: 44),
    RgbaColor(red: 43, green: 24, blue: 20),
    RgbaColor(red: 40, green: 24, blue: 32),
    // Deep/dark hues — readable on light backgrounds.
    RgbaColor(red: 20, green: 40, blue: 90),
    RgbaColor(red: 80, green: 20, blue: 30),
    RgbaColor(red: 20, green: 70, blue: 45),
    RgbaColor(red: 90, green: 50, blue: 10),
    RgbaColor(red: 70, green: 20, blue: 80),
    RgbaColor(red: 10, green: 60, blue: 70),
  ];

  static const List<RgbaColor> textDark = [
    // Neutrals — near-white through mid-grey.
    RgbaColor(red: 255, green: 255, blue: 255),
    RgbaColor(red: 245, green: 245, blue: 248),
    RgbaColor(red: 225, green: 225, blue: 230),
    RgbaColor(red: 180, green: 180, blue: 186),
    RgbaColor(red: 130, green: 130, blue: 136),
    // Warm near-white.
    RgbaColor(red: 228, green: 229, blue: 245),
    // Light/pastel hues — readable on dark backgrounds.
    RgbaColor(red: 200, green: 220, blue: 255),
    RgbaColor(red: 255, green: 205, blue: 210),
    RgbaColor(red: 205, green: 245, blue: 220),
    RgbaColor(red: 255, green: 225, blue: 180),
    RgbaColor(red: 235, green: 205, blue: 255),
    RgbaColor(red: 190, green: 240, blue: 245),
  ];

  /// Returns the correct light/dark palette for [role], given whether
  /// the theme being edited is dark mode. Prefer this over reaching
  /// for `xLight`/`xDark` fields directly so call sites (e.g.
  /// `custom_theme_screen.dart`) don't each have to re-implement the
  /// same `isDark ? … : …` branch per field.
  static List<RgbaColor> forRole(AppColorRole role, {required bool isDark}) {
    switch (role) {
      case AppColorRole.primary:
        return isDark ? primaryDark : primaryLight;
      case AppColorRole.secondary:
        return isDark ? secondaryDark : secondaryLight;
      case AppColorRole.surface:
        return isDark ? surfaceDark : surfaceLight;
      case AppColorRole.background:
        return isDark ? backgroundDark : backgroundLight;
      case AppColorRole.text:
        return isDark ? textDark : textLight;
    }
  }
}

/// The five color roles in [AppThemeData], used with [AppColors.forRole]
/// to fetch the correct light/dark palette for a given field.
enum AppColorRole { primary, secondary, surface, background, text }