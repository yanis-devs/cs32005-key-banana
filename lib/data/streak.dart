/// Converts a yyyymmdd key (e.g. 20261111) to a UTC date.
///
/// Using UTC avoids daylight-saving shifts, so the difference between two
/// consecutive days is always exactly 24 hours.
DateTime _toDate(int dateKey) =>
    DateTime.utc(dateKey ~/ 10000, (dateKey ~/ 100) % 100, dateKey % 100);

/// Number of consecutive days played, counting back from the most recent
/// played day.
///
/// The streak is still alive if the last game was today or yesterday (the
/// player may not have played yet today). Anything older resets it to 0.
/// [dateKeys] can be in any order and may contain duplicates. [todayKey] is
/// the current date as yyyymmdd.
int computeStreak(List<int> dateKeys, int todayKey) {
  if (dateKeys.isEmpty) return 0;

  // Remove duplicate days, then sort so the most recent day comes first.
  final days = dateKeys.toSet().map(_toDate).toList()
    ..sort((a, b) => b.compareTo(a)); // newest first

  // If the latest game is more than a day old, the streak has been broken.
  final today = _toDate(todayKey);
  if (today.difference(days.first).inDays > 1) return 0;

  // Walk backwards from the latest day, counting each day that follows on
  // directly from the one before it. The first gap ends the streak.
  var streak = 1;
  for (var i = 1; i < days.length; i++) {
    if (days[i - 1].difference(days[i]).inDays == 1) {
      streak++;
    } else {
      break;
    }
  }
  return streak;
}
