import 'package:samay/core/services/auth_service.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/core/services/config_service.dart';
import 'package:samay/core/services/event_service.dart';
import 'package:samay/core/services/group_service.dart';
import 'package:samay/core/services/media_service.dart';
import 'package:samay/core/services/moderation_service.dart';
import 'package:samay/core/services/notification_service.dart';
import 'package:samay/core/services/realtime_service.dart';
import 'package:samay/core/services/shards_service.dart';
import 'package:samay/core/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// DEPRECATED — thin facade over the decomposed feature services.
///
/// ## Decomposition (ARC-05 / CQ-01 / M-38 — agent I-11)
///
/// The former 936-line monolith was split into focused, injectable services
/// (all in `lib/core/services/`):
///
/// | Service | File | Domain |
/// |---------|------|--------|
/// | [AuthService] | auth_service.dart | signup/OTP/session/profile-row helpers |
/// | [UserService] | user_service.dart | profiles, friendships, search |
/// | [GroupService] | group_service.dart | groups, memberships, invites, roles |
/// | [EventService] | event_service.dart | events + photo likes |
/// | [ChatService] | chat_service.dart | messages (E2EE seam for I-38) |
/// | [NotificationService] | notification_service.dart | notifications |
/// | [ShardsService] | shards_service.dart | shard economy, cosmetics, leaderboard |
/// | [ModerationService] | moderation_service.dart | content reports |
/// | [MediaService] | media_service.dart | storage uploads + signed URLs |
/// | [RealtimeService] | realtime_service.dart | realtime subscriptions |
/// | [ConfigService] | config_service.dart | app_config reads |
///
/// This class only re-exports the legacy API so the 50+ existing call sites
/// keep working while feature agents migrate incrementally. New code must use
/// the service providers in `lib/core/providers/service_providers.dart`
/// instead. **Delete this facade at STOP-100 once all call sites have
/// migrated** (I-11 follow-up).
///
/// The singleton pattern is retained for the facade only; the services
/// themselves are plain injectable classes (see their constructors).
class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;

  late final ConfigService _configService = ConfigService(client: client);
  late final AuthService _authService = AuthService(client: client, config: _configService);
  late final UserService _userService = UserService(client: client);
  late final GroupService _groupService = GroupService(client: client);
  late final EventService _eventService = EventService(client: client);
  late final RealtimeService _realtimeService = RealtimeService(client: client);
  late final ChatService _chatService = ChatService(client: client, realtime: _realtimeService);
  late final NotificationService _notificationService = NotificationService(client: client, realtime: _realtimeService);
  late final ShardsService _shardsService = ShardsService(client: client, config: _configService);
  late final ModerationService _moderationService = ModerationService(client: client);
  late final MediaService _mediaService = MediaService(client: client);

  /// Decomposed services (exposed for wiring; prefer the Riverpod providers
  /// in `lib/core/providers/service_providers.dart`).
  AuthService get authService => _authService;
  UserService get userService => _userService;
  GroupService get groupService => _groupService;
  EventService get eventService => _eventService;
  ChatService get chatService => _chatService;
  NotificationService get notificationService => _notificationService;
  ShardsService get shardsService => _shardsService;
  ModerationService get moderationService => _moderationService;
  MediaService get mediaService => _mediaService;
  RealtimeService get realtimeService => _realtimeService;
  ConfigService get configService => _configService;

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  Future<String> checkSignupEmail(String email) async =>
      _authService.checkSignupEmail(email);

  Future<void> upsertSignupTracker(String email, bool profileCreated) async =>
      _authService.upsertSignupTracker(email, profileCreated);

  Future<void> signIn(String email, String password) async =>
      _authService.signIn(email, password);

  Future<void> signUp(String email, String password) async =>
      _authService.signUp(email, password);

  Future<void> signOut() async => _authService.signOut();

  Future<void> sendOtp(String email) async => _authService.sendOtp(email);

  Future<void> verifyOtp(String email, String token) async =>
      _authService.verifyOtp(email, token);

  Map<String, dynamic>? getCurrentUser() => _authService.getCurrentUser();

  Future<Map<String, dynamic>?> refreshSession() async =>
      _authService.refreshSession();

  Future<void> updateUser(Map<String, dynamic> patch) async =>
      _authService.updateUser(patch);

  Future<void> softDeleteUser() async => _authService.softDeleteUser();

  Future<void> createUserProfile({
    required String username,
    String? avatarUrl,
    String? dateOfBirth,
  }) async =>
      _authService.createUserProfile(
        username: username,
        avatarUrl: avatarUrl,
        dateOfBirth: dateOfBirth,
      );

  // ---------------------------------------------------------------------------
  // Users / friendships
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>?> getUserProfile(String userId) async =>
      _userService.getUserProfile(userId);

  Future<String?> getFriendshipStatus(String userId) async =>
      _userService.getFriendshipStatus(userId);

  Future<String?> getFriendshipIdForUser(String userId) async =>
      _userService.getFriendshipIdForUser(userId);

  Future<Map<String, dynamic>?> getFriendshipDetail(String userId) async =>
      _userService.getFriendshipDetail(userId);

  Future<void> sendFriendRequest(String userId) async =>
      _userService.sendFriendRequest(userId);

  Future<void> acceptFriendRequest(String friendshipId) async =>
      _userService.acceptFriendRequest(friendshipId);

  Future<void> declineFriendRequest(String friendshipId) async =>
      _userService.declineFriendRequest(friendshipId);

  Future<void> blockUser(String userId) async => _userService.blockUser(userId);

  Future<void> unblockUser(String userId) async => _userService.unblockUser(userId);

  Future<List<Map<String, dynamic>>> searchUsers(String query) async =>
      _userService.searchUsers(query);

  Future<List<Map<String, dynamic>>> getFriends() async => _userService.getFriends();

  Future<void> removeFriend(String friendshipId) async =>
      _userService.removeFriend(friendshipId);

  Future<List<Map<String, dynamic>>> getFriendRequests() async =>
      _userService.getFriendRequests();

  Future<List<Map<String, dynamic>>> getBlockedUsers() async =>
      _userService.getBlockedUsers();

  Future<bool> getBlockStatus(String userId) async =>
      _userService.getBlockStatus(userId);

  // ---------------------------------------------------------------------------
  // Groups
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async =>
      _groupService.createGroup(data);

  Future<void> joinGroup(String groupId) async => _groupService.joinGroup(groupId);

  Future<void> leaveGroup(String groupId) async => _groupService.leaveGroup(groupId);

  Future<Map<String, dynamic>?> getGroup(String groupId) async =>
      _groupService.getGroup(groupId);

  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async =>
      _groupService.getGroupMembers(groupId);

  Future<List<Map<String, dynamic>>> getGroupInvites() async =>
      _groupService.getGroupInvites();

  Future<void> acceptGroupInvite(String membershipId) async =>
      _groupService.acceptGroupInvite(membershipId);

  Future<void> declineGroupInvite(String membershipId) async =>
      _groupService.declineGroupInvite(membershipId);

  Future<void> updateGroup(String groupId, Map<String, dynamic> patch) async =>
      _groupService.updateGroup(groupId, patch);

  Future<void> kickMember(String groupId, String userId) async =>
      _groupService.kickMember(groupId, userId);

  Future<void> transferPromotor(String groupId, String newPromotorId) async =>
      _groupService.transferPromotor(groupId, newPromotorId);

  Future<void> setMemberRole(String groupId, String userId, String role) async =>
      _groupService.setMemberRole(groupId, userId, role);

  Future<int> getUserGroupCount() async => _groupService.getUserGroupCount();

  Future<List<Map<String, dynamic>>> getMyGroups() async =>
      _groupService.getMyGroups();

  // ---------------------------------------------------------------------------
  // Events
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data) async =>
      _eventService.createEvent(data);

  Future<List<Map<String, dynamic>>> listEvents([String? status, String? type]) async =>
      _eventService.listEvents(status, type);

  Future<Map<String, dynamic>> getEvent(String id) async =>
      _eventService.getEvent(id);

  Future<void> updateEvent(String id, Map<String, dynamic> patch) async =>
      _eventService.updateEvent(id, patch);

  Future<void> likePhoto(String photoId) async => _eventService.likePhoto(photoId);

  // ---------------------------------------------------------------------------
  // Chat
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> loadMessages(String chatId, {int limit = 50, int offset = 0}) async =>
      _chatService.loadMessages(chatId, limit: limit, offset: offset);

  Future<void> sendMessage(String chatId, String content, String? mediaUrl) async =>
      _chatService.sendMessage(chatId, content, mediaUrl);

  // ---------------------------------------------------------------------------
  // Photos (storage)
  // ---------------------------------------------------------------------------

  Future<void> uploadPhoto(String eventId, String filePath) async =>
      _mediaService.uploadEventPhoto(eventId, filePath);

  Future<String> getSignedPhotoUrl(String storagePath) async =>
      _mediaService.getSignedPhotoUrl(storagePath);

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  Future<List<Map<String, dynamic>>> getNotifications() async =>
      _notificationService.getNotifications();

  Future<void> markNotificationRead(String id) async =>
      _notificationService.markNotificationRead(id);

  // ---------------------------------------------------------------------------
  // Shards / cosmetics / leaderboard
  // ---------------------------------------------------------------------------

  Future<void> donateToGroup(String groupId, int amount) async =>
      _shardsService.donateToGroup(groupId, amount);

  Future<List<Map<String, dynamic>>> getGroupContributions(String groupId) async =>
      _shardsService.getGroupContributions(groupId);

  Future<int> getUserContributionToGroup(String groupId) async =>
      _shardsService.getUserContributionToGroup(groupId);

  Future<void> purchaseCosmetic(String cosmeticId) async =>
      _shardsService.purchaseCosmetic(cosmeticId);

  Future<List<Map<String, dynamic>>> getLeaderboard(String sizeTier) async =>
      _shardsService.getLeaderboard(sizeTier);

  // ---------------------------------------------------------------------------
  // Moderation
  // ---------------------------------------------------------------------------

  Future<void> reportContent(String targetType, String targetId, String reason) async =>
      _moderationService.reportContent(targetType, targetId, reason);

  // ---------------------------------------------------------------------------
  // Config
  // ---------------------------------------------------------------------------

  Future<Map<String, String>> fetchAppConfig() async =>
      _configService.fetchAppConfig();

  Future<int> getSignupShardGrant() async => _configService.getSignupShardGrant();

  // ---------------------------------------------------------------------------
  // Realtime
  // ---------------------------------------------------------------------------

  /// Sync by design (I-38): the underlying [RealtimeService.subscribeToMessages]
  /// returns the [RealtimeChannel] so callers can unsubscribe on dispose; the
  /// facade must not swallow it behind a `Future<void>`.
  RealtimeChannel subscribeToMessages(String chatId, void Function(Map<String, dynamic>) onInsert) =>
      _realtimeService.subscribeToMessages(chatId, onInsert);

  Future<void> subscribeToNotifications(void Function(Map<String, dynamic>) onInsert) async =>
      _realtimeService.subscribeToNotifications(onInsert);

  Future<void> subscribeToEventStatus(String eventId, void Function(String) onChange) async =>
      _realtimeService.subscribeToEventStatus(eventId, onChange);

  Future<void> subscribeToQRToken(String eventId, void Function(String) onUpdate) async =>
      _realtimeService.subscribeToQRToken(eventId, onUpdate);

  // ---------------------------------------------------------------------------
  // Generic edge-function invocation (future ApiService)
  // ---------------------------------------------------------------------------

  Future<Map<String, dynamic>> callEdgeFunction(String name, Map<String, dynamic> body) async {
    try {
      final res = await client.functions.invoke(name, body: body);
      if (res.data != null) {
        return Map<String, dynamic>.from(res.data as Map);
      }
      throw Exception('Edge Function returned no data');
    } on FunctionException catch (e) {
      throw Exception('Edge Function error (${e.status}): ${e.details}');
    }
  }
}
