// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Group _$GroupFromJson(Map<String, dynamic> json) => _Group(
  id: json['id'] as String,
  name: json['name'] as String,
  description: json['description'] as String?,
  coverUrl: json['cover_url'] as String?,
  groupShards: (json['group_shards'] as num?)?.toInt() ?? 0,
  sizeTier: json['size_tier'] as String?,
  rankBracket: json['rank_bracket'] as String?,
  frozenAt: json['frozen_at'] == null
      ? null
      : DateTime.parse(json['frozen_at'] as String),
  myRole: json['my_role'] as String?,
  myStatus: json['my_status'] as String?,
);

Map<String, dynamic> _$GroupToJson(_Group instance) => <String, dynamic>{
  'id': instance.id,
  'name': instance.name,
  'description': instance.description,
  'cover_url': instance.coverUrl,
  'group_shards': instance.groupShards,
  'size_tier': instance.sizeTier,
  'rank_bracket': instance.rankBracket,
  'frozen_at': instance.frozenAt?.toIso8601String(),
  'my_role': instance.myRole,
  'my_status': instance.myStatus,
};
