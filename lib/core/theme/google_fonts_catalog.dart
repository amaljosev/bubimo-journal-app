// lib/core/theme/google_fonts_catalog.dart

/// Every family here must exist on Google Fonts under this exact
/// name (case/spacing sensitive) — `google_fonts` resolves purely by
/// string match.
///
/// Ordering is intentionally interleaved rather than grouped by
/// category. The old layout listed ~20 sans-serifs back to back, then
/// ~12 serifs, then scripts, etc. — so a user scrolling the picker
/// saw long stretches that all looked/felt similar before hitting
/// something visually different. Google Fonts doesn't have real
/// "italic" or "bold" *families* (those are weights/styles most
/// families already support via [FontWeight]/[FontStyle] on the same
/// family name) — so instead of grouping by weight, this list rotates
/// through style *categories* (sans, script, serif, display, mono,
/// rounded, slab/black letter-ish, condensed) in short runs, repeating
/// a category only after several others have appeared. Keeps the
/// scroll visually varied without implying weight variants that
/// aren't actually separate entries.
///
/// Category tags in comments are for maintainers only — the picker
/// UI reads this as one flat list (see FontPicker / FontPickerSheet).
class GoogleFontsCatalog {
  GoogleFontsCatalog._();

  static const List<String> families = [
    // sans
    'Poppins',
    // script
    'Satisfy',
    // sans
    'Roboto',
    // serif
    'Merriweather',
    // display
    'Righteous',
    // script
    'Cookie',
    // sans
    'Inter',
    // mono
    'JetBrains Mono',
    // display
    'Bangers',
    // serif
    'Lora',
    // rounded
    'Comfortaa',
    // script
    'Courgette',
    // sans
    'Nunito',
    // display
    'Permanent Marker',
    // serif
    'Playfair Display',
    // script
    'Pacifico',
    // sans
    'Quicksand',
    // mono
    'Roboto Mono',
    // script
    'Rock Salt',
    // sans
    'Montserrat',
    // rounded
    'Mali',
    // serif
    'PT Serif',
    // display
    'Baloo 2',
    // script
    'Dancing Script',
    // sans
    'Lato',
    // condensed
    'Oswald',
    // serif
    'Bitter',
    // display
    'Fredoka',
    // script
    'Sacramento',
    // sans
    'Open Sans',
    // mono
    'Space Mono',
    // serif
    'Cormorant Garamond',
    // display
    'Bungee',
    // script
    'Kalam',
    // sans
    'Mulish',
    // rounded
    'Varela Round',
    // serif
    'Libre Baskerville',
    // display
    'Alfa Slab One',
    // script
    'Shadows Into Light',
    // sans
    'Rubik',
    // condensed
    'Barlow Condensed',
    // serif
    'Crimson Pro',
    // display
    'Abril Fatface',
    // script
    'Great Vibes',
    // sans
    'Karla',
    // mono
    'IBM Plex Mono',
    // serif
    'Crimson Text',
    // display
    'Comic Neue',
    // script
    'Indie Flower',
    // sans
    'Work Sans',
    // rounded
    'Baloo Bhai 2',
    // serif
    'EB Garamond',
    // display
    'Lobster',
    // script
    'Patrick Hand',
    // sans
    'Manrope',
    // condensed
    'Fjalla One',
    // serif
    'Source Serif 4',
    // script
    'Homemade Apple',
    // sans
    'Josefin Sans',
    // mono
    'Source Code Pro',
    // serif
    'Spectral',
    // script
    'Reenie Beanie',
    // sans
    'Raleway',
    // display
    'Passion One',
    // script
    'Amatic SC',
    // sans
    'Sora',
    // script
    'Caveat',
    // sans
    'DM Sans',
    // script
    'Caveat Brush',
    // sans
    'Outfit',
    // condensed
    'Archivo Narrow',
    // sans
    'Urbanist',
    // display
    'Chewy',
    // sans
    'Plus Jakarta Sans',
    // display
    'Titan One',
    // sans
    'Figtree',
  ];
}