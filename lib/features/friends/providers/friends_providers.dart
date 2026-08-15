import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/utils/throttled_refresh.dart';

/// Combined view of a user's friend requests: received + sent rows and the
/// display names of the users involved.
///
/// Names are fetched per user because the friendships table only stores ids;
/// the map is keyed by `user_id`.
///
/// No-fallback (2026-08-14): a friend whose profile cannot be resolved is
/// an ERROR, never a placeholder name — [build] throws and the screens
/// render the ErrorView + retry.
class FriendRequestsData {
  final List<Map<String, dynamic>> requests;
  final Map<String, String> names;

  const FriendRequestsData({required this.requests, required this.names});
}

class FriendsListNotifier extends AsyncNotifier<List<Map<String, dynamic>>>
    with ThrottledRefresh {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final repo = ref.read(friendsRepositoryProvider);
    final res = await repo.getFriends();
    final profiles = <Map<String, dynamic>>[];
    for (final f in res) {
      // No-fallback (2026-08-14): a friend with an unresolvable profile is
      // an ERROR — never silently dropped from the list.
      final profile = await repo.getUserProfile(f.userId);
      if (profile == null) {
        throw ProfileResolutionError(f.userId);
      }
      profiles.add(profile.toJson());
    }
    markFetched();
    return profiles;
  }

  /// Re-runs [build] to reload the friend list (finding SM-09). R20: skipped
  /// while the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Friends of the current user, as full user profiles.
final friendsListProvider = AsyncNotifierProvider<FriendsListNotifier,
    List<Map<String, dynamic>>>(FriendsListNotifier.new);

class FriendRequestsNotifier extends AsyncNotifier<FriendRequestsData>
    with ThrottledRefresh {
  @override
  Future<FriendRequestsData> build() async {
    final repo = ref.read(friendsRepositoryProvider);
    final requests = await repo.getFriendRequests();
    final names = <String, String>{};
    for (final r in requests) {
      final userId = r['user_id'] as String;
      if (names.containsKey(userId)) continue;
      // No-fallback (2026-08-14): an unresolvable or username-less profile is
      // an ERROR — never the "Usuario" placeholder.
      final profile = await repo.getUserProfile(userId);
      if (profile == null || profile.username.isEmpty) {
        throw ProfileResolutionError(userId);
      }
      names[userId] = profile.username;
    }
    markFetched();
    return FriendRequestsData(requests: requests, names: names);
  }

  /// Re-runs [build] after accepting/declining a request (finding SM-09).
  /// R20: skipped while the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Received + sent friend requests with resolved display names.
final friendRequestsProvider = AsyncNotifierProvider<FriendRequestsNotifier,
    FriendRequestsData>(FriendRequestsNotifier.new);

class BlockedUsersNotifier extends AsyncNotifier<List<Map<String, dynamic>>>
    with ThrottledRefresh {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final repo = ref.read(friendsRepositoryProvider);
    final res = await repo.getBlockedUsers();
    final profiles = <Map<String, dynamic>>[];
    for (final b in res) {
      final uid = b['blocked_user_id'] as String;
      // No-fallback (2026-08-14): an unresolvable blocked-user profile is an
      // ERROR — never a truncated-uid placeholder.
      final profile = await repo.getUserProfile(uid);
      if (profile == null) throw ProfileResolutionError(uid);
      profiles.add(profile.toJson());
    }
    markFetched();
    return profiles;
  }

  /// Re-runs [build] after unblocking a user (finding SM-09). R20: skipped
  /// while the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Users blocked by the current user (profiles with username fallback).
final blockedUsersProvider = AsyncNotifierProvider<BlockedUsersNotifier,
    List<Map<String, dynamic>>>(BlockedUsersNotifier.new);

class SearchResultsNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String>
    with ThrottledRefresh {
  @override
  Future<List<Map<String, dynamic>>> build(String arg) async {
    final results = await ref.read(friendsRepositoryProvider).searchUsers(arg);
    markFetched();
    return results;
  }

  /// Re-runs [build] after a friend request changes a result's status. R20:
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
final searchResultsProvider = AsyncNotifierProvider.family<SearchResultsNotifier,
    List<Map<String, dynamic>>, String>(SearchResultsNotifier.new);
