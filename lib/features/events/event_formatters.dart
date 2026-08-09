import 'package:intl/intl.dart';

/// Formats an event date range for display, e.g. "vie 15 may., 21:00 – 02:00"
/// (same-day events show the end time only) — locale-aware via `intl`.
String formatEventDateRange(DateTime startsAt, DateTime endsAt, String locale) {
  final start = startsAt.toLocal();
  final end = endsAt.toLocal();
  final startLabel = DateFormat('EEE d MMM, HH:mm', locale).format(start);
  if (start.year == end.year &&
      start.month == end.month &&
      start.day == end.day) {
    return '$startLabel – ${DateFormat('HH:mm', locale).format(end)}';
  }
  return '$startLabel – ${DateFormat('EEE d MMM, HH:mm', locale).format(end)}';
}
