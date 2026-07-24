import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  SupabaseService._();
  static final SupabaseService instance = SupabaseService._();

  SupabaseClient get client => Supabase.instance.client;
  GoTrueClient get auth => client.auth;

  Future<String> checkSignupEmail(String email) async {
    final res = await client.rpc('check_signup_email', params: {'p_email': email});
    return res as String;
  }

  Future<void> upsertSignupTracker(String email, bool profileCreated) async {
    await client.from('signup_tracker').upsert({
      'email': email,
      'profile_created': profileCreated,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

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

  Future<Map<String, dynamic>?> refreshSession() async {
    try {
      final response = await auth.refreshSession();
      return response.session?.user.toJson();
    } catch (_) {
      return null;
    }
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
    final eventId = const Uuid().v4();
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final inviteToken = const Uuid().v4();
    final now = DateTime.now().toIso8601String();

    await client.from('events').insert({
      'id': eventId,
      'name': data['name'],
      'description': data['description'],
      'cover_url': data['cover_url'],
      'type': data['type'],
      'created_by_user_id': user.id,
      'group_id': data['group_id'],
      'location_name': data['location_name'],
      'location_lat': data['location_lat'],
      'location_lng': data['location_lng'],
      'starts_at': data['starts_at'],
      'ends_at': data['ends_at'],
      'join_mode': data['join_mode'],
      'preshards_pool': data['preshards_pool'] ?? 0,
      'preshards_cap_per_user': data['preshards_cap_per_user'],
      'preshards_remainder_action': data['preshards_remainder_action'],
      'invite_token': inviteToken,
      'status': data['status'] ?? 'upcoming',
      'dynamic_qr_enabled': (data['preshards_pool'] ?? 0) > 0,
      'created_at': now,
      'updated_at': now,
    });

    await client.from('event_promotores').insert({
      'event_id': eventId,
      'user_id': user.id,
      'role': 'promotor',
      'preshards_contributed': data['preshards_pool'] ?? 0,
      'added_at': now,
    });

    await client.from('chats').insert({
      'type': 'event',
      'reference_id': eventId,
      'created_at': now,
    });

    return {'id': eventId, 'invite_token': inviteToken};
  }

  Future<List<Map<String, dynamic>>> listEvents([String? status, String? type]) async {
    var query = client.from('events').select();
    if (status != null) query = query.eq('status', status);
    if (type != null) query = query.eq('type', type);
    final res = await query.order('starts_at', ascending: true);
    return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> getEvent(String id) async {
    final res = await client.from('events').select().eq('id', id).single();
    return Map<String, dynamic>.from(res);
  }

  Future<void> updateEvent(String id, Map<String, dynamic> patch) async {
    final data = Map<String, dynamic>.from(patch);
    data['updated_at'] = DateTime.now().toIso8601String();
    if (patch.containsKey('preshards_pool')) {
      data['dynamic_qr_enabled'] = (patch['preshards_pool'] as int) > 0;
    }
    await client.from('events').update(data).eq('id', id);
  }

  Future<String?> getFriendshipStatus(String userId) async {
    final user = auth.currentUser;
    if (user == null) return null;
    final asRequester = await client
        .from('friendships')
        .select('status')
        .eq('requester_id', user.id)
        .eq('addressee_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (asRequester != null) return asRequester['status'] as String?;
    final asAddressee = await client
        .from('friendships')
        .select('status')
        .eq('requester_id', userId)
        .eq('addressee_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return asAddressee?['status'] as String?;
  }

  Future<String?> getFriendshipIdForUser(String userId) async {
    final user = auth.currentUser;
    if (user == null) return null;
    final asRequester = await client
        .from('friendships')
        .select('id')
        .eq('requester_id', user.id)
        .eq('addressee_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (asRequester != null) return asRequester['id'] as String?;
    final asAddressee = await client
        .from('friendships')
        .select('id')
        .eq('requester_id', userId)
        .eq('addressee_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return asAddressee?['id'] as String?;
  }

  Future<Map<String, dynamic>?> getFriendshipDetail(String userId) async {
    final user = auth.currentUser;
    if (user == null) return null;
    final asRequester = await client
        .from('friendships')
        .select('id, status, requester_id')
        .eq('requester_id', user.id)
        .eq('addressee_id', userId)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    if (asRequester != null) return Map<String, dynamic>.from(asRequester);
    final asAddressee = await client
        .from('friendships')
        .select('id, status, requester_id')
        .eq('requester_id', userId)
        .eq('addressee_id', user.id)
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return asAddressee != null ? Map<String, dynamic>.from(asAddressee) : null;
  }

  Future<void> sendFriendRequest(String userId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final asRequester = await client
        .from('friendships')
        .select('id')
        .eq('requester_id', user.id)
        .eq('addressee_id', userId)
        .limit(1)
        .maybeSingle();
    final asAddressee = asRequester == null ? await client
        .from('friendships')
        .select('id')
        .eq('requester_id', userId)
        .eq('addressee_id', user.id)
        .limit(1)
        .maybeSingle() : null;
    if (asRequester != null || asAddressee != null) throw Exception('Ya existe una solicitud o amistad con este usuario');
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

    var existing = await client
        .from('friendships')
        .select('id, requester_id')
        .eq('requester_id', user.id)
        .eq('addressee_id', userId)
        .maybeSingle();
    existing ??= await client
        .from('friendships')
        .select('id, requester_id')
        .eq('requester_id', userId)
        .eq('addressee_id', user.id)
        .maybeSingle();
    if (existing != null) {
      await client.from('friendships').delete().eq('id', existing['id'] as String);
    }
    await client.from('friendships').insert({
      'requester_id': user.id,
      'addressee_id': userId,
      'status': 'blocked',
    });
  }

  Future<void> unblockUser(String userId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    var existing = await client
        .from('friendships')
        .select('id')
        .eq('requester_id', user.id)
        .eq('addressee_id', userId)
        .maybeSingle();
    existing ??= await client
        .from('friendships')
        .select('id')
        .eq('requester_id', userId)
        .eq('addressee_id', user.id)
        .maybeSingle();
    if (existing != null) {
      await client.from('friendships').delete().eq('id', existing['id'] as String);
    }
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final user = auth.currentUser;
    final res = await client
        .from('user_search_view')
        .select('id, username, avatar_url')
        .ilike('username', '$query%')
        .neq('id', user?.id ?? '')
        .limit(20);
    final results = res.map((e) => Map<String, dynamic>.from(e)).toList();

    if (results.isEmpty || user == null) return results;

    final ids = results.map((r) => r['id'] as String).toList();
    final asRequester = await client
        .from('friendships')
        .select('requester_id, addressee_id, status')
        .eq('requester_id', user.id)
        .inFilter('addressee_id', ids);
    final asAddressee = await client
        .from('friendships')
        .select('requester_id, addressee_id, status')
        .eq('addressee_id', user.id)
        .inFilter('requester_id', ids);
    final frRows = [...asRequester, ...asAddressee];

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
    final asRequester = await client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, created_at')
        .eq('requester_id', user.id)
        .eq('status', 'accepted');
    final asAddressee = await client
        .from('friendships')
        .select('id, requester_id, addressee_id, status, created_at')
        .eq('addressee_id', user.id)
        .eq('status', 'accepted');
    final res = [...asRequester, ...asAddressee];
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

    var res = await client
        .from('friendships')
        .select('id')
        .eq('requester_id', user.id)
        .eq('addressee_id', userId)
        .eq('status', 'blocked')
        .maybeSingle();
    res ??= await client
        .from('friendships')
        .select('id')
        .eq('requester_id', userId)
        .eq('addressee_id', user.id)
        .eq('status', 'blocked')
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
      'rank_bracket': 'b0_20',
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
    final remaining = await client
        .from('group_members')
        .select('id')
        .eq('group_id', groupId)
        .limit(1);
    if (remaining.isEmpty) {
      await client.from('groups').delete().eq('id', groupId);
      await client.from('chats').delete().eq('reference_id', groupId).eq('type', 'group');
    }
  }

  Future<Map<String, dynamic>?> getGroup(String groupId) async {
    final res = await client.from('groups').select().eq('id', groupId).maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final res = await client
        .from('group_members')
        .select('id, user_id, role, joined_at, status, users!inner(username)')
        .eq('group_id', groupId)
        .eq('status', 'active');
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getGroupInvites() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('group_members')
        .select('id, group_id, role, joined_at, groups!inner(name)')
        .eq('user_id', user.id)
        .eq('status', 'invited');
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> acceptGroupInvite(String membershipId) async {
    await client.from('group_members').update({'status': 'active'}).eq('id', membershipId);
  }

  Future<void> declineGroupInvite(String membershipId) async {
    await client.from('group_members').delete().eq('id', membershipId);
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
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('messages')
        .select('id, sender_id, content, media_url, created_at')
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (res as List).reversed.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> sendMessage(String chatId, String content, String? mediaUrl) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': user.id,
      'content': content,
      'media_url': mediaUrl,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> uploadPhoto(String eventId, String filePath) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final bytes = await _readFileBytes(filePath);
    final extension = filePath.split('.').last;
    final storagePath = '$eventId/photos/${const Uuid().v4()}.$extension';

    await client.storage.from('events').uploadBinary(storagePath, bytes);
    await client.from('event_photos').insert({
      'event_id': eventId,
      'uploaded_by_user_id': user.id,
      'storage_path': storagePath,
      'likes_count': 0,
      'reported': false,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String> getSignedPhotoUrl(String storagePath) async {
    final res = await client.storage.from('events').createSignedUrl(storagePath, 3600);
    return res;
  }

  Future<void> likePhoto(String photoId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final existing = await client
        .from('event_photo_likes')
        .select('id')
        .eq('photo_id', photoId)
        .eq('user_id', user.id)
        .maybeSingle();
    if (existing != null) return;

    await client.from('event_photo_likes').insert({
      'photo_id': photoId,
      'user_id': user.id,
      'created_at': DateTime.now().toIso8601String(),
    });
    await client.rpc('increment_photo_likes', params: {'p_photo_id': photoId});
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('notifications')
        .select('id, type, title, body, data, read, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> markNotificationRead(String id) async {
    await client.from('notifications').update({'read': true}).eq('id', id);
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
        .select('id, user_id, shards_contributed, users!inner(username)')
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
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final cosmetic = await client.from('cosmetics').select('shard_cost').eq('id', cosmeticId).single();
    final cost = cosmetic['shard_cost'] as int;

    final userData = await client.from('users').select('personal_shards').eq('id', user.id).single();
    final shards = userData['personal_shards'] as int;
    if (shards < cost) throw Exception('No tienes suficientes shards');

    await client.from('user_cosmetics').insert({
      'user_id': user.id,
      'cosmetic_id': cosmeticId,
      'equipped': false,
      'purchased_at': DateTime.now().toIso8601String(),
    });

    await client.from('shard_ledger').insert({
      'user_id': user.id,
      'delta': -cost,
      'reason': 'cosmetic_purchase',
      'reference_id': cosmeticId,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> reportContent(String targetType, String targetId, String reason) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client.from('reports').insert({
      'reporter_id': user.id,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
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
        .select('id, username, avatar_url, bio, personal_shards')
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
    String? avatarUrl,
    String? dateOfBirth,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final shards = await getSignupShardGrant();
    final now = DateTime.now().toIso8601String();

    await client.from('users').insert({
      'id': user.id,
      'username': username,
      'avatar_url': avatarUrl,
      'date_of_birth': dateOfBirth,
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

    final email = user.email;
    if (email != null) {
      await upsertSignupTracker(email, true);
    }
  }

  RealtimeChannel _subscribeToChannel(
    String channelName,
    PostgresChangeEvent event,
    String table,
    void Function(Map<String, dynamic>) callback,
  ) {
    final channel = client.channel(channelName);
    channel.onPostgresChanges(
      event: event,
      schema: 'public',
      table: table,
      callback: (payload) => callback(payload.newRecord),
    );
    channel.subscribe();
    return channel;
  }

  Future<void> subscribeToMessages(String chatId, void Function(Map<String, dynamic>) onInsert) async {
    _subscribeToChannel('messages:$chatId', PostgresChangeEvent.insert, 'messages', onInsert);
  }

  Future<void> subscribeToNotifications(void Function(Map<String, dynamic>) onInsert) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    _subscribeToChannel('notifications:${user.id}', PostgresChangeEvent.insert, 'notifications', onInsert);
  }

  Future<void> subscribeToEventStatus(String eventId, void Function(String) onChange) async {
    final channel = client.channel('event-status:$eventId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'events',
      callback: (payload) {
        final newStatus = payload.newRecord['status'] as String?;
        if (newStatus != null) onChange(newStatus);
      },
    );
    channel.subscribe();
  }

  Future<void> subscribeToQRToken(String eventId, void Function(String) onUpdate) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final channel = client.channel('qr-token:$eventId:${user.id}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'event_qr_tokens',
      callback: (payload) {
        final token = payload.newRecord['token'] as String?;
        if (token != null) onUpdate(token);
      },
    );
    channel.subscribe();
  }

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

  Future<Uint8List> _readFileBytes(String filePath) async {
    final file = File(filePath);
    return await file.readAsBytes();
  }
}
