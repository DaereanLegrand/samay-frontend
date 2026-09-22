import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/group.dart';
import 'package:samay/core/models/group_member.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/utils/shard_math.dart';
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

  /// Re-runs [build] after group mutations (donations, transfers…). 
  /// skipped while the last fetch is younger than [refreshThrottle].
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

class GroupChatIdNotifier extends FamilyAsyncNotifier<String?, String>
    with ThrottledRefresh {
  @override
  Future<String?> build(String arg) async {
    final chatId = await ref.read(groupsRepositoryProvider).getGroupChatId(arg);
    markFetched();
    return chatId;
  }

  /// Re-runs [build] after a group chat row is created (the group
  /// detail Chat tab retries on demand), skipped while the last fetch
  /// is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// The chat id of [groupId]'s group chat (`chats` row with
/// `type = 'group'` + `reference_id = [groupId]`), or null while the row
/// does not exist yet. The group detail Chat tab hosts
/// [ChatThreadView] with the resolved chat id.
final groupChatIdProvider = AsyncNotifierProvider.family<GroupChatIdNotifier,
    String?, String>(GroupChatIdNotifier.new);

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
    extends FamilyAsyncNotifier<GroupContributionsData, String>
    with ThrottledRefresh {
  @override
  Future<GroupContributionsData> build(String arg) async {
    final repo = ref.read(groupsRepositoryProvider);
    final raw = await repo.getGroupContributions(arg);
    final contributors = aggregateContributions(raw);
    final myContribution = await repo.getUserContributionToGroup(arg);
    markFetched();
    return GroupContributionsData(
      contributors: contributors,
      myContribution: myContribution,
    );
  }

  /// Re-runs [build] after a donation.  skipped while the last fetch is
  /// younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Top contributors (per user, aggregated, sorted desc) + the current user's
/// own active contribution for a group.
final contributionsProvider = AsyncNotifierProvider.family<
    GroupContributionsNotifier, GroupContributionsData, String>(
  GroupContributionsNotifier.new,
);

/// Combined group-detail data: all four providers fetched in parallel,
/// returned as a record. Replaces the 4-level nested when() in
/// GroupDetailScreen (Batch 5b M5).
class GroupDetailData {
  final Group? group;
  final List<GroupMember> members;
  final GroupContributionsData contributions;
  final Map<String, dynamic>? membership;

  const GroupDetailData({
    required this.group,
    required this.members,
    required this.contributions,
    required this.membership,
  });
}

class GroupDetailCombinedNotifier
    extends FamilyAsyncNotifier<GroupDetailData, String> {
  @override
  Future<GroupDetailData> build(String groupId) async {
    final repo = ref.read(groupsRepositoryProvider);
    // Fetch all four in parallel via Future.wait.
    final results = await Future.wait([
      repo.getGroup(groupId),
      repo.getGroupMembers(groupId),
      Future(() async {
        final raw = await repo.getGroupContributions(groupId);
        final contributors = aggregateContributions(raw);
        final myContribution = await repo.getUserContributionToGroup(groupId);
        return GroupContributionsData(
          contributors: contributors,
          myContribution: myContribution,
        );
      }),
      repo.getMyMembership(groupId),
    ]);
    return GroupDetailData(
      group: results[0] as Group?,
      members: results[1] as List<GroupMember>,
      contributions: results[2] as GroupContributionsData,
      membership: results[3] as Map<String, dynamic>?,
    );
  }
}

/// All group-detail data in one fetch — parallel Future.wait replaces
/// the 4-level nested when() in the detail screen (M5).
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

/// A leaderboard entry: a [Group] enriched with ranking data.
class LeaderboardEntry {
  final Group group;
  final int rankPosition;
  final int score;
  final int memberCount;

  const LeaderboardEntry({
    required this.group,
    required this.rankPosition,
    required this.score,
    required this.memberCount,
  });
}

class LeaderboardNotifier
    extends FamilyAsyncNotifier<List<LeaderboardEntry>, String>
    with ThrottledRefresh {
  @override
  Future<List<LeaderboardEntry>> build(String sizeTier) async {
    final repo = ref.read(groupsRepositoryProvider);
    final res = await repo.getLeaderboard(sizeTier);
    final byId = {
      for (final g in await repo.getGroups([
        for (final r in res) r['group_id'] as String,
      ]))
        g.id: g,
    };
    final entries = <LeaderboardEntry>[];
    for (final r in res) {
      final g = byId[r['group_id'] as String];
      if (g != null) {
        entries.add(
          LeaderboardEntry(
            group: g,
            rankPosition: (r['rank_position'] as num?)?.toInt() ?? 0,
            score: (r['score'] as num?)?.toInt() ?? 0,
            memberCount: (r['member_count'] as num?)?.toInt() ?? 0,
          ),
        );
      }
    }
    markFetched();
    return entries;
  }

  /// Re-runs [build].  skipped while the
  /// last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Group rankings for a size tier (`micro`/`small`/`medium`/`large`),
/// enriched with group details.
final leaderboardProvider = AsyncNotifierProvider.family<LeaderboardNotifier,
    List<LeaderboardEntry>, String>(LeaderboardNotifier.new);
