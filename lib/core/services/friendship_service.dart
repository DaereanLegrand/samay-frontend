import 'package:samay/core/errors/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Friendship lifecycle: requests, accept/decline, block/unblock, friends
/// list, and pending-request queries.
///
/// Extracted from the former monolithic [UserService] as part of the
/// Batch 5b decomposition.
class FriendshipService {
  final SupabaseClient client;

  FriendshipService({required this.client});

  GoTrueClient get auth => client.auth;

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

  /// Sends a friend request to [userId], returning the outcome:
  ///
  /// * `pending` — a fresh `pending` friendship row was inserted.
  /// * `accepted` — the addressee had already sent the current user a
  ///   `pending` request, so the friendship is accepted instantly (the
  ///   atomic mutual-accept flow — the reference app's `send_friend_request`
  ///   returns 'accepted' the same way).
  ///
  /// Throws when the current user already has a friendship/request in the
  /// forward direction, or when an existing BLOCK row is in play (either
  /// direction): a block can only be lifted by the blocker via
  /// [unblockUser] — never by the blocked party "accepting" it.
  Future<String> sendFriendRequest(String userId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final asRequester = await client
        .from('friendships')
        .select('id, status')
        .eq('requester_id', user.id)
        .eq('addressee_id', userId)
        .limit(1)
        .maybeSingle();
    final asAddressee = asRequester == null
        ? await client
              .from('friendships')
              .select('id, status')
              .eq('requester_id', userId)
              .eq('addressee_id', user.id)
              .limit(1)
              .maybeSingle()
        : null;
    if (asRequester != null) {
      throw ConflictError(
        'Ya existe una solicitud o amistad con este usuario',
        code: 'already_friends',
      );
    }
    if (asAddressee != null) {
      if (asAddressee['status'] == 'blocked') {
        throw ConflictError(
          'No puedes enviar una solicitud: estás bloqueado',
          code: 'blocked',
        );
      }
      await client
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('id', asAddressee['id'] as String)
          .eq('status', 'pending');
      return 'accepted';
    }
    await client.from('friendships').insert({
      'requester_id': user.id,
      'addressee_id': userId,
      'status': 'pending',
    });
    return 'pending';
  }

  /// Accepts the incoming friend request [friendshipId] via the
  /// `accept_friend_request` SECURITY DEFINER RPC (migration 20260817000004):
  /// the server verifies auth.uid() is the ADDressee of a 'pending' row and
  /// flips it to 'accepted' — the direct UPDATE was client-guarded only
  /// (friendships_update_own covers requester OR addressee, so the requester
  /// could accept their own outbound request).
  Future<void> acceptFriendRequest(String friendshipId) async {
    await client.rpc(
      'accept_friend_request',
      params: {'p_friendship_id': friendshipId},
    );
  }

  /// Declines the incoming friend request [friendshipId] by deleting the row.
  /// Scoped to `status = 'pending'` (FixB2-authz): the addressee of a
  /// BLOCKED row can never delete the block through this path — only the
  /// blocker lifts it via [unblockUser].
  Future<void> declineFriendRequest(String friendshipId) async {
    await client
        .from('friendships')
        .delete()
        .eq('id', friendshipId)
        .eq('status', 'pending');
  }

  /// Blocks [userId] through the server RPC (234_safety_moderation). The
  /// server owns the ownership rules: a peer's existing block cannot be
  /// altered by the blocked party, and blocking cascades to discovery,
  /// notifications and invites.
  Future<void> blockUser(String userId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc('block_user', params: {'p_user_id': userId});
    final status = res is Map ? res['status'] : null;
    switch (status) {
      case 'ok':
        return;
      case 'blocked_by_peer':
        throw ConflictError(
          'No puedes modificar un bloqueo existente.',
          code: 'blocked_by_peer',
        );
      case 'invalid_target':
        throw ValidationError('user', 'No puedes bloquearte a ti mismo.');
      case 'not_authenticated':
        throw const UnauthorizedError();
      default:
        throw const ServerError();
    }
  }

  Future<void> unblockUser(String userId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc('unblock_user', params: {'p_user_id': userId});
    final status = res is Map ? res['status'] : null;
    switch (status) {
      case 'ok':
        return;
      case 'blocked_by_peer':
        throw ConflictError(
          'Solo quien bloqueó puede desbloquear.',
          code: 'blocked_by_peer',
        );
      case 'not_authenticated':
        throw const UnauthorizedError();
      default:
        throw const ServerError();
    }
  }

  /// Mutes [userId]. Mute is one-way and weaker than block: invites stay
  /// available, but the muted user's activity leaves the caller's
  /// notifications.
  Future<void> muteUser(String userId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc('mute_user', params: {'p_user_id': userId});
    final status = res is Map ? res['status'] : null;
    if (status == 'ok') return;
    if (status == 'invalid_target') {
      throw ValidationError('user', 'No puedes silenciarte a ti mismo.');
    }
    if (status == 'not_authenticated') throw const UnauthorizedError();
    throw const ServerError();
  }

  Future<void> unmuteUser(String userId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    await client.rpc('unmute_user', params: {'p_user_id': userId});
  }

  Future<List<Map<String, dynamic>>> _profileRowsFromRpc(
    String function,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc(function);
    return (res as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<List<Map<String, dynamic>>> getMutedUsers() =>
      _profileRowsFromRpc('get_muted_users');

  Future<List<Map<String, dynamic>>> getFriends() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
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
      final friendId = row['requester_id'] == user.id
          ? row['addressee_id'] as String
          : row['requester_id'] as String;
      friends.add({'friendship_id': row['id'], 'user_id': friendId});
    }
    return friends;
  }

  /// Resolves the CALLER's accepted-friend profiles in ONE round trip via the
  /// `get_friend_profiles` SECURITY DEFINER RPC (migration 040_friends/
  /// 01_get_friend_profiles.sql). The RPC scopes to auth.uid() — it can only
  /// ever return the caller's accepted friends, never arbitrary users — and
  /// ships in the migration so it exists on every deployment (the previous
  /// `user_search_view` client read was not queryable on some deployments,
  /// surfacing as a client-side cast crash).
  Future<List<Map<String, dynamic>>> getFriendProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const [];
    final res = await client.rpc(
      'get_friend_profiles',
      params: {'p_user_ids': userIds},
    );
    return (res as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> removeFriend(String friendshipId) async {
    await client.from('friendships').delete().eq('id', friendshipId);
  }

  Future<List<Map<String, dynamic>>> getFriendRequests() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
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
        {
          'type': 'received',
          'friendship_id': r['id'],
          'user_id': r['requester_id'],
          'created_at': r['created_at'],
        },
      for (final s in sent)
        {
          'type': 'sent',
          'friendship_id': s['id'],
          'user_id': s['addressee_id'],
          'created_at': s['created_at'],
        },
    ];
  }

  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final rows = await _profileRowsFromRpc('get_blocked_users');
    return [
      for (final row in rows)
        {
          'blocked_user_id': row['id'],
          'username': row['username'],
          'avatar_url': row['avatar_url'],
        },
    ];
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
}
