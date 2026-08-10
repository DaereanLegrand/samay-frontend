import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/utils/shard_math.dart';

class MyGroupsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final groups = await ref.read(groupsRepositoryProvider).getMyGroups();
    return groups.map((g) => g.toJson()).toList();
  }

  /// Re-runs [build] after creating/joining/leaving a group (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Groups the current user belongs to (each row carries `my_role`).
final myGroupsProvider = AsyncNotifierProvider<MyGroupsNotifier,
    List<Map<String, dynamic>>>(MyGroupsNotifier.new);

class GroupDetailNotifier
    extends FamilyAsyncNotifier<Map<String, dynamic>?, String> {
  @override
  Future<Map<String, dynamic>?> build(String arg) async {
    final group = await ref.read(groupsRepositoryProvider).getGroup(arg);
    return group?.toJson();
  }

  /// Re-runs [build] after group mutations (donations, transfers…).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// A single group row by id (null when the group does not exist).
final groupDetailProvider = AsyncNotifierProvider.family<GroupDetailNotifier,
    Map<String, dynamic>?, String>(GroupDetailNotifier.new);

class GroupMembersNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String> {
  @override
  Future<List<Map<String, dynamic>>> build(String arg) async {
    final members =
        await ref.read(groupsRepositoryProvider).getGroupMembers(arg);
    return members.map((m) => m.toJson()).toList();
  }

  /// Re-runs [build] after membership changes.
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Active members of a group (rows join `users` → `users.username`).
final groupMembersProvider = AsyncNotifierProvider.family<GroupMembersNotifier,
    List<Map<String, dynamic>>, String>(GroupMembersNotifier.new);

/// Aggregated per-user contributions plus the current user's own active
/// total, for a group.
class GroupContributionsData {
  final List<Map<String, dynamic>> contributors;
  final int myContribution;

  const GroupContributionsData({
    required this.contributors,
    required this.myContribution,
  });
}

class GroupContributionsNotifier
    extends FamilyAsyncNotifier<GroupContributionsData, String> {
  @override
  Future<GroupContributionsData> build(String arg) async {
    final repo = ref.read(groupsRepositoryProvider);
    final raw = await repo.getGroupContributions(arg);
    final contributors = aggregateContributions(raw);
    final myContribution = await repo.getUserContributionToGroup(arg);
    return GroupContributionsData(
      contributors: contributors,
      myContribution: myContribution,
    );
  }

  /// Re-runs [build] after a donation.
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Top contributors (per user, aggregated, sorted desc) + the current user's
/// own active contribution for a group.
final contributionsProvider = AsyncNotifierProvider.family<
    GroupContributionsNotifier, GroupContributionsData, String>(
  GroupContributionsNotifier.new,
);

class GroupInvitesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return ref.read(groupsRepositoryProvider).getGroupInvites();
  }

  /// Re-runs [build] after accepting/declining an invite.
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Group invitations awaiting the current user's response.
final groupInvitesProvider = AsyncNotifierProvider<GroupInvitesNotifier,
    List<Map<String, dynamic>>>(GroupInvitesNotifier.new);

class LeaderboardNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String> {
  @override
  Future<List<Map<String, dynamic>>> build(String sizeTier) async {
    final repo = ref.read(groupsRepositoryProvider);
    final res = await repo.getLeaderboard(sizeTier);
    final groups = <Map<String, dynamic>>[];
    for (final r in res) {
      final g = await repo.getGroup(r['group_id'] as String);
      if (g != null) {
        final row = g.toJson();
        row['rank_position'] = r['rank_position'];
        row['score'] = r['score'];
        row['member_count'] = r['member_count'];
        groups.add(row);
      }
    }
    return groups;
  }

  /// Re-runs [build] (pull-to-refresh, finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Group rankings for a size tier (`micro`/`small`/`medium`/`large`),
/// enriched with group details.
final leaderboardProvider = AsyncNotifierProvider.family<LeaderboardNotifier,
    List<Map<String, dynamic>>, String>(LeaderboardNotifier.new);
