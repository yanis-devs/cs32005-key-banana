/// Three-letter month names, indexed by month number minus 1.
const List<String> _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// Formats a yyyymmdd date key for display: 20261114 becomes "14 Nov 2026".
/// An unreadable key is returned as plain digits rather than throwing.
///
/// Only the ranges are checked (month 1-12, day 1-31), not whether the day
/// exists in that month, so 20260231 would display as "31 Feb 2026".
String formatDateKey(int dateKey) {
  // Split yyyymmdd into its parts with integer division and remainder.
  final year = dateKey ~/ 10000;
  final month = (dateKey ~/ 100) % 100;
  final day = dateKey % 100;

  // Out-of-range parts mean this isn't a real date key, so show it as-is.
  if (month < 1 || month > 12 || day < 1 || day > 31) return '$dateKey';
  return '$day ${_months[month - 1]} $year';
}
