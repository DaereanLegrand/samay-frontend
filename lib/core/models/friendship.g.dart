// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'friendship.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_FriendshipSummary _$FriendshipSummaryFromJson(Map<String, dynamic> json) =>
    _FriendshipSummary(
      friendshipId: json['friendship_id'] as String,
      userId: json['user_id'] as String,
      status: json['status'] as String?,
    );

Map<String, dynamic> _$FriendshipSummaryToJson(_FriendshipSummary instance) =>
    <String, dynamic>{
      'friendship_id': instance.friendshipId,
      'user_id': instance.userId,
      'status': instance.status,
    };
