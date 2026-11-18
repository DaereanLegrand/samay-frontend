import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/models/friend_request_summary.dart';
import 'package:samay/core/models/user_profile.dart';
import 'package:samay/core/models/user_search_result.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/utils/throttled_refresh.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';

/// Combined view of a user's friend requests: received + sent rows and the
/// display names of the users involved.
///
/// Names are fetched per user because the friendships table only stores ids;
/// the map is keyed by `user_id`.
///
/// No-fallback: a friend whose profile cannot be resolved is
/// an ERROR, never a placeholder name — [build] throws and the screens
/// render the ErrorView + retry.
class FriendRequestsData {
  final List<FriendRequestSummary> requests;
  final Map<String, String> names;

  const FriendRequestsData({required this.requests, required this.names});
}

class FriendsListNotifier extends AsyncNotifier<List<UserProfile>>
    with ThrottledRefresh {
  @override
  Future<List<UserProfile>> build() async {
    final repo = ref.read(friendsRepositoryProvider);
    final res = await repo.getFriends();
    // Resolve every friend in ONE `get_friend_profiles` RPC round trip: the
    // client-side `user_search_view` read is not queryable on every deployment
    // (Kong strips the route path → PostgREST returns the OpenAPI doc).
    final rows = await repo.getUserSearchRows([for (final f in res) f.userId]);
    final byId = {for (final r in rows) r['id'] as String: r};
    final profiles = <UserProfile>[];
    for (final f in res) {
      // No-fallback: a friend with an unresolvable profile is
      // an ERROR — never silently dropped from the list.
      final row = byId[f.userId];
      if (row == null) {
        throw ProfileResolutionError(f.userId);
      }
      profiles.add(UserProfile.fromJson(row));
    }
    markFetched();
    return profiles;
  }

  /// Re-runs [build] to reload the friend list.  skipped
  /// while the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Friends of the current user, as full user profiles.
final friendsListProvider =
    AsyncNotifierProvider<FriendsListNotifier, List<UserProfile>>(
      FriendsListNotifier.new,
    );

class FriendRequestsNotifier extends AsyncNotifier<FriendRequestsData>
    with ThrottledRefresh {
  @override
  Future<FriendRequestsData> build() async {
    final repo = ref.read(friendsRepositoryProvider);
    final requests = await repo.getFriendRequests();
    final userIds = <String>{for (final r in requests) r.userId}.toList();
    final rows = await repo.getUserProfiles(userIds);
    final byId = {for (final row in rows) row['id'] as String: row};
    final names = <String, String>{};
    for (final userId in userIds) {
      // No-fallback: an unresolvable or username-less profile is
      // an ERROR — never the "Usuario" placeholder.
      final username = byId[userId]?['username'] as String?;
      if (username == null || username.isEmpty) {
        throw ProfileResolutionError(userId);
      }
      names[userId] = username;
    }
    markFetched();
    return FriendRequestsData(requests: requests, names: names);
  }

  /// Re-runs [build] after accepting/declining a request.
  /// skipped while the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Received + sent friend requests with resolved display names.
final friendRequestsProvider =
    AsyncNotifierProvider<FriendRequestsNotifier, FriendRequestsData>(
      FriendRequestsNotifier.new,
    );

class BlockedUsersNotifier extends AsyncNotifier<List<UserProfile>>
    with ThrottledRefresh {
  @override
  Future<List<UserProfile>> build() async {
    final repo = ref.read(friendsRepositoryProvider);
    // get_blocked_users() is SECURITY DEFINER: the public views intentionally
    // hide blocked users, so resolving them through user_search_view would
    // always fail.
    final rows = await repo.getBlockedUsers();
    markFetched();
    return [
      for (final row in rows)
        UserProfile.fromJson({
          'id': row['blocked_user_id'],
          'username': row['username'],
          'avatar_url': row['avatar_url'],
        }),
    ];
  }

  /// Re-runs [build] after unblocking a user.  skipped
  /// while the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Users blocked by the current user (profiles with username fallback).
final blockedUsersProvider =
    AsyncNotifierProvider<BlockedUsersNotifier, List<UserProfile>>(
      BlockedUsersNotifier.new,
    );

class MutedUsersNotifier extends AsyncNotifier<List<UserProfile>>
    with ThrottledRefresh {
  @override
  Future<List<UserProfile>> build() async {
    final service = ref.read(friendshipServiceProvider);
    final rows = await service.getMutedUsers();
    markFetched();
    return [
      for (final row in rows)
        UserProfile.fromJson({
          'id': row['id'],
          'username': row['username'],
          'avatar_url': row['avatar_url'],
        }),
    ];
  }

  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Users muted by the current user (one-way, weaker than block).
final mutedUsersProvider =
    AsyncNotifierProvider<MutedUsersNotifier, List<UserProfile>>(
      MutedUsersNotifier.new,
    );

class SearchResultsNotifier
    extends FamilyAsyncNotifier<List<UserSearchResult>, String>
    with ThrottledRefresh {
  @override
  Future<List<UserSearchResult>> build(String arg) async {
    final results = await ref.read(friendsRepositoryProvider).searchUsers(arg);
    markFetched();
    return results;
  }

  /// Re-runs [build] after a friend request changes a result's status.
  /// skipped while the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// User search results for a query (family keyed by the trimmed query).
///
/// Consumers must not watch this provider with an empty query — the search
/// service would query with an empty prefix.
final searchResultsProvider =
    AsyncNotifierProvider.family<
      SearchResultsNotifier,
      List<UserSearchResult>,
      String
    >(SearchResultsNotifier.new);

/// The Social surface's pending counter — received friend requests plus group
/// invites. It used to live in the retired nav shell; the slim build has no
/// nav bar, so the Social header badge owns it here next to its data sources.
final pendingCountsProvider = Provider<int>((ref) {
  final requests = ref.watch(
    friendRequestsProvider.select(
      (v) =>
          v.valueOrNull?.requests
              .where((r) => r.type == 'received')
              .length ??
          0,
    ),
  );
  final invites = ref.watch(
    groupInvitesProvider.select((v) => v.valueOrNull?.length ?? 0),
  );
  return requests + invites;
});
