// lib/core/services/review_prompt_service.dart

import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../network/network_info.dart';

/// Decides when to show the Play in-app review dialog.
///
/// Triggers on the 1st open, and every subsequent odd-numbered open
/// (1st, 3rd, 5th, 7th, etc.) if online and available.
class ReviewPromptService {
  static const _kViewCount = 'review_entry_view_count';
  static const _kLastPromptedView = 'review_last_prompted_view';

  final InAppReview _inAppReview;
  final NetworkInfo _networkInfo;

  bool _isRequesting = false;

  ReviewPromptService({
    required this._networkInfo,
    InAppReview? inAppReview,
  }) : _inAppReview = inAppReview ?? InAppReview.instance;

  /// Call each time an entry is opened.
  Future<void> onEntryOpened() async {
    if (_isRequesting) return;
    _isRequesting = true;

    try {
      final prefs = await SharedPreferences.getInstance();

      final views = (prefs.getInt(_kViewCount) ?? 0) + 1;
      await prefs.setInt(_kViewCount, views);

      // Only prompt on odd-numbered opens (1, 3, 5, 7...)
      if (views % 2 == 0) return;

      // Prevent duplicate triggers for the same view count
      final lastPromptedView = prefs.getInt(_kLastPromptedView) ?? 0;
      if (views <= lastPromptedView) return;

      // Check internet connection (Play Core requires network)
      final isOnline = await _networkInfo.isConnected;
      if (!isOnline) return;

      final available = await _inAppReview.isAvailable();
      if (!available) return;

      // Save state before requesting
      await prefs.setInt(_kLastPromptedView, views);

      await _inAppReview.requestReview();
    } catch (e, st) {
      debugPrint('[ReviewPromptService] requestReview failed: $e\n$st');
    } finally {
      _isRequesting = false;
    }
  }

  Future<void> openStoreListing() async {
    try {
      await _inAppReview.openStoreListing();
    } catch (e, st) {
      debugPrint('[ReviewPromptService] openStoreListing failed: $e\n$st');
    }
  }

  @visibleForTesting
  Future<void> resetCountersForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kViewCount);
    await prefs.remove(_kLastPromptedView);
  }
}