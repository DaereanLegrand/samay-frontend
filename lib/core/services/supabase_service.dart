import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

  Future<String?> getFriendshipStatus(String userId) async {
    final user = auth.currentUser;
    if (user == null) return null;
    final res = await client
        .from('friendships')
        .select('status')
        .or('and(requester_id.eq.${user.id},addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.${user.id})')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return res?['status'] as String?;
  }

  Future<String?> getFriendshipIdForUser(String userId) async {
    final user = auth.currentUser;
    if (user == null) return null;
    final res = await client
        .from('friendships')
        .select('id')
        .or('and(requester_id.eq.${user.id},addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.${user.id})')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return res?['id'] as String?;
  }

  Future<Map<String, dynamic>?> getFriendshipDetail(String userId) async {
    final user = auth.currentUser;
    if (user == null) return null;
    final res = await client
        .from('friendships')
        .select('id, status, requester_id')
        .or('and(requester_id.eq.${user.id},addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.${user.id})')
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return res != null ? Map<String, dynamic>.from(res) : null;
  }

  Future<void> sendFriendRequest(String userId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final existing = await client
        .from('friendships')
        .select('id')
        .or('and(requester_id.eq.${user.id},addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.${user.id})')
        .limit(1)
        .maybeSingle();
    if (existing != null) throw Exception('Ya existe una solicitud o amistad con este usuario');
    await client.from('friendships').insert({
      'requester_id': user.id,
      'addressee_id': userId,
      'status': 'pending',
    });
  }

  Future<void> acceptFriendRequest(String friendshipId) async {
    await client
        .from('friendships')
        .update({'status': 'accepted'})
        .eq('id', friendshipId);
  }

  Future<void> declineFriendRequest(String friendshipId) async {
    await client.from('friendships').delete().eq('id', friendshipId);
  }

  Future<void> blockUser(String userId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final existing = await client
        .from('friendships')
        .select('id')
        .or('and(requester_id.eq.${user.id},addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.${user.id})')
        .maybeSingle();
    if (existing != null) {
      await client
          .from('friendships')
          .update({'status': 'blocked'})
          .eq('id', existing['id'] as String);
    } else {
      await client.from('friendships').insert({
        'requester_id': user.id,
        'addressee_id': userId,
        'status': 'blocked',
      });
    }
  }

  Future<void> unblockUser(String userId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final existing = await client
        .from('friendships')
        .select('id')
        .or('and(requester_id.eq.${user.id},addressee_id.eq.$userId),and(requester_id.eq.$userId,addressee_id.eq.${user.id})')
        .maybeSingle();
    if (existing != null) {
      await client.from('friendships').delete().eq('id', existing['id'] as String);
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final user = auth.currentUser;
    final res = await client
        .from('users')
        .select('id, username, display_name, avatar_url')
        .ilike('username', '$query%')
        .neq('id', user?.id ?? '')
        .isFilter('deleted_at', null)
        .limit(20);
    final results = res.map((e) => Map<String, dynamic>.from(e)).toList();

    if (results.isEmpty || user == null) return results;

    final ids = results.map((r) => r['id'] as String).toList();
    final frRows = await client
        .from('friendships')
        .select('requester_id, addressee_id, status')
        .or('and(requester_id.eq.${user.id},addressee_id.in.(${ids.join(',')})),and(requester_id.in.(${ids.join(',')}),addressee_id.eq.${user.id})');

    final blockedByMe = <String>{};
    final blockedByThem = <String>{};
    final statusByUser = <String, String>{};
    for (final row in frRows) {
      final otherId = row['requester_id'] == user.id
          ? row['addressee_id'] as String
          : row['requester_id'] as String;
      final status = row['status'] as String;
      statusByUser[otherId] = status;
      if (status == 'blocked') {
        if (row['requester_id'] == user.id) {
          blockedByMe.add(otherId);
        } else {
          blockedByThem.add(otherId);
        }
      }
    }

    return results
        .where((r) => !blockedByMe.contains(r['id']))
        .map((r) {
          final uid = r['id'] as String;
          final frStatus = statusByUser[uid];
          if (frStatus != null) {
            r['friendship_status'] = frStatus;
          }
          if (blockedByThem.contains(uid)) {
            r['hidden'] = true;
          }
          return r;
        })
        .where((r) => r['hidden'] != true)
        .toList();
  }

  Future<List<Map<String, dynamic>>> getFriends() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, created_at')
        .or('and(requester_id.eq.${user.id},status.eq.accepted),and(addressee_id.eq.${user.id},status.eq.accepted)');
    final friends = <Map<String, dynamic>>[];
    for (final row in res) {
      final friendId = row['requester_id'] == user.id ? row['addressee_id'] as String : row['requester_id'] as String;
      friends.add({'friendship_id': row['id'], 'user_id': friendId});
    }
    return friends;
  }

  Future<void> removeFriend(String friendshipId) async {
    await client.from('friendships').delete().eq('id', friendshipId);
  }

  Future<List<Map<String, dynamic>>> getFriendRequests() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final received = await client
        .from('friendships')
        .select('id, requester_id, created_at')
        .eq('addressee_id', user.id)
        .eq('status', 'pending');
    final sent = await client
        .from('friendships')
        .select('id, addressee_id, created_at')
        .eq('requester_id', user.id)
        .eq('status', 'pending');
    return [
      for (final r in received)
        {'type': 'received', 'friendship_id': r['id'], 'user_id': r['requester_id'], 'created_at': r['created_at']},
      for (final s in sent)
        {'type': 'sent', 'friendship_id': s['id'], 'user_id': s['addressee_id'], 'created_at': s['created_at']},
    ];
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('friendships')
        .select('id, requester_id, addressee_id, status');
    return res
        .where((e) => e['status'] == 'blocked' && e['requester_id'] == user.id)
        .map((e) => {'blocked_user_id': e['addressee_id']})
        .toList();
  }

  Future<bool> getBlockStatus(String userId) async {
    final user = auth.currentUser;
    if (user == null) return false;
    final res = await client
        .from('friendships')
        .select('id')
        .or('and(requester_id.eq.${user.id},addressee_id.eq.$userId,status.eq.blocked),and(requester_id.eq.$userId,addressee_id.eq.${user.id},status.eq.blocked)')
        .maybeSingle();
    return res != null;
  }

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final groupId = const Uuid().v4();

    await client.from('groups').insert({
      'id': groupId,
      'name': data['name'],
      'description': data['description'],
      'cover_url': data['cover_url'],
      'created_by_user_id': user.id,
    });

    await client.from('group_members').insert({
      'group_id': groupId,
      'user_id': user.id,
      'role': 'promotor',
    });

    await client.from('chats').insert({
      'type': 'group',
      'reference_id': groupId,
    });

    return {
      'id': groupId,
      'name': data['name'],
      'description': data['description'],
    };
  }

  Future<void> joinGroup(String groupId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client.from('group_members').insert({
      'group_id': groupId,
      'user_id': user.id,
      'role': 'member',
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', user.id);
  }

  Future<Map<String, dynamic>?> getGroup(String groupId) async {
    final res = await client.from('groups').select().eq('id', groupId).maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final res = await client
        .from('group_members')
        .select('id, user_id, role, joined_at')
        .eq('group_id', groupId);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> updateGroup(String groupId, Map<String, dynamic> patch) async {
    await client.from('groups').update(patch).eq('id', groupId);
  }

  Future<void> kickMember(String groupId, String userId) async {
    await client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<void> transferPromotor(String groupId, String newPromotorId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client
        .from('group_members')
        .update({'role': 'co_promotor'})
        .eq('group_id', groupId)
        .eq('user_id', user.id)
        .eq('role', 'promotor');
    await client
        .from('group_members')
        .update({'role': 'promotor'})
        .eq('group_id', groupId)
        .eq('user_id', newPromotorId);
  }

  Future<void> setMemberRole(String groupId, String userId, String role) async {
    await client
        .from('group_members')
        .update({'role': role})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<int> getUserGroupCount() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('group_members')
        .select('id')
        .eq('user_id', user.id)
        .eq('role', 'promotor');
    return res.length;
  }

  Future<List<Map<String, dynamic>>> getMyGroups() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final memberships = await client
        .from('group_members')
        .select('group_id, role')
        .eq('user_id', user.id);
    if (memberships.isEmpty) return [];
    final groupIds = memberships.map((m) => m['group_id'] as String).toList();
    final groups = await client
        .from('groups')
        .select()
        .inFilter('id', groupIds);
    for (final g in groups) {
      final m = memberships.firstWhere((m) => m['group_id'] == g['id']);
      g['my_role'] = m['role'];
    }
    return groups.map((e) => Map<String, dynamic>.from(e)).toList();
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
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final userRes = await client.from('users').select('personal_shards').eq('id', user.id).single();
    final currentShards = userRes['personal_shards'] as int;
    if (currentShards < amount) throw Exception('No tienes suficientes shards');

    final config = await fetchAppConfig();
    final boostDays = int.parse(config['economy.group_shard_boost_days'] ?? '14');
    final now = DateTime.now();

    await client.rpc('donate_shards_to_group', params: {
      'p_group_id': groupId,
      'p_user_id': user.id,
      'p_amount': amount,
      'p_expires_at': now.add(Duration(days: boostDays)).toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getGroupContributions(String groupId) async {
    final res = await client
        .from('group_shard_contributions')
        .select('id, user_id, shards_contributed, contributed_at, expires_at')
        .eq('group_id', groupId)
        .gt('expires_at', DateTime.now().toIso8601String())
        .order('shards_contributed', ascending: false);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<int> getUserContributionToGroup(String groupId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('group_shard_contributions')
        .select('shards_contributed')
        .eq('group_id', groupId)
        .eq('user_id', user.id)
        .gt('expires_at', DateTime.now().toIso8601String());
    int total = 0;
    for (final row in res) {
      total += row['shards_contributed'] as int;
    }
    return total;
  }

  Future<void> purchaseCosmetic(String cosmeticId) async {
    throw UnimplementedError('purchaseCosmetic');
  }

  Future<void> reportContent(String targetType, String targetId, String reason) async {
    throw UnimplementedError('reportContent');
  }

  Future<List<Map<String, dynamic>>> getLeaderboard(String sizeTier) async {
    final res = await client
        .from('group_rank_snapshots')
        .select('group_id, rank_position, score, member_count')
        .eq('size_tier', sizeTier)
        .order('rank_position', ascending: true)
        .limit(100);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final res = await client
        .from('users')
        .select('id, username, display_name, avatar_url, bio, personal_shards')
        .eq('id', userId)
        .maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
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
