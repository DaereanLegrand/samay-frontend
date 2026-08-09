/// Pure age-verification policy extracted from `age_gate_screen.dart` (I-46,
/// TST-06/M-13). Calendar-accurate 18-year rule: the widget's old
/// `365 * 18`-day approximation is replaced by this shared function so the
/// 17y364d boundary and leap-day birthdays behave correctly everywhere.
///
/// [now] is injectable for deterministic tests; defaults to `DateTime.now()`.
bool isAdult(DateTime? birthDate, {DateTime? now}) {
  if (birthDate == null) return false;
  final reference = now ?? DateTime.now();
  if (birthDate.isAfter(reference)) return false;

  var age = reference.year - birthDate.year;
  final hadBirthdayThisYear = reference.month > birthDate.month ||
      (reference.month == birthDate.month && reference.day >= birthDate.day);
  if (!hadBirthdayThisYear) age -= 1;
  return age >= 18;
}

/// Formats a date of birth as `day/month/year` — the same shape the ARB
/// `authSelectedDate` template renders (l10n-agnostic pure function).
String formatDob(DateTime date) => '${date.day}/${date.month}/${date.year}';
