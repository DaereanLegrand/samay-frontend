import 'package:freezed_annotation/freezed_annotation.dart';

part 'group_member.freezed.dart';
part 'group_member.g.dart';

@freezed
abstract class GroupMember with _$GroupMember {
  const GroupMember._();

  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory GroupMember({
    required String id,
    required String groupId,
    required String userId,
    @Default('member') String role,
    @Default('active') String status,
    required DateTime joinedAt,
    @JsonKey(name: 'users') Map<String, dynamic>? users,
  }) = _GroupMember;

  factory GroupMember.fromJson(Map<String, dynamic> json) =>
      _$GroupMemberFromJson(json);

  String? get username => users?['username'] as String?;

  String? get avatarUrl => users?['avatar_url'] as String?;
}
