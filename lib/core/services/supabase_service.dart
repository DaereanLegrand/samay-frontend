import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;

  Future<void> signIn(String email, String password) async {
    await auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signUp(String email, String password) async {
    await auth.signUp(email: email, password: password);
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  Future<void> sendOtp(String email) async {
    await auth.signInWithOtp(email: email);
  }

  Future<void> verifyOtp(String email, String token) async {
    await auth.verifyOTP(email: email, token: token, type: OtpType.email);
  }

  Map<String, dynamic>? getCurrentUser() {
    final user = auth.currentUser;
    if (user == null) return null;
    return user.toJson();
  }

  Future<void> updateUser(Map<String, dynamic> patch) async {
    await auth.updateUser(
      UserAttributes(
        email: patch['email'] as String?,
        password: patch['password'] as String?,
        data: patch['data'] as Map<String, dynamic>?,
      ),
    );
  }

  Future<void> softDeleteUser() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client
        .from('users')
        .update({
          'deleted_at': DateTime.now().toIso8601String(),
          'username': 'deleted_user_${user.id}',
          'avatar_url': null,
          'bio': null,
        })
        .eq('id', user.id);
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data) async {
    throw UnimplementedError('createEvent');
  }

  Future<List<Map<String, dynamic>>> listEvents([String? status, String? type]) async {
    throw UnimplementedError('listEvents');
  }

  Future<Map<String, dynamic>> getEvent(String id) async {
    throw UnimplementedError('getEvent');
  }

  Future<void> updateEvent(String id, Map<String, dynamic> patch) async {
    throw UnimplementedError('updateEvent');
  }

  Future<void> sendFriendRequest(String userId) async {
    throw UnimplementedError('sendFriendRequest');
  }

  Future<void> acceptFriendRequest(String friendshipId) async {
    throw UnimplementedError('acceptFriendRequest');
  }

  Future<void> declineFriendRequest(String friendshipId) async {
    throw UnimplementedError('declineFriendRequest');
  }

  Future<void> blockUser(String userId) async {
    throw UnimplementedError('blockUser');
  }

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    throw UnimplementedError('createGroup');
  }

  Future<void> joinGroup(String groupId) async {
    throw UnimplementedError('joinGroup');
  }

  Future<void> leaveGroup(String groupId) async {
    throw UnimplementedError('leaveGroup');
  }

  Future<List<Map<String, dynamic>>> loadMessages(String chatId, {int limit = 50, int offset = 0}) async {
    throw UnimplementedError('loadMessages');
  }

  Future<void> sendMessage(String chatId, String content, String? mediaUrl) async {
    throw UnimplementedError('sendMessage');
  }

  Future<void> uploadPhoto(String eventId, String filePath) async {
    throw UnimplementedError('uploadPhoto');
  }

  Future<String> getSignedPhotoUrl(String storagePath) async {
    throw UnimplementedError('getSignedPhotoUrl');
  }

  Future<void> likePhoto(String photoId) async {
    throw UnimplementedError('likePhoto');
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    throw UnimplementedError('getNotifications');
  }

  Future<void> markNotificationRead(String id) async {
    throw UnimplementedError('markNotificationRead');
  }

  Future<void> donateToGroup(String groupId, int amount) async {
    throw UnimplementedError('donateToGroup');
  }

  Future<void> purchaseCosmetic(String cosmeticId) async {
    throw UnimplementedError('purchaseCosmetic');
  }

  Future<void> reportContent(String targetType, String targetId, String reason) async {
    throw UnimplementedError('reportContent');
  }

  Future<Map<String, String>> fetchAppConfig() async {
    final res = await client.from('app_config').select('key, value');
    final map = <String, String>{};
    for (final row in res) {
      map[row['key'] as String] = row['value'] as String;
    }
    return map;
  }

  Future<int> getSignupShardGrant() async {
    try {
      final config = await fetchAppConfig();
      return int.parse(config['economy.user_signup_shards'] ?? '256');
    } catch (_) {
      return 256;
    }
  }

  Future<void> createUserProfile({
    required String username,
    required String displayName,
    String? avatarUrl,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final shards = await getSignupShardGrant();
    final now = DateTime.now().toIso8601String();

    await client.from('users').insert({
      'id': user.id,
      'username': username,
      'display_name': displayName,
      'avatar_url': avatarUrl,
      'date_of_birth': null,
      'bio': null,
      'banned_at': null,
      'ban_reason': null,
      'deleted_at': null,
      'personal_shards': shards,
      'preshards': 0,
      'subscription_tier': 'free',
      'subscription_expires_at': null,
      'created_at': now,
      'updated_at': now,
    });

    await client.from('shard_ledger').insert({
      'user_id': user.id,
      'delta': shards,
      'reason': 'admin_grant',
      'reference_id': null,
      'created_at': now,
    });
  }

  Future<void> subscribeToMessages(String chatId, void Function(Map<String, dynamic>) onInsert) async {
    throw UnimplementedError('subscribeToMessages');
  }

  Future<void> subscribeToNotifications(void Function(Map<String, dynamic>) onInsert) async {
    throw UnimplementedError('subscribeToNotifications');
  }

  Future<void> subscribeToEventStatus(String eventId, void Function(String) onChange) async {
    throw UnimplementedError('subscribeToEventStatus');
  }

  Future<void> subscribeToQRToken(String eventId, void Function(String) onUpdate) async {
    throw UnimplementedError('subscribeToQRToken');
  }

  Future<Map<String, dynamic>> callEdgeFunction(String name, Map<String, dynamic> body) async {
    throw UnimplementedError('callEdgeFunction');
  }
}
