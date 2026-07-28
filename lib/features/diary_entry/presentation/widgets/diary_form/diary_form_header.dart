// lib/features/diary_entry/presentation/widgets/diary_form/diary_form_header.dart

import 'package:flutter/material.dart';

import '../../../../../core/utils/date_utils.dart';
import '../../../domain/entities/mood.dart';

/// Date on the left (big day-number + weekday + month layout) and the
/// mood avatar on the right, which opens the mood popover speech-bubble
/// anchored to itself.
///
/// Extracted from `_DiaryFormViewState._buildHeaderRow` to keep the
/// form page's state class focused on orchestration rather than
/// widget-building.
class DiaryFormHeaderRow extends StatelessWidget {
  final DateTime date;
  final Mood? mood;
  final GlobalKey moodAvatarKey;
  final VoidCallback onDateTap;
  final VoidCallback onMoodTap;

  const DiaryFormHeaderRow({
    super.key,
    required this.date,
    required this.mood,
    required this.moodAvatarKey,
    required this.onDateTap,
    required this.onMoodTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onDateTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppDateUtils.formatDD(date),
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Row(
                  children: [
                    Text(
                      AppDateUtils.formatEE(date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      AppDateUtils.formatMMMYyyy(date),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary
                            .withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          key: moodAvatarKey,
          onTap: onMoodTap,
          child: CircleAvatar(
            radius: 26,
            backgroundColor:
                theme.colorScheme.primary.withValues(alpha: 0.12),
            child: mood != null
                ? Text(
                    mood!.emoji,
                    style: const TextStyle(fontSize: 26),
                  )
                : Icon(
                    Icons.sentiment_satisfied_alt_outlined,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Minimal title field: no border, no fill, no visible container of
/// any kind — just the text itself with a soft hint, matching the
/// unboxed, journal-page feel of the description area below it.
///
/// Extracted from `_DiaryFormViewState._buildTitleField`.
class DiaryFormTitleField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode nextFocusNode;
  final ValueChanged<String> onChanged;

  /// Mirrors the Quill description's current alignment (see
  /// `DiaryFormState.alignment`, set from the bottom toolbar's T
  /// panel) — the title is plain text and can't carry a Quill
  /// attribute of its own, so this is how the same "whole entry"
  /// alignment choice reaches it. Defaults to `TextAlign.start` to
  /// match the field's previous unconfigured behavior when the caller
  /// doesn't pass one.
  final TextAlign textAlign;

  /// Mirrors the T panel's Bold/Italic/Underline toggles and the
  /// "Text color" panel's pick — same whole-entry rationale as
  /// [textAlign]. All default to the field's previous unconfigured
  /// look (regular weight, no italic/underline, theme's default
  /// color) so passing none of them changes nothing.
  final bool isBold;
  final bool isItalic;
  final bool isUnderlined;
  final double? fontSize;
  final Color? textColor;

  const DiaryFormTitleField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.nextFocusNode,
    required this.onChanged,
    this.textAlign = TextAlign.start,
    this.isBold = false,
    this.isItalic = false,
    this.isUnderlined = false,
    this.fontSize,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurface,
    );

    return TextField(
      controller: controller,
      focusNode: focusNode,
      maxLines: null,
      textAlign: textAlign,
      textInputAction: TextInputAction.next,
      onTapOutside: (_) => focusNode.unfocus(),
      onSubmitted: (_) => nextFocusNode.requestFocus(),
      cursorColor: theme.colorScheme.primary,
      // `isBold`/`isItalic`/`isUnderlined` override the base w800
      // weight/style rather than compounding with it — Bold here means
      // "at least as bold as the title already was", so toggling it
      // off falls back to the title's own w800 default rather than a
      // plain w400, keeping the title from ever looking lighter than
      // its normal look.
      style: baseStyle?.copyWith(
        fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration:
            isUnderlined ? TextDecoration.underline : TextDecoration.none,
        fontSize: fontSize ?? baseStyle.fontSize,
        color: textColor ?? baseStyle.color,
      ),
      decoration: InputDecoration(
        hintText: 'Title',
        hintStyle: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        filled: false,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        isDense: true,
        isCollapsed: true,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: onChanged,
    );
  }
}