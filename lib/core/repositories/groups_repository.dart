import 'package:samay/core/models/group.dart';
import 'package:samay/core/models/group_member.dart';
import 'package:samay/core/services/group_service.dart';
import 'package:samay/core/services/shards_service.dart';

/// Groups domain repository (I-50): thin, typed facade over [GroupService]
/// (memberships, invites, roles) and [ShardsService] (economy, leaderboard).
///
/// Dependency direction doctrine (DEVELOPMENT-WORKFLOW §5): providers depend
/// on repositories, repositories on services, services on the Supabase client.
/// Feature providers must read this repository via `groupsRepositoryProvider`
/// (Riverpod) instead of the legacy `SupabaseService.instance` singleton.
///
/// Typed where the I-10 freezed models match the service shape ([Group],
/// [GroupMember]); raw `Map<String, dynamic>` rows are passed through where
/// the service shapes are not modeled (`getGroupInvites` joins `groups` while
/// the model maps `users`; `getLeaderboard` rank snapshots; aggregated
/// `getGroupContributions` rows).
class GroupsRepository {
  GroupsRepository({
    required GroupService groups,
    required ShardsService shards,
  })  : _groups = groups,
        _shards = shards;

  final GroupService _groups;
  final ShardsService _shards;

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

  Future<void> transferPromotor(String groupId, String newPromotorId) =>
      _groups.transferPromotor(groupId, newPromotorId);

  Future<void> setMemberRole(String groupId, String userId, String role) =>
      _groups.setMemberRole(groupId, userId, role);

  Future<int> getUserGroupCount() => _groups.getUserGroupCount();

  /// Invites [userIds] to [groupId] as pending `invited` members.
  Future<void> inviteMembers(String groupId, List<String> userIds) =>
      _groups.inviteMembers(groupId, userIds);

  /// Group rankings for a size tier (`micro`/`small`/`medium`/`large`) —
  /// rank-snapshot rows, not modeled — Map passthrough.
  Future<List<Map<String, dynamic>>> getLeaderboard(String sizeTier) =>
      _shards.getLeaderboard(sizeTier);

  /// Active per-user contribution rows of a group (aggregation happens at
  /// the provider boundary, same as before the repository layer).
  Future<List<Map<String, dynamic>>> getGroupContributions(String groupId) =>
      _shards.getGroupContributions(groupId);

  /// The current user's own active contribution total for a group.
  Future<int> getUserContributionToGroup(String groupId) =>
      _shards.getUserContributionToGroup(groupId);

  /// Donates [amount] shards to [groupId] (RPC with boost window).
  Future<void> donateToGroup(String groupId, int amount) =>
      _shards.donateToGroup(groupId, amount);
}
