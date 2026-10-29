// lib/features/help/data/faq_data.dart

import 'package:bubimo/features/help/domain/faq_item.dart';

/// Static FAQ content for the Help screen.
///
/// This is intentionally a plain hardcoded list (per project decision) —
/// no Bloc, no remote fetch. To add/edit an FAQ, just add/edit an entry
/// below; the UI groups everything by [FaqCategory] automatically.
class FaqData {
  FaqData._();

  static const List<FaqItem> all = [
    // ---- Diary & Entries ----
    FaqItem(
      category: FaqCategory.diary,
      question: 'How do I create a new diary entry?',
      answer:
          'Tap the "+" button on the home screen to start a new entry. '
          'You can add text, a mood, images, and stickers before saving. '
          'Entries are grouped by date automatically on your timeline.',
    ),
    FaqItem(
      category: FaqCategory.diary,
      question: 'How do I mark an entry as a favorite?',
      answer:
          'Open any entry and tap the heart icon'
    ),
    FaqItem(
      category: FaqCategory.diary,
      question: 'What is the Timeline view?',
      answer:
          'Timeline shows all your entries in chronological order, with '
          'entries from the same day grouped under a single date. It\'s '
          'a quick way to scroll back through your journaling history.',
    ),

    // ---- Themes & Customization ----
    FaqItem(
      category: FaqCategory.themes,
      question: 'Can I change the app\'s theme?',
      answer:
          'Yes. Go to Themes to choose from built-in themes '
          '(Dusk, Meadow, Ocean, Sunset, Bloom) or create your own '
          'custom theme.',
    ),
    FaqItem(
      category: FaqCategory.themes,
      question: 'How do I create a custom theme?',
      answer:
          'In Themes, tap "Create Custom Theme." You can set '
          'your own Primary, Background, Secondary, Surface, and Text '
          'colors, preview them live, and switch between Light and Dark '
          'mode. Text color contrast is checked automatically so your '
          'entries stay readable.',
    ),

    // ---- Stickers, Images & Media ----
    FaqItem(
      category: FaqCategory.stickersAndMedia,
      question: 'Why aren\'t my stickers or backgrounds loading?',
      answer:
          'Stickers and background images are downloaded from our '
          'server, so they need an active internet connection the '
          'first time you use them. Once loaded, they\'re cached for '
          'offline use. If they still don\'t appear, check your '
          'connection and try again.',
    ),
    FaqItem(
      category: FaqCategory.stickersAndMedia,
      question: 'How do I add a  profile image?',
      answer:
          'Go to  Profile to set a profile image, or open an '
          'entry\'s customization options to add a header image to '
          'that specific entry.',
    ),

    // ---- Privacy & App Lock ----
    FaqItem(
      category: FaqCategory.privacyAndLock,
      question: 'Is my diary private?',
      answer:
          'Yes. Your entries are stored securely, and you can add an '
          'extra layer of protection with App Lock so only you can '
          'open the app.',
    ),
    FaqItem(
      category: FaqCategory.privacyAndLock,
      question: 'How do I set up App Lock?',
      answer:
          'Go to Settings > App Lock and choose a lock method: '
          'biometric (fingerprint/face), PIN, or your device\'s '
          'default screen lock. Only one method can be active at a '
          'time. You\'ll also set a security question in case you '
          'forget your PIN or pattern.',
    ),
    // FaqItem(
    //   category: FaqCategory.privacyAndLock,
    //   question: 'I forgot my PIN — what do I do?',
    //   answer:
    //       'On the unlock screen, tap "Forgot PIN" '
    //       'and answer your security question to regain access and set '
    //       'a new one.',
    // ),
    FaqItem(
      category: FaqCategory.privacyAndLock,
      question: 'How do I switch from one lock method to another?',
      answer:
          'Go to Settings > App Lock and select the new method. '
          'You\'ll be asked to verify your current PIN or '
          'biometric first before the new method can be set up, to '
          'keep your diary secure during the switch.',
    ),

    // ---- Reminders ----
    FaqItem(
      category: FaqCategory.reminders,
      question: 'How do I set a reminder to write in my diary?',
      answer:
          'Go to Settings > Reminders and turn on daily reminders. '
          'You\'ll need to allow notification and alarm permissions '
          'when prompted so reminders can arrive on time.',
    ),
    FaqItem(
      category: FaqCategory.reminders,
      question: 'My reminders aren\'t showing up — why?',
      answer:
          'This is usually a permissions issue. Open Settings > '
          'Reminders and check the status banner — it will tell you if '
          'a notification or exact-alarm permission is missing, and '
          'let you jump straight to your device\'s app settings to '
          'enable it.',
    ),

    // ---- Backup, Import & Export ----
    FaqItem(
      category: FaqCategory.backupAndData,
      question: 'How do I back up my diary?',
      answer:
          'Go to Settings > Backup to enable cloud backup, or use '
          'Export to save a local copy of your entries. Cloud backup '
          'keeps your diary safe even if you lose your device.',
    ),
    FaqItem(
      category: FaqCategory.backupAndData,
      question: 'How do I restore or import my entries?',
      answer:
          'Go to Settings > Backup and choose Import, then select your '
          'exported file or restore from your cloud backup.',
    ),

    // ---- General ----
    FaqItem(
      category: FaqCategory.general,
      question: 'Does bubimo work without an internet connection?',
      answer:
          'Yes, writing and viewing entries works fully offline. Only '
          'sticker/background downloads and cloud backup require '
          'internet access.',
    ),
  ];

  /// Returns all FAQ items grouped by category, preserving the
  /// declaration order of [FaqCategory] and the order items appear
  /// within [all].
  static Map<FaqCategory, List<FaqItem>> get groupedByCategory {
    final Map<FaqCategory, List<FaqItem>> grouped = {
      for (final category in FaqCategory.values) category: <FaqItem>[],
    };
    for (final item in all) {
      grouped[item.category]!.add(item);
    }
    // Drop categories with no entries so the UI doesn't render empty sections.
    grouped.removeWhere((_, items) => items.isEmpty);
    return grouped;
  }
}