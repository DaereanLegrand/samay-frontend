// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'group_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_GroupMember _$GroupMemberFromJson(Map<String, dynamic> json) => _GroupMember(
  id: json['id'] as String,
  groupId: json['group_id'] as String,
  userId: json['user_id'] as String,
  role: json['role'] as String? ?? 'member',
  status: json['status'] as String? ?? 'active',
  joinedAt: DateTime.parse(json['joined_at'] as String),
  users: json['users'] as Map<String, dynamic>?,
);

Map<String, dynamic> _$GroupMemberToJson(_GroupMember instance) =>
    <String, dynamic>{
      'id': instance.id,
      'group_id': instance.groupId,
      'user_id': instance.userId,
      'role': instance.role,
      'status': instance.status,
      'joined_at': instance.joinedAt.toIso8601String(),
      'users': instance.users,
    };
