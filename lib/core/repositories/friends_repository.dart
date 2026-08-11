import 'package:samay/core/models/friendship.dart';
import 'package:samay/core/models/user_profile.dart';
import 'package:samay/core/services/user_service.dart';

/// Friends domain repository (I-50): thin, typed facade over [UserService].
///
/// Dependency direction doctrine (DEVELOPMENT-WORKFLOW §5): providers depend
/// on repositories, repositories on services, services on the Supabase client.
/// Feature providers must read this repository via `friendsRepositoryProvider`
/// (Riverpod) instead of the legacy `SupabaseService.instance` singleton —
/// this is what makes the feature layer mockable at the service boundary.
///
/// Typed where the I-10 freezed models match the service shape
/// ([UserProfile], [FriendshipSummary]); raw `Map<String, dynamic>` rows are
/// passed through where the service enriches rows beyond the models
/// (`searchUsers` adds `friendship_status`/`hidden`; `getFriendRequests`
/// discriminates `received`/`sent`; `getFriendshipDetail` carries
/// `requester_id`; `getBlockedUsers` maps `blocked_user_id`).
class FriendsRepository {
  FriendsRepository({required UserService users}) : _users = users;

  final UserService _users;

  /// The full profile of [userId], or null when the row does not exist.
  Future<UserProfile?> getUserProfile(String userId) async {
    final res = await _users.getUserProfile(userId);
    return res == null ? null : UserProfile.fromJson(res);
  }

  /// Accepted friendships of the current user.
  Future<List<FriendshipSummary>> getFriends() async {
    final res = await _users.getFriends();
    return [for (final f in res) FriendshipSummary.fromJson(f)];
  }

  /// Search results for [query], carrying the service's `friendship_status`
  /// / `hidden` enrichment (not modeled — Map passthrough).
  Future<List<Map<String, dynamic>>> searchUsers(String query) =>
      _users.searchUsers(query);

  /// Received + sent friend requests (rows carry `type`/`friendship_id`/
  /// `user_id`/`created_at` — Map passthrough).
  Future<List<Map<String, dynamic>>> getFriendRequests() =>
      _users.getFriendRequests();

  /// Users blocked by the current user (`blocked_user_id` rows).
  Future<List<Map<String, dynamic>>> getBlockedUsers() =>
      _users.getBlockedUsers();

  /// Whether the current user has an active block against [userId].
  Future<bool> getBlockStatus(String userId) => _users.getBlockStatus(userId);

  /// The friendship status against [userId] (`pending`/`accepted`/`blocked`)
  /// or null when no friendship row exists.
  Future<String?> getFriendshipStatus(String userId) =>
      _users.getFriendshipStatus(userId);

  Future<String?> getFriendshipIdForUser(String userId) =>
      _users.getFriendshipIdForUser(userId);

  /// The latest friendship row against [userId] (`id`/`status`/
  /// `requester_id` — Map passthrough; `requester_id` is not modeled).
  Future<Map<String, dynamic>?> getFriendshipDetail(String userId) =>
      _users.getFriendshipDetail(userId);

  /// Sends a friend request to [userId], returning `pending` (new request)
  /// or `accepted` (the addressee already had a pending request against the
  /// current user — instant mutual accept, R15).
  Future<String> sendFriendRequest(String userId) =>
      _users.sendFriendRequest(userId);

  Future<void> acceptFriendRequest(String friendshipId) =>
      _users.acceptFriendRequest(friendshipId);

  Future<void> declineFriendRequest(String friendshipId) =>
      _users.declineFriendRequest(friendshipId);

  Future<void> blockUser(String userId) => _users.blockUser(userId);

  Future<void> unblockUser(String userId) => _users.unblockUser(userId);

  Future<void> removeFriend(String friendshipId) =>
      _users.removeFriend(friendshipId);
}
