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

/// Q17 funnel guard: the profile-creation call must never receive a missing or
/// underage DOB, even if a stale/deep-linked route skipped the picker. Returns
/// null when the ISO date is acceptable; otherwise a stable reason the screen
/// can localize.
String? signupDobError(String? isoDate, {DateTime? now}) {
  if (isoDate == null || isoDate.trim().isEmpty) return 'required';
  final parsed = DateTime.tryParse(isoDate);
  if (parsed == null) return 'invalid';
  return isAdult(parsed, now: now) ? null : 'underage';
}
