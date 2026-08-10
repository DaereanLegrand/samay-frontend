import 'package:freezed_annotation/freezed_annotation.dart';

part 'ledger_entry.freezed.dart';
part 'ledger_entry.g.dart';

/// A single immutable shard/preshard movement (SLED — `shard_ledger` and
/// `preshard_ledger` rows; 20260510000001_full_schema.sql:272/282).
///
/// Both tables share the same shape: the delta sign convention (+earn /
/// −spend), the `reason` enum value (9 shard reasons / 6 preshard reasons),
/// an optional [referenceId] pointing at the entity that caused the movement
/// (event, group, cosmetic or minigame session) and the immutable
/// [createdAt] timestamp. Rows are read-only for clients (`sl_read_own` /
/// `pl_read_own` RLS) — this model is a display projection, never written
/// back.
@freezed
abstract class LedgerEntry with _$LedgerEntry {
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory LedgerEntry({
    required String id,
    required int delta,
    required String reason,
    String? referenceId,
    required DateTime createdAt,
  }) = _LedgerEntry;

  factory LedgerEntry.fromJson(Map<String, dynamic> json) =>
      _$LedgerEntryFromJson(json);
}
