import 'package:samay/core/models/group.dart';
import 'package:samay/core/models/group_member.dart';
import 'package:samay/core/models/group_theme.dart';
import 'package:samay/core/services/group_service.dart';

/// Groups domain repository: thin, typed facade over [GroupService]
/// (memberships, invites, roles) and [ShardsService] (economy, leaderboard).
///
/// Dependency direction doctrine (DEVELOPMENT-WORKFLOW §5): providers depend
/// on repositories, repositories on services, services on the Supabase client.
/// Feature providers must read this repository via `groupsRepositoryProvider`
/// (Riverpod) instead of the `SupabaseService.instance` singleton.
///
/// Typed where the freezed models match the service shape ([Group],
/// [GroupMember]); raw `Map<String, dynamic>` rows are passed through where
/// the service shapes are not modeled (`getGroupInvites` joins `groups` while
/// the model maps `users`; `getLeaderboard` rank snapshots; aggregated
/// `getGroupContributions` rows).
class GroupsRepository {
  GroupsRepository({required GroupService groups}) : _groups = groups;

  final GroupService _groups;

  /// Groups the current user belongs to (each [Group] carries `myRole`).
  Future<List<Group>> getMyGroups() async {
    final res = await _groups.getMyGroups();
    return [for (final g in res) Group.fromJson(g)];
  }

  /// A single group by id, or null when it does not exist.
  Future<Group?> getGroup(String groupId) async {
    final res = await _groups.getGroup(groupId);
    return res == null ? null : Group.fromJson(res);
  }

  /// Groups for [groupIds] in ONE read — the batch form of [getGroup].
  Future<List<Group>> getGroups(List<String> groupIds) async {
    final res = await _groups.getGroups(groupIds);
    return [for (final g in res) Group.fromJson(g)];
  }

  /// The chat id of [groupId]'s group chat (type='group', reference_id), or
  /// null when the chat row does not exist — the UI opens the group's E2EE
  /// chat with this id.
  Future<String?> getGroupChatId(String groupId) =>
      _groups.getGroupChatId(groupId);

  /// Active members of a group (each [GroupMember] carries the `users` join
  /// → [GroupMember.username]).
  Future<List<GroupMember>> getGroupMembers(String groupId) async {
    final res = await _groups.getGroupMembers(groupId);
    return [for (final m in res) GroupMember.fromJson(m)];
  }

  /// Group invitations awaiting the current user's response. The rows join
  /// `groups` (`groups.name`) which the [GroupMember] model does not map —
  /// Map passthrough.
  Future<List<Map<String, dynamic>>> getGroupInvites() =>
      _groups.getGroupInvites();

  /// The current user's own membership row for [groupId] (id/role/status),
  /// or null when there is none — Map passthrough (the detail
  /// screen gates the invited state on it).
  Future<Map<String, dynamic>?> getMyMembership(String groupId) =>
      _groups.getMyMembership(groupId);

  Future<void> acceptInvite(String membershipId) =>
      _groups.acceptGroupInvite(membershipId);

  Future<void> declineInvite(String membershipId) =>
      _groups.declineGroupInvite(membershipId);

  /// Group lifecycle + membership management (passthrough).
  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) =>
      _groups.createGroup(data);

  Future<void> joinGroup(String groupId) => _groups.joinGroup(groupId);

  Future<void> leaveGroup(String groupId) => _groups.leaveGroup(groupId);

  Future<void> updateGroup(String groupId, Map<String, dynamic> patch) =>
      _groups.updateGroup(groupId, patch);

  Future<void> kickMember(String groupId, String userId) =>
      _groups.kickMember(groupId, userId);

  Future<void> transferHost(String groupId, String newHostId) =>
      _groups.transferHost(groupId, newHostId);

  Future<void> setMemberRole(String groupId, String userId, String role) =>
      _groups.setMemberRole(groupId, userId, role);

  Future<int> getUserGroupCount() => _groups.getUserGroupCount();

  /// Invites [userIds] to [groupId] as pending `invited` members.
  Future<void> inviteMembers(String groupId, List<String> userIds) =>
      _groups.inviteMembers(groupId, userIds);

  /// The host-owned group theme plus the caller's permissions (E4).
  Future<GroupTheme> getGroupTheme(String groupId) async {
    final res = await _groups.getGroupTheme(groupId);
    return GroupTheme.fromJson(res);
  }

  /// Changes the group theme; omitted arguments are left untouched.
  Future<void> setGroupTheme(
    String groupId, {
    String? backgroundColor,
    String? accentColor,
    String? controlMode,
  }) =>
      _groups.setGroupTheme(
        groupId,
        backgroundColor: backgroundColor,
        accentColor: accentColor,
        controlMode: controlMode,
      );
}
