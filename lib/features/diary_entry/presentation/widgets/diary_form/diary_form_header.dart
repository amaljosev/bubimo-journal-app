// lib/features/diary_entry/presentation/widgets/diary_form/diary_form_header.dart

import 'package:flutter/material.dart';

import '../../../../../core/di/injection.dart';
import '../../../../../core/theme/font/safe_font_service.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../domain/entities/mood.dart';

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

class DiaryFormTitleField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final FocusNode nextFocusNode;
  final ValueChanged<String> onChanged;
  final TextAlign textAlign;
  final bool isBold;
  final bool isItalic;
  final bool isUnderlined;
  final double? fontSize;
  final Color? textColor;
  final String? fontFamily;

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
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseStyle = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w800,
      color: theme.colorScheme.onSurface,
    );

    final family = fontFamily;
    final familyStyle = (family == null || baseStyle == null)
        ? baseStyle
        : getIt<SafeFontService>().resolveTextStyle(
            fontFamily: family,
            base: baseStyle,
          );

    return TextField(
      maxLength: 50,
      maxLines: 2,
      controller: controller,
      focusNode: focusNode,
      textAlign: textAlign,
      textInputAction: TextInputAction.next,
      onTapOutside: (_) => focusNode.unfocus(),
      onSubmitted: (_) => nextFocusNode.requestFocus(),
      cursorColor: theme.colorScheme.primary,
      style: familyStyle?.copyWith(
        fontWeight: isBold ? FontWeight.w900 : FontWeight.w800,
        fontStyle: isItalic ? FontStyle.italic : FontStyle.normal,
        decoration:
            isUnderlined ? TextDecoration.underline : TextDecoration.none,
        fontSize: fontSize ?? familyStyle.fontSize,
        color: textColor ?? familyStyle.color,
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