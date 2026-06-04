// IST calendar day counts for subscription windows (matches server
// subscriptionCalendarDays.js). Inclusive start/end; remaining counts
// from today (IST) through end, including today.

String _ymdIST(DateTime d) {
  final utc = d.toUtc();
  final ist = utc.add(const Duration(hours: 5, minutes: 30));
  return '${ist.year.toString().padLeft(4, '0')}-'
      '${ist.month.toString().padLeft(2, '0')}-'
      '${ist.day.toString().padLeft(2, '0')}';
}

String _istTodayYmd() => _ymdIST(DateTime.now());

/// Inclusive calendar days from subscription start → end (IST).
int totalDaysInclusiveIST(DateTime start, DateTime end) {
  final y1 = _ymdIST(start);
  final y2 = _ymdIST(end);
  final a = DateTime.parse('${y1}T00:00:00+05:30');
  final b = DateTime.parse('${y2}T00:00:00+05:30');
  final diff = b.difference(a).inDays;
  if (diff < 0) return 0;
  return diff + 1;
}

/// Days from today (IST) through end date (inclusive).
int remainingDaysInclusiveIST(DateTime start, DateTime end) {
  final startYmd = _ymdIST(start);
  final endYmd = _ymdIST(end);
  final todayYmd = _istTodayYmd();
  final remStart =
      startYmd.compareTo(todayYmd) >= 0 ? startYmd : todayYmd;
  if (remStart.compareTo(endYmd) > 0) return 0;
  final a = DateTime.parse('${remStart}T00:00:00+05:30');
  final b = DateTime.parse('${endYmd}T00:00:00+05:30');
  return b.difference(a).inDays + 1;
}
