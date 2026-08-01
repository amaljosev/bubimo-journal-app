// lib/features/theme/presentation/widgets/custom_theme_form/font_picker_sheet.dart

import 'package:flutter/material.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/font/safe_font_service.dart';
import '../../../../../core/theme/google_fonts_catalog.dart';
import '../../../../../core/widgets/needs_internet_inline.dart';

/// Bottom sheet listing [GoogleFontsCatalog.families], each rendered in
/// its own font via [SafeFontService] so the user sees a real live
/// preview before picking — safely: opening this sheet used to build
/// every visible row's preview via `GoogleFonts.getFont` directly,
/// which meant opening it offline with several uncached families
/// visible fired several of `google_fonts`' detached network fetches
/// at once, each one an unhandled-exception risk (see
/// SafeFontService's doc comment). Routing preview rendering through
/// [SafeFontService.resolveTextStyle] instead means an uncached
/// family just renders in the system font until it's available,
/// rather than gambling on a fetch mid-scroll.
///
/// Tapping a font makes one real, awaited attempt to secure it (see
/// [SafeFontService.ensureFontAvailable]) before returning the pick —
/// if that attempt fails (offline, or a transient download error), a
/// SnackBar explains why, but the pick is still returned and applied;
/// it'll just show in a fallback font until it's actually downloaded.
///
/// Returns the picked family name via `Navigator.pop`, or `null` if
/// dismissed without a selection. Same public API as before — no
/// changes needed at the `FontPickerSheet.show(...)` call site.
class FontPickerSheet extends StatefulWidget {
  final String selectedFont;

  const FontPickerSheet({super.key, required this.selectedFont});

  static Future<String?> show(
    BuildContext context, {
    required String selectedFont,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => FontPickerSheet(selectedFont: selectedFont),
    );
  }

  @override
  State<FontPickerSheet> createState() => _FontPickerSheetState();
}

class _FontPickerSheetState extends State<FontPickerSheet> {
  /// Checked once when the sheet opens — this is a short-lived
  /// browse-and-pick sheet, not something left open long enough to
  /// warrant a live connectivity stream. Same reasoning as the
  /// rich-editor font picker's identical check.
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

  Future<void> _handleFontTap(String font) async {
    final result = await getIt<SafeFontService>().ensureFontAvailable(font);
    if (!mounted) return;

    result.match(
      (failure) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      ),
      (_) {},
    );

    if (!mounted) return;
    Navigator.of(context).pop(font);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaHeight = MediaQuery.of(context).size.height;
    final fontService = getIt<SafeFontService>();

    return SafeArea(
      top: false,
      child: SizedBox(
        height: mediaHeight * 0.7,
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Text('Choose a font', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_isOffline)
              const NeedsInternetBanner(
                message:
                    "You're offline — fonts you haven't used before won't "
                    'load until you reconnect. Already-used fonts still '
                    'work.',
              ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: GoogleFontsCatalog.families.length,
                itemBuilder: (context, index) {
                  final font = GoogleFontsCatalog.families[index];
                  final isSelected = font == widget.selectedFont;

                  final previewStyle = fontService.resolveTextStyle(
                    fontFamily: font,
                    base: const TextStyle(fontSize: 17),
                  );

                  return ListTile(
                    title: Text(font, style: previewStyle),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                          )
                        : null,
                    selected: isSelected,
                    onTap: () => _handleFontTap(font),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}