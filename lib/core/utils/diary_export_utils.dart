// lib/core/utils/diary_export_utils.dart

import 'dart:convert';

import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Helpers shared by the human-readable diary exports (PDF and TXT), so
/// both formats agree on what an entry's title, body text, date and
/// file name look like instead of each keeping its own copy.
class DiaryExportUtils {
  DiaryExportUtils._();

  static const List<String> _monthNames = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Parses Quill Delta JSON into plain text — mirrors
  /// `DiaryFormBloc._extractPlainText`'s exact fallback behavior (if
  /// [content] isn't valid Delta JSON, e.g. a legacy plain-text entry
  /// from before the rich editor existed, the raw string is returned
  /// unchanged) so every place agrees on what "the entry's body text"
  /// means.
  static String extractPlainText(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) return '';

    try {
      final decoded = jsonDecode(trimmed);
      final doc = quill.Document.fromJson(decoded as List);
      return doc.toPlainText().trim();
    } catch (_) {
      return trimmed;
    }
  }

  /// The entry's title, or "Untitled" when it's missing/blank.
  static String displayTitle(String? title) {
    final trimmed = title?.trim();
    return (trimmed == null || trimmed.isEmpty) ? 'Untitled' : trimmed;
  }

  /// Formats a date as e.g. "Jan 5, 2025" without pulling in `intl` —
  /// matches this project's convention of avoiding that dependency.
  static String formatDate(DateTime date) {
    return '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';
  }

  /// `yyyyMMdd_HHmm` — used in exported file names.
  static String fileTimestamp([DateTime? now]) {
    final value = now ?? DateTime.now();
    return '${value.year}${_twoDigits(value.month)}${_twoDigits(value.day)}'
        '_${_twoDigits(value.hour)}${_twoDigits(value.minute)}';
  }

  static String _twoDigits(int value) => value.toString().padLeft(2, '0');
}