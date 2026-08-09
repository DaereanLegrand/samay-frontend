import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/services/supabase_service.dart';

class MyGroupsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return SupabaseService.instance.getMyGroups();
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
    return SupabaseService.instance.getGroup(arg);
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
    return SupabaseService.instance.getGroupMembers(arg);
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
    final raw = await SupabaseService.instance.getGroupContributions(arg);
    final Map<String, Map<String, dynamic>> aggregated = {};
    for (final c in raw) {
      final uid = c['user_id'] as String;
      final amount = c['shards_contributed'] as int;
      if (aggregated.containsKey(uid)) {
        aggregated[uid]!['shards_contributed'] =
            (aggregated[uid]!['shards_contributed'] as int) + amount;
      } else {
        aggregated[uid] = Map<String, dynamic>.from(c);
      }
    }
    final contributors = aggregated.values.toList()
      ..sort((a, b) =>
          (b['shards_contributed'] as int).compareTo(a['shards_contributed'] as int));
    final myContribution =
        await SupabaseService.instance.getUserContributionToGroup(arg);
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
    return SupabaseService.instance.getGroupInvites();
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
    final res = await SupabaseService.instance.getLeaderboard(sizeTier);
    final groups = <Map<String, dynamic>>[];
    for (final r in res) {
      final g = await SupabaseService.instance.getGroup(r['group_id'] as String);
      if (g != null) {
        g['rank_position'] = r['rank_position'];
        g['score'] = r['score'];
        g['member_count'] = r['member_count'];
        groups.add(g);
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
