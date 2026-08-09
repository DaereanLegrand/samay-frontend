// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Event _$EventFromJson(Map<String, dynamic> json) => _Event(
  id: json['id'] as String,
  name: json['name'] as String,
  type: json['type'] as String,
  status: json['status'] as String,
  startsAt: DateTime.parse(json['starts_at'] as String),
  endsAt: DateTime.parse(json['ends_at'] as String),
  groupId: json['group_id'] as String?,
  locationName: json['location_name'] as String?,
  preshardsPool: (json['preshards_pool'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$EventToJson(_Event instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': instance.type,
  'status': instance.status,
  'starts_at': instance.startsAt.toIso8601String(),
  'ends_at': instance.endsAt.toIso8601String(),
  'group_id': instance.groupId,
  'location_name': instance.locationName,
  'preshards_pool': instance.preshardsPool,
};
