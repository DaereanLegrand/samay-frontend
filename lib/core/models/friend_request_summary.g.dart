// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friend_request_summary.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FriendRequestSummary _$FriendRequestSummaryFromJson(
  Map<String, dynamic> json,
) => _FriendRequestSummary(
  type: json['type'] as String,
  friendshipId: json['friendship_id'] as String,
  userId: json['user_id'] as String,
  createdAt: json['created_at'] == null
      ? null
      : DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$FriendRequestSummaryToJson(
  _FriendRequestSummary instance,
) => <String, dynamic>{
  'type': instance.type,
  'friendship_id': instance.friendshipId,
  'user_id': instance.userId,
  'created_at': instance.createdAt?.toIso8601String(),
};
