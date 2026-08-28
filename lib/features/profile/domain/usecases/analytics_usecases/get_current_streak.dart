// lib/features/profile/domain/usecases/analytics_usecases/get_current_streak.dart

import 'package:fpdart/fpdart.dart';

import '../../../../../core/error/failures.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../diary_entry/domain/usecases/get_all_diary_entries.dart';
import 'activity_day_utils.dart';

/// Pure calculation, split out so [GetAnalyticsSnapshot] can reuse it
/// against an activity-day set it already built, without forcing a
/// second `getAllDiaryEntries()` fetch.
///
/// Computes the current streak: the number of consecutive calendar days
/// with at least one entry DATED that day (see [buildActivityDaySet]),
/// ending today if today already has an entry, or ending yesterday if
/// today doesn't have one YET (today isn't over — that's not a missed
/// day).
///
/// Since activity days come from [DiaryEntry.date] rather than
/// `createdAt`/`updatedAt`, writing or backdating an entry for a
/// previously-missed day fills that day back in — if it reconnects the
/// run up to today/yesterday, the streak is naturally repaired with no
/// special-case logic here.
int calculateCurrentStreak(Set<DateTime> activityDays) {
  if (activityDays.isEmpty) return 0;

  final today = AppDateUtils.dateOnly(DateTime.now());
  var cursor = today;

  if (!activityDays.contains(cursor)) {
    // No activity yet today. On its own this does NOT mean the streak
    // is broken — today simply hasn't ended, and the user may still
    // write later today. The streak is only actually broken once a
    // full calendar day has passed with zero activity, i.e. yesterday
    // is ALSO empty. If yesterday has activity, the streak is still
    // alive as of right now; count it starting from yesterday instead
    // (today just doesn't add to the count until the user does
    // something today).
    final yesterday = cursor.subtract(const Duration(days: 1));
    if (!activityDays.contains(yesterday)) return 0;
    cursor = yesterday;
  }

  var streak = 0;
  while (activityDays.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return streak;
}

/// Usage: `await getCurrentStreak()`.
///
/// Kept as a standalone use case (in addition to
/// [GetAnalyticsSnapshot]) for call sites or tests that want just this
/// one metric without depending on the combined snapshot.
class GetCurrentStreak {
  final GetAllDiaryEntries getAllDiaryEntries;

  const GetCurrentStreak(this.getAllDiaryEntries);

  Future<Either<Failure, int>> call() async {
    final result = await getAllDiaryEntries();
    return result.map(
      (entries) => calculateCurrentStreak(buildActivityDaySet(entries)),
    );
  }
}