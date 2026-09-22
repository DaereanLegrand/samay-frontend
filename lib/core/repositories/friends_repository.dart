import 'package:samay/core/models/friend_request_summary.dart';
import 'package:samay/core/models/friendship.dart';
import 'package:samay/core/models/user_profile.dart';
import 'package:samay/core/models/user_search_result.dart';
import 'package:samay/core/services/discovery_service.dart';
import 'package:samay/core/services/friendship_service.dart';
import 'package:samay/core/services/user_service.dart';

/// Friends domain repository: thin, typed facade over
/// [FriendshipService] (friendship lifecycle) and [UserService] (profile
/// lookups for friend tiles).
///
/// Dependency direction doctrine (DEVELOPMENT-WORKFLOW §5): providers depend
/// on repositories, repositories on services, services on the Supabase client.
/// Feature providers must read this repository via `friendsRepositoryProvider`
/// (Riverpod) instead of the `SupabaseService.instance` singleton —
/// this is what makes the feature layer mockable at the service boundary.
///
/// Typed where the freezed models match the service shape
/// ([UserProfile], [FriendshipSummary]); raw `Map<String, dynamic>` rows are
/// passed through where the service enriches rows beyond the models
/// (`searchUsers` adds `friendship_status`/`hidden`; `getFriendRequests`
/// discriminates `received`/`sent`; `getFriendshipDetail` carries
/// `requester_id`; `getBlockedUsers` maps `blocked_user_id`).
class FriendsRepository {
  FriendsRepository({
    required UserService users,
    required FriendshipService friendships,
    required DiscoveryService discovery,
  })  : _users = users,
        _friendships = friendships,
        _discovery = discovery;

  final UserService _users;
  final FriendshipService _friendships;
  final DiscoveryService _discovery;

  /// The full profile of [userId], or null when the row does not exist.
  Future<UserProfile?> getUserProfile(String userId) async {
    final res = await _users.getUserProfile(userId);
    return res == null ? null : UserProfile.fromJson(res);
  }

  /// Accepted friendships of the current user.
  Future<List<FriendshipSummary>> getFriends() async {
    final res = await _friendships.getFriends();
    return [for (final f in res) FriendshipSummary.fromJson(f)];
  }

  /// Profiles of [userIds] in ONE `user_search_view` read — the batch form of
  /// [getUserProfile] for the non-own-row branch. Rows with no visible profile
  /// are absent from the result.
  Future<List<Map<String, dynamic>>> getUserProfiles(List<String> userIds) =>
      _users.getUserProfiles(userIds);

  /// Search-shaped profile rows for [ids] via the `get_friend_profiles`
  /// SECURITY DEFINER RPC — ONE batched query (no N+1), scoped to the caller's
  /// accepted friends. Friends that cannot be resolved are simply absent. Used
  /// by the on-device friends-cache warm-up so one unresolvable friend can
  /// never abort the whole cache.
  Future<List<Map<String, dynamic>>> getUserSearchRows(List<String> ids) async {
    if (ids.isEmpty) return const [];
    return _friendships.getFriendProfiles(ids);
  }

  /// Search results for [query], carrying the service's `friendship_status`
  /// / `friendship_id` / `friendship_direction` enrichment.
  Future<List<UserSearchResult>> searchUsers(String query) async {
    final res = await _discovery.searchUsers(query);
    return [for (final r in res) UserSearchResult.fromJson(r)];
  }

  /// Received + sent friend requests (typed with `type`/`friendship_id`/
  /// `user_id`/`created_at`).
  Future<List<FriendRequestSummary>> getFriendRequests() async {
    final res = await _friendships.getFriendRequests();
    return [for (final r in res) FriendRequestSummary.fromJson(r)];
  }

  /// Users blocked by the current user (`blocked_user_id` rows).
  Future<List<Map<String, dynamic>>> getBlockedUsers() =>
      _friendships.getBlockedUsers();

  /// Whether the current user has an active block against [userId].
  Future<bool> getBlockStatus(String userId) =>
      _friendships.getBlockStatus(userId);

  /// The friendship status against [userId] (`pending`/`accepted`/`blocked`)
  /// or null when no friendship row exists.
  Future<String?> getFriendshipStatus(String userId) =>
      _friendships.getFriendshipStatus(userId);

  Future<String?> getFriendshipIdForUser(String userId) =>
      _friendships.getFriendshipIdForUser(userId);

  /// The latest friendship row against [userId] (`id`/`status`/
  /// `requester_id` — Map passthrough; `requester_id` is not modeled).
  Future<Map<String, dynamic>?> getFriendshipDetail(String userId) =>
      _friendships.getFriendshipDetail(userId);

  /// Sends a friend request to [userId], returning `pending` (new request)
  /// or `accepted` (the addressee already had a pending request against the
  /// current user — instant mutual accept).
  Future<String> sendFriendRequest(String userId) =>
      _friendships.sendFriendRequest(userId);

  Future<void> acceptFriendRequest(String friendshipId) =>
      _friendships.acceptFriendRequest(friendshipId);

  Future<void> declineFriendRequest(String friendshipId) =>
      _friendships.declineFriendRequest(friendshipId);

  Future<void> blockUser(String userId) => _friendships.blockUser(userId);

  Future<void> unblockUser(String userId) => _friendships.unblockUser(userId);

  Future<void> removeFriend(String friendshipId) =>
      _friendships.removeFriend(friendshipId);
}
