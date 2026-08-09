import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/services/supabase_service.dart';

/// Combined view of a user's friend requests: received + sent rows and the
/// display names of the users involved.
///
/// Names are fetched per user because the friendships table only stores ids;
/// the map is keyed by `user_id`.
class FriendRequestsData {
  final List<Map<String, dynamic>> requests;
  final Map<String, String> names;

  const FriendRequestsData({required this.requests, required this.names});
}

class FriendsListNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final res = await SupabaseService.instance.getFriends();
    final profiles = <Map<String, dynamic>>[];
    for (final f in res) {
      final profile = await SupabaseService.instance
          .getUserProfile(f['user_id'] as String);
      if (profile != null) profiles.add(profile);
    }
    return profiles;
  }

  /// Re-runs [build] to reload the friend list (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Friends of the current user, as full user profiles.
final friendsListProvider = AsyncNotifierProvider<FriendsListNotifier,
    List<Map<String, dynamic>>>(FriendsListNotifier.new);

class FriendRequestsNotifier extends AsyncNotifier<FriendRequestsData> {
  @override
  Future<FriendRequestsData> build() async {
    final requests = await SupabaseService.instance.getFriendRequests();
    final names = <String, String>{};
    for (final r in requests) {
      final userId = r['user_id'] as String;
      if (names.containsKey(userId)) continue;
      final profile = await SupabaseService.instance.getUserProfile(userId);
      names[userId] = profile?['username'] as String? ?? 'Usuario';
    }
    return FriendRequestsData(requests: requests, names: names);
  }

  /// Re-runs [build] after accepting/declining a request (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Received + sent friend requests with resolved display names.
final friendRequestsProvider = AsyncNotifierProvider<FriendRequestsNotifier,
    FriendRequestsData>(FriendRequestsNotifier.new);

class BlockedUsersNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final res = await SupabaseService.instance.getBlockedUsers();
    final profiles = <Map<String, dynamic>>[];
    for (final b in res) {
      final uid = b['blocked_user_id'] as String;
      final profile = await SupabaseService.instance.getUserProfile(uid);
      if (profile != null) {
        profiles.add(profile);
      } else {
        profiles.add({
          'id': uid,
          'username': uid.substring(0, uid.length < 8 ? uid.length : 8),
          'avatar_url': null,
        });
      }
    }
    return profiles;
  }

  /// Re-runs [build] after unblocking a user (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Users blocked by the current user (profiles with username fallback).
final blockedUsersProvider = AsyncNotifierProvider<BlockedUsersNotifier,
    List<Map<String, dynamic>>>(BlockedUsersNotifier.new);

class SearchResultsNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String> {
  @override
  Future<List<Map<String, dynamic>>> build(String arg) async {
    return SupabaseService.instance.searchUsers(arg);
  }

  /// Re-runs [build] after a friend request changes a result's status.
  Future<void> refresh() async => ref.invalidateSelf();
}

/// User search results for a query (family keyed by the trimmed query).
///
/// Consumers must not watch this provider with an empty query — the search
/// service would query with an empty prefix.
final searchResultsProvider = AsyncNotifierProvider.family<SearchResultsNotifier,
    List<Map<String, dynamic>>, String>(SearchResultsNotifier.new);
