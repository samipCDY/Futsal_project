const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Wed 15 Jul 2026"
String formatDateLong(DateTime date) =>
    '${_weekdays[date.weekday - 1]} ${date.day} ${_months[date.month - 1]} ${date.year}';

/// "15 Jul 2026"
String formatDateDayMonthYear(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

/// "Wed 15" — for compact date pickers.
String formatDateShort(DateTime date) => '${_weekdays[date.weekday - 1]} ${date.day}';

/// "2026-07-15" — the format the API expects.
String formatDateApi(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// "18:00" or "18:00:00" -> "6:00 PM"
String formatClock(String time) {
  final parts = time.split(':');
  final hour = int.parse(parts[0]);
  final minute = parts.length > 1 ? parts[1] : '00';
  final hour12 = hour % 12 == 0 ? 12 : hour % 12;
  return '$hour12:$minute ${hour < 12 ? 'AM' : 'PM'}';
}

/// "18:00", "19:00" -> "6:00 PM – 7:00 PM"
String formatTimeRange(String start, String end) => '${formatClock(start)} – ${formatClock(end)}';
