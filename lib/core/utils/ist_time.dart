/// Bengaluru time helpers.
///
/// All timetable maths uses "IST wall-clock" DateTimes stored as UTC values
/// (so 08:30 IST is DateTime.utc(y, m, d, 8, 30)). That keeps results the same
/// whatever time zone the phone or browser is set to.
library;

const istOffset = Duration(hours: 5, minutes: 30);

DateTime nowIst() => DateTime.now().toUtc().add(istOffset);

DateTime istMidnight(DateTime t) => DateTime.utc(t.year, t.month, t.day);

bool isWeekend(DateTime t) => t.weekday == DateTime.saturday || t.weekday == DateTime.sunday;

/// Hour of day as a fraction, e.g. 8:30 -> 8.5.
double hourOfDay(DateTime t) => t.hour + t.minute / 60 + t.second / 3600;

/// "8:42 am"
String formatTime(DateTime t) {
  final h12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final mm = t.minute.toString().padLeft(2, '0');
  return '$h12:$mm ${t.hour < 12 ? 'am' : 'pm'}';
}

/// "+11 min", "-2 min", "on time"
String formatDelay(double minutes) {
  final m = minutes.round();
  if (m == 0) return 'on time';
  return m > 0 ? '+$m min' : '$m min';
}

/// "in 7 min", "now", "2 min ago"
String formatRelative(DateTime t, DateTime now) {
  final m = t.difference(now).inSeconds / 60;
  if (m.abs() < 1) return 'now';
  return m > 0 ? 'in ${m.round()} min' : '${(-m).round()} min ago';
}
