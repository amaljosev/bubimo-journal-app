// lib/features/profile/domain/usecases/analytics_usecases/get_analytics_snapshot.dart

import 'package:equatable/equatable.dart';
import 'package:fpdart/fpdart.dart';

import '../../../../../core/error/failures.dart';
import '../../../../diary_entry/domain/entities/mood.dart';
import '../../../../diary_entry/domain/usecases/get_all_diary_entries.dart';
import 'activity_day_utils.dart';
import 'get_current_streak.dart';
import 'get_entry_stats.dart';
import 'get_heatmap_data.dart';
import 'get_longest_streak.dart';
import 'get_mood_counts.dart';
import 'get_word_count_trend.dart';

/// Every metric the Analytics screen needs, computed from a single
/// `getAllDiaryEntries()` fetch.
class AnalyticsSnapshot extends Equatable {
  final Map<Mood, int> moodCounts;
  final int currentStreak;
  final int longestStreak;
  final List<HeatmapDay> heatmapData;
  final EntryStats entryStats;
  final List<WordCountDay> wordCountTrend;

  const AnalyticsSnapshot({
    required this.moodCounts,
    required this.currentStreak,
    required this.longestStreak,
    required this.heatmapData,
    required this.entryStats,
    required this.wordCountTrend,
  });

  @override
  List<Object?> get props => [
        moodCounts,
        currentStreak,
        longestStreak,
        heatmapData,
        entryStats,
        wordCountTrend,
      ];
}

/// Loads every analytics metric from a SINGLE `getAllDiaryEntries()`
/// call and a single activity-day-set build, instead of the previous
/// pattern of 5 independent use cases each re-fetching every entry and
/// re-deriving the same activity-day set from scratch.
///
/// On a local SQLite database with a modest entry count neither pattern
/// is user-visibly slow, but re-fetching the same unfiltered table 5
/// times per screen load is pure waste that only grows with entry
/// count, and the 3-way duplicated activity-day logic was a
/// maintenance hazard (any future change to "what counts as activity"
/// had to be made correctly in 3 places by hand). This is the same
/// data, computed once.
///
/// The individual `Get*` use cases (e.g. [GetCurrentStreak]) are kept
/// as thin standalone wrappers around the same pure calculation
/// functions — for tests or any future call site that only needs one
/// metric — but [AnalyticsBloc] should use this snapshot use case.
///
/// Usage: `await getAnalyticsSnapshot()`.
class GetAnalyticsSnapshot {
  final GetAllDiaryEntries getAllDiaryEntries;

  const GetAnalyticsSnapshot(this.getAllDiaryEntries);

  Future<Either<Failure, AnalyticsSnapshot>> call() async {
    final result = await getAllDiaryEntries();

    return result.map((entries) {
      final activityDays = buildActivityDaySet(entries);

      return AnalyticsSnapshot(
        moodCounts: calculateMoodCounts(entries),
        currentStreak: calculateCurrentStreak(activityDays),
        longestStreak: calculateLongestStreak(activityDays),
        // Heatmap and both streaks now share the same underlying
        // definition — see buildActivityDaySet's and
        // calculateHeatmapData's doc comments — both keyed off
        // DiaryEntry.date, not createdAt/updatedAt.
        heatmapData: calculateHeatmapData(entries),
        entryStats: calculateEntryStats(entries),
        wordCountTrend: calculateWordCountTrend(entries),
      );
    });
  }
}