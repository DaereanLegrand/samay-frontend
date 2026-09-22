/// Pure age-verification policy shared by the age gate. Calendar-accurate
/// 18-year rule: the shared function (not a `365 * 18`-day approximation)
/// keeps the 17y364d boundary and leap-day birthdays correct everywhere.
///
/// [now] is injectable; defaults to `DateTime.now()`.
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
