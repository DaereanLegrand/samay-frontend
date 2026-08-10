// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ledger_entry.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_LedgerEntry _$LedgerEntryFromJson(Map<String, dynamic> json) => _LedgerEntry(
  id: json['id'] as String,
  delta: (json['delta'] as num).toInt(),
  reason: json['reason'] as String,
  referenceId: json['reference_id'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$LedgerEntryToJson(_LedgerEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'delta': instance.delta,
      'reason': instance.reason,
      'reference_id': instance.referenceId,
      'created_at': instance.createdAt.toIso8601String(),
    };
