import 'package:intl/intl.dart';

/// Formats a ledger entry timestamp for the movement rows, e.g.
/// "sáb 1 ago., 21:30" — locale-aware via `intl`, same pattern as the event
/// date ranges (`lib/features/events/event_formatters.dart`).
String formatLedgerTimestamp(DateTime createdAt, String locale) {
  return DateFormat('EEE d MMM, HH:mm', locale).format(createdAt.toLocal());
}

/// Shortens a uuid reference for the ledger rows (SLED "reference id short"):
/// the first uuid segment (8 hex chars) is enough for cross-referencing
/// against event/group/cosmetic ids on other screens.
String shortReferenceId(String? referenceId) {
  if (referenceId == null || referenceId.isEmpty) return '';
  final dash = referenceId.indexOf('-');
  return dash > 0 ? referenceId.substring(0, dash) : referenceId;
}
