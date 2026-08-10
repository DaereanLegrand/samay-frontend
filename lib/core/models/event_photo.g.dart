// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'event_photo.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_EventPhoto _$EventPhotoFromJson(Map<String, dynamic> json) => _EventPhoto(
  id: json['id'] as String,
  eventId: json['event_id'] as String,
  uploadedByUserId: json['uploaded_by_user_id'] as String,
  storagePath: json['storage_path'] as String,
  likesCount: (json['likes_count'] as num?)?.toInt() ?? 0,
  reported: json['reported'] as bool? ?? false,
  createdAt: DateTime.parse(json['created_at'] as String),
  signedUrl: json['signed_url'] as String?,
  likedByMe: json['liked_by_me'] as bool? ?? false,
);

Map<String, dynamic> _$EventPhotoToJson(_EventPhoto instance) =>
    <String, dynamic>{
      'id': instance.id,
      'event_id': instance.eventId,
      'uploaded_by_user_id': instance.uploadedByUserId,
      'storage_path': instance.storagePath,
      'likes_count': instance.likesCount,
      'reported': instance.reported,
      'created_at': instance.createdAt.toIso8601String(),
      'signed_url': instance.signedUrl,
      'liked_by_me': instance.likedByMe,
    };
