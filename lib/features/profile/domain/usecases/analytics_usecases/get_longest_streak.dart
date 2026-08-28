// lib/features/profile/domain/usecases/analytics_usecases/get_longest_streak.dart

import 'package:fpdart/fpdart.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../diary_entry/domain/usecases/get_all_diary_entries.dart';
import 'activity_day_utils.dart';

/// Pure calculation, split out so [GetAnalyticsSnapshot] can reuse it
/// against an activity-day set it already built, without forcing a
/// second `getAllDiaryEntries()` fetch.
///
/// Computes the longest streak ever achieved: the longest run of
/// consecutive calendar days with at least one entry DATED that day
/// (see [buildActivityDaySet]), anywhere in the user's history (not
/// just ending today).
int calculateLongestStreak(Set<DateTime> activityDays) {
  if (activityDays.isEmpty) return 0;

  final sortedDays = activityDays.toList()..sort();

  var longest = 1;
  var current = 1;

  for (var i = 1; i < sortedDays.length; i++) {
    final previous = sortedDays[i - 1];
    final day = sortedDays[i];

    if (AppDateUtils.isDayBefore(previous, day)) {
      current++;
      if (current > longest) longest = current;
    } else {
      current = 1;
    }
  }

  return longest;
}

/// Usage: `await getLongestStreak()`.
///
/// Kept as a standalone use case (in addition to
/// [GetAnalyticsSnapshot]) for call sites or tests that want just this
/// one metric without depending on the combined snapshot.
class GetLongestStreak {
  final GetAllDiaryEntries getAllDiaryEntries;

  const GetLongestStreak(this.getAllDiaryEntries);

  Future<Either<Failure, int>> call() async {
    final result = await getAllDiaryEntries();
    return result.map(
      (entries) => calculateLongestStreak(buildActivityDaySet(entries)),
    );
  }
}