// lib/features/profile/domain/usecases/analytics_usecases/get_heatmap_data.dart

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../diary_entry/domain/entities/diary_entry.dart';
import '../../../../diary_entry/domain/usecases/get_all_diary_entries.dart';

/// A single cell in the GitHub-style heatmap grid.
///
/// Keyed by [entryCount] (not a plain bool) because more than one entry
/// can legitimately land on the same calendar day — most commonly when
/// a user backdates an entry to a date that already has one, but
/// nothing prevents multiple same-day entries in general. [hasEntry] is
/// a convenience getter for callers that only care about presence, not
/// count (e.g. the cell fill color).
class HeatmapDay extends Equatable {
  final DateTime date;
  final int entryCount;

  const HeatmapDay({required this.date, required this.entryCount});

  bool get hasEntry => entryCount > 0;

  @override
  List<Object?> get props => [date, entryCount];
}

/// Pure calculation, split out so [GetAnalyticsSnapshot] can reuse it
/// against entries it already fetched, without forcing a second
/// `getAllDiaryEntries()` call.
///
/// Builds a 365-day grid (oldest first, today last) with the number of
/// entries whose [DiaryEntry.date] falls on each calendar day.
///
/// IMPORTANT — this is keyed by [DiaryEntry.date] (the diary date the
/// user picked/backdated to), NOT by `createdAt`/`updatedAt`. This is a
/// deliberate design choice: it shares the exact same source of truth
/// as the Timeline screen, so entry counts are consistent between the
/// two, and backdating or editing an entry for a previous date
/// correctly updates that earlier day's cell — not today's.
///
/// The current/longest streak calculations (`calculateCurrentStreak`/
/// `calculateLongestStreak`, via [buildActivityDaySet]) now use this
/// same `DiaryEntry.date`-based definition — so the heatmap and streaks
/// deliberately agree with each other, matching how journaling apps
/// like Day One and Rosebud let a backdated entry both fill in the
/// heatmap cell for that day AND repair a broken streak through it.
List<HeatmapDay> calculateHeatmapData(List<DiaryEntry> entries) {
  final countsByDay = <DateTime, int>{};
  for (final entry in entries) {
    final day = AppDateUtils.dateOnly(entry.date);
    countsByDay[day] = (countsByDay[day] ?? 0) + 1;
  }

  final last365Days = AppDateUtils.lastNDays(365);

  return last365Days
      .map(
        (day) => HeatmapDay(
          date: day,
          entryCount: countsByDay[day] ?? 0,
        ),
      )
      .toList();
}

/// Usage: `await getHeatmapData()`.
///
/// Kept as a standalone use case (in addition to
/// [GetAnalyticsSnapshot]) for call sites or tests that want just this
/// one metric without depending on the combined snapshot.
class GetHeatmapData {
  final GetAllDiaryEntries getAllDiaryEntries;

  const GetHeatmapData(this.getAllDiaryEntries);

  Future<Either<Failure, List<HeatmapDay>>> call() async {
    final result = await getAllDiaryEntries();
    return result.map(calculateHeatmapData);
  }
}