// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_search_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserSearchResult _$UserSearchResultFromJson(Map<String, dynamic> json) =>
    _UserSearchResult(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      friendshipStatus: json['friendship_status'] as String?,
      friendshipId: json['friendship_id'] as String?,
      friendshipDirection: json['friendship_direction'] as String?,
    );

Map<String, dynamic> _$UserSearchResultToJson(_UserSearchResult instance) =>
    <String, dynamic>{
      'id': instance.id,
      'username': instance.username,
      'avatar_url': instance.avatarUrl,
      'friendship_status': instance.friendshipStatus,
      'friendship_id': instance.friendshipId,
      'friendship_direction': instance.friendshipDirection,
    };
