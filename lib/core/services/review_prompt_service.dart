import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Decides when to show the Play in-app review dialog.
///
/// The API can't report whether the user rated, so we track our own
/// attempts: at most one prompt per calendar day, [maxPrompts] total.
class ReviewPromptService {
  /// Entry opens required before the first prompt, so brand-new users
  /// aren't asked before they've actually used the app.
  static const int minViewsBeforeFirstPrompt = 3;

  /// Give up after this many attempts.
  static const int maxPrompts = 3;

  static const _kViewCount = 'review_entry_view_count';
  static const _kPromptCount = 'review_prompt_count';
  static const _kLastPromptDay = 'review_last_prompt_day';

  final InAppReview _inAppReview;

  ReviewPromptService([InAppReview? inAppReview])
    : _inAppReview = inAppReview ?? InAppReview.instance;

  /// Call each time the entry preview screen is opened.
  Future<void> onEntryOpened() async {
    final prefs = await SharedPreferences.getInstance();

    final views = (prefs.getInt(_kViewCount) ?? 0) + 1;
    await prefs.setInt(_kViewCount, views);
    if (views < minViewsBeforeFirstPrompt) return;

    final promptCount = prefs.getInt(_kPromptCount) ?? 0;
    if (promptCount >= maxPrompts) return;

    // Already asked today -> wait for another day.
    final today = _dayKey(DateTime.now());
    if (prefs.getString(_kLastPromptDay) == today) return;

    if (!await _inAppReview.isAvailable()) return;

    // Record before requesting so a rapid re-open can't double-fire.
    await prefs.setString(_kLastPromptDay, today);
    await prefs.setInt(_kPromptCount, promptCount + 1);

    await _inAppReview.requestReview();
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}