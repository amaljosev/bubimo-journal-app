// lib/features/plus/domain/entities/plus_feature.dart

/// Every feature that sits behind Bubimo Plus.
///
/// Passed to the paywall (see `PlusGate.require`) so it can open with
/// a line about the exact feature the user just tapped, and used by
/// the benefits list so the paywall and the gates never drift apart —
/// adding a feature here adds it to both.
enum PlusFeature {
  customThemes(
    'Custom themes',
    'Create your own colors, font and header image.',
  ),
  cloudBackup(
    'Cloud backup',
    'Back up your diary to Google Drive.',
  ),
  localBackup(
    'Local backup',
    'Save a full backup file to your device.',
  ),
  pdfExport(
    'PDF export',
    'Turn your diary into a neatly laid-out PDF.',
  ),
  removeAds(
    'Ad-free diary',
    'Switch ads off for a distraction-free diary.',
  );

  final String title;
  final String pitch;

  const PlusFeature(this.title, this.pitch);
}
