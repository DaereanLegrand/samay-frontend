// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_profile.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserProfile _$UserProfileFromJson(Map<String, dynamic> json) => _UserProfile(
  id: json['id'] as String,
  username: json['username'] as String,
  avatarUrl: json['avatar_url'] as String?,
  bio: json['bio'] as String?,
  personalShards: (json['personal_shards'] as num?)?.toInt() ?? 0,
  preshards: (json['preshards'] as num?)?.toInt() ?? 0,
  subscriptionTier: json['subscription_tier'] as String? ?? 'free',
  entitlementTier: json['entitlement_tier'] as String? ?? 'free',
  deletedAt: json['deleted_at'] == null
      ? null
      : DateTime.parse(json['deleted_at'] as String),
  dateOfBirth: json['date_of_birth'] == null
      ? null
      : DateTime.parse(json['date_of_birth'] as String),
);

Map<String, dynamic> _$UserProfileToJson(_UserProfile instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'avatar_url': instance.avatarUrl,
      'bio': instance.bio,
      'personal_shards': instance.personalShards,
      'preshards': instance.preshards,
      'subscription_tier': instance.subscriptionTier,
      'entitlement_tier': instance.entitlementTier,
      'deleted_at': instance.deletedAt?.toIso8601String(),
      'date_of_birth': instance.dateOfBirth?.toIso8601String(),
    };
