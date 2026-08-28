// lib/features/profile/domain/usecases/analytics_usecases/activity_day_utils.dart

import '../../../../../core/utils/date_utils.dart';
import '../../../../diary_entry/domain/entities/diary_entry.dart';

/// Single source of truth for the "activity day" definition shared by
/// streaks and the heatmap: a calendar day for which the user has at
/// least one diary entry DATED that day — [DiaryEntry.date], the diary
/// date the user picked (and can freely backdate), NOT
/// `createdAt`/`updatedAt` (when the entry was actually typed/edited in
/// real time).
///
/// This is the standard journaling-app definition of a streak day —
/// e.g. Day One ("restore your streak by creating new entries on any
/// days you missed") and Rosebud ("adjust your entry dates to maintain
/// your streak") both work this way. Writing or editing an entry dated
/// for a day you missed retroactively fills that day in, which is
/// exactly what lets `calculateCurrentStreak` show a repaired, unbroken
/// streak once the gap is backfilled — no separate "repair" step is
/// needed, since the streak is just a live read of which days now have
/// an entry.
///
/// Previously duplicated verbatim inside [GetCurrentStreak],
/// [GetLongestStreak], and [GetHeatmapData] — consolidated here so the
/// activity definition can only ever be changed in one place.
Set<DateTime> buildActivityDaySet(List<DiaryEntry> entries) {
  final days = <DateTime>{};
  for (final entry in entries) {
    days.add(AppDateUtils.dateOnly(entry.date));
  }
  return days;
}