import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/group.dart';
import 'package:samay/core/models/group_member.dart';
import 'package:samay/core/models/group_theme.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/utils/throttled_refresh.dart';

class MyGroupsNotifier extends AsyncNotifier<List<Group>>
    with ThrottledRefresh {
  @override
  Future<List<Group>> build() async {
    final groups = await ref.read(groupsRepositoryProvider).getMyGroups();
    markFetched();
    return groups;
  }

  /// Re-runs [build] after creating/joining/leaving a group.
  /// skipped while the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Groups the current user belongs to (each row carries `my_role`).
final myGroupsProvider =
    AsyncNotifierProvider<MyGroupsNotifier, List<Group>>(MyGroupsNotifier.new);

class GroupDetailNotifier
    extends FamilyAsyncNotifier<Group?, String>
    with ThrottledRefresh {
  @override
  Future<Group?> build(String arg) async {
    final group = await ref.read(groupsRepositoryProvider).getGroup(arg);
    markFetched();
    return group;
  }

  /// Re-runs [build] after group mutations.  skipped while the last fetch is
  /// younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// A single group row by id (null when the group does not exist).
final groupDetailProvider = AsyncNotifierProvider.family<GroupDetailNotifier,
    Group?, String>(GroupDetailNotifier.new);

class GroupMembersNotifier
    extends FamilyAsyncNotifier<List<GroupMember>, String>
    with ThrottledRefresh {
  @override
  Future<List<GroupMember>> build(String arg) async {
    final members =
        await ref.read(groupsRepositoryProvider).getGroupMembers(arg);
    markFetched();
    return members;
  }

  /// Re-runs [build] after membership changes.  skipped while the last
  /// fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Active members of a group (rows join `users` → `users.username`).
final groupMembersProvider = AsyncNotifierProvider.family<GroupMembersNotifier,
    List<GroupMember>, String>(GroupMembersNotifier.new);

/// Combined group-detail data: the group, its members and the caller's
/// membership row fetched in parallel, returned as one record.
class GroupDetailData {
  final Group? group;
  final List<GroupMember> members;
  final Map<String, dynamic>? membership;

  const GroupDetailData({
    required this.group,
    required this.members,
    required this.membership,
  });
}

class GroupDetailCombinedNotifier
    extends FamilyAsyncNotifier<GroupDetailData, String> {
  @override
  Future<GroupDetailData> build(String groupId) async {
    final repo = ref.read(groupsRepositoryProvider);
    final results = await Future.wait([
      repo.getGroup(groupId),
      repo.getGroupMembers(groupId),
      repo.getMyMembership(groupId),
    ]);
    return GroupDetailData(
      group: results[0] as Group?,
      members: results[1] as List<GroupMember>,
      membership: results[2] as Map<String, dynamic>?,
    );
  }
}

/// All group-detail data in one fetch — parallel Future.wait replaces
/// the nested when() in the detail screen (M5).
final groupDetailCombinedProvider = AsyncNotifierProvider.family<
    GroupDetailCombinedNotifier, GroupDetailData, String>(
  GroupDetailCombinedNotifier.new,
);

class GroupInvitesNotifier extends AsyncNotifier<List<Map<String, dynamic>>>
    with ThrottledRefresh {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final invites =
        await ref.read(groupsRepositoryProvider).getGroupInvites();
    markFetched();
    return invites;
  }

  /// Re-runs [build] after accepting/declining an invite.  skipped while
  /// the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Group invitations awaiting the current user's response.
final groupInvitesProvider = AsyncNotifierProvider<GroupInvitesNotifier,
    List<Map<String, dynamic>>>(GroupInvitesNotifier.new);

/// The host-owned group theme (E4): palette, control mode and the caller's
/// `can_change_*` flags. The member list and group minigames read the
/// resulting colours.
final groupThemeProvider =
    FutureProvider.family<GroupTheme, String>((ref, groupId) {
  return ref.read(groupsRepositoryProvider).getGroupTheme(groupId);
});
