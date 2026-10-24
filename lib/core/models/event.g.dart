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
  description: json['description'] as String?,
  groupId: json['group_id'] as String?,
  locationName: json['location_name'] as String?,
  locationCity: json['location_city'] as String?,
  locationLat: _asDouble(json['location_lat']),
  locationLng: _asDouble(json['location_lng']),
  viewerRole: json['viewer_role'] as String?,
  viewerHasExactLocation: json['viewer_has_exact_location'] as bool? ?? false,
  distanceKm: _asDouble(json['distance_km']),
  coverUrl: json['cover_url'] as String?,
  createdByUserId: json['created_by_user_id'] as String?,
  joinMode: json['join_mode'] as String?,
  featured: json['featured'] as bool? ?? false,
  preshardsDistributed: json['preshards_distributed'] as bool? ?? false,
  preshardsPool: (json['preshards_pool'] as num?)?.toInt() ?? 0,
  capacity: (json['capacity'] as num?)?.toInt() ?? 0,
  preshardsCapPerUser: (json['preshards_cap_per_user'] as num?)?.toInt(),
  preshardsRemainderAction: json['preshards_remainder_action'] as String?,
);

Map<String, dynamic> _$EventToJson(_Event instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'type': instance.type,
  'status': instance.status,
  'starts_at': instance.startsAt.toIso8601String(),
  'ends_at': instance.endsAt.toIso8601String(),
  'description': instance.description,
  'group_id': instance.groupId,
  'location_name': instance.locationName,
  'location_city': instance.locationCity,
  'location_lat': instance.locationLat,
  'location_lng': instance.locationLng,
  'viewer_role': instance.viewerRole,
  'viewer_has_exact_location': instance.viewerHasExactLocation,
  'distance_km': instance.distanceKm,
  'cover_url': instance.coverUrl,
  'created_by_user_id': instance.createdByUserId,
  'join_mode': instance.joinMode,
  'featured': instance.featured,
  'preshards_distributed': instance.preshardsDistributed,
  'preshards_pool': instance.preshardsPool,
  'capacity': instance.capacity,
  'preshards_cap_per_user': instance.preshardsCapPerUser,
  'preshards_remainder_action': instance.preshardsRemainderAction,
};
