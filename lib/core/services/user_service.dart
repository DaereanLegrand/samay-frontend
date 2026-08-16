import 'package:samay/features/profile/widgets/interests.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User profiles, friendship lifecycle and search.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11).
class UserService {
  final SupabaseClient client;

  UserService({required this.client});

  GoTrueClient get auth => client.auth;

  /// The profile of [userId], or null when the row does not exist.
  ///
  /// Own row → the full `users` table (bio, shards, subscription tier —
  /// own-row-only RLS since `20260520000001` dropped `users_search`).
  /// ANY OTHER user → the `user_search_view` security barrier
  /// (id/username/avatar_url/bio, deleted + blocked excluded) — reading the
  /// `users` table directly for another user returns an empty result (RLS),
  /// which is what used to surface as the "Usuario" fallback.
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final user = auth.currentUser;
    final isOwn = user != null && user.id == userId;
    final res = await (isOwn
        ? client
              .from('users')
              .select(
                'id, username, avatar_url, bio, personal_shards, preshards, subscription_tier',
              )
              .eq('id', userId)
              .maybeSingle()
        : client
              .from('user_search_view')
              .select('id, username, avatar_url, bio')
              .eq('id', userId)
              .maybeSingle());
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  /// Persists the public avatar URL on the user's profile row
  /// (PRFL avatar-upload gap — I-36). Own-row only: the `users_update_own`
  /// RLS policy restricts the update to `id = auth.uid()`.
  Future<void> updateAvatarUrl(String userId, String avatarUrl) async {
    await client
        .from('users')
        .update({'avatar_url': avatarUrl})
        .eq('id', userId);
  }

  /// Persists the bio on the user's profile row (edit-profile save path).
  /// Own-row only: the `users_update_own` RLS policy restricts the update to
  /// `id = auth.uid()`.
  Future<void> updateBio(String userId, String bio) async {
    await client.from('users').update({'bio': bio}).eq('id', userId);
  }

  /// The Party Finder opt-in (`users.discovery_opt_in`, PFND spec: default
  /// OFF). Reads the own row — self-editable because the column is
  /// deliberately OUT of I-32's protected set and REVOKE UPDATE list
  /// (see migration 20260809000004, trigger-interplay decision).
  Future<bool> getDiscoveryOptIn() async {
    final user = auth.currentUser;
    if (user == null) return false;
    final res = await client
        .from('users')
        .select('discovery_opt_in')
        .eq('id', user.id)
        .maybeSingle();
    return res?['discovery_opt_in'] as bool? ?? false;
  }

  /// Persists the Party Finder opt-in on the own row (privacy toggle).
  Future<void> setDiscoveryOptIn(bool value) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client
        .from('users')
        .update({'discovery_opt_in': value})
        .eq('id', user.id);
  }

  /// The current user's interest-tag slugs (own `users.interest_tags` row),
  /// sorted for determinism. Parsed through [UserInterests.fromDb] (handles
  /// both the PostgREST native list form and a JSON-encoded array string).
  Future<List<String>> getMyInterestTags() async {
    final user = auth.currentUser;
    if (user == null) return const [];
    final res = await client
        .from('users')
        .select('interest_tags')
        .eq('id', user.id)
        .maybeSingle();
    if (res == null) return const [];
    final tags = UserInterests.fromDb(res['interest_tags']).tags.toList()
      ..sort();
    return tags;
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

  /// Sends a friend request to [userId], returning the outcome:
  ///
  /// * `pending` — a fresh `pending` friendship row was inserted.
  /// * `accepted` — the addressee had already sent the current user a
  ///   `pending` request, so the friendship is accepted instantly (the
  ///   atomic mutual-accept flow, R15 — Juega's `send_friend_request`
  ///   returns 'accepted' the same way).
  ///
  /// Throws when the current user already has a friendship/request in the
  /// forward direction, or when an existing BLOCK row is in play (either
  /// direction): a block can only be lifted by the blocker via
  /// [unblockUser] — never by the blocked party "accepting" it.
  Future<String> sendFriendRequest(String userId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

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
      throw Exception('Ya existe una solicitud o amistad con este usuario');
    }
    if (asAddressee != null) {
      // FixB2-authz (LOW): the addressee of a BLOCKED row must never flip it
      // into an accepted friendship — the mutual-accept shortcut below is
      // additionally guarded by `status = 'pending'` (a blocked row fails
      // the UPDATE filter and no-ops), but the honest outcome for the
      // blocked party is an explicit error, mirroring the forward-direction
      // guard's message shape.
      if (asAddressee['status'] == 'blocked') {
        throw Exception('No puedes enviar una solicitud: estás bloqueado');
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
    await client.rpc('accept_friend_request', params: {
      'p_friendship_id': friendshipId,
    });
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
      await client
          .from('friendships')
          .delete()
          .eq('id', existing['id'] as String);
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
      await client
          .from('friendships')
          .delete()
          .eq('id', existing['id'] as String);
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
        .select('id, requester_id, addressee_id, status')
        .eq('requester_id', user.id)
        .inFilter('addressee_id', ids);
    final asAddressee = await client
        .from('friendships')
        .select('id, requester_id, addressee_id, status')
        .eq('addressee_id', user.id)
        .inFilter('requester_id', ids);
    final frRows = [...asRequester, ...asAddressee];

    final blockedByMe = <String>{};
    final blockedByThem = <String>{};
    final statusByUser = <String, String>{};
    // ISSUE 5: pending rows also carry the friendship id + direction so the
    // search UI can accept an inbound request (`received`) or show the
    // static pending badge for an outbound one (`sent`).
    final pendingIds = <String, String>{};
    final pendingDirections = <String, String>{};
    for (final row in frRows) {
      final otherId = row['requester_id'] == user.id
          ? row['addressee_id'] as String
          : row['requester_id'] as String;
      final status = row['status'] as String;
      statusByUser[otherId] = status;
      if (status == 'pending') {
        pendingIds[otherId] = row['id'] as String;
        pendingDirections[otherId] = row['requester_id'] == user.id
            ? 'sent'
            : 'received';
      } else if (status == 'blocked') {
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
          if (frStatus == 'pending') {
            r['friendship_id'] = pendingIds[uid];
            r['friendship_direction'] = pendingDirections[uid];
          }
          if (blockedByThem.contains(uid)) {
            r['hidden'] = true;
          }
          return r;
        })
        .where((r) => r['hidden'] != true)
        .toList();
  }

  /// Party Finder matches (PFND — I-60): opted-in users from the
  /// `discovery_view` security-barrier view whose interest tags overlap mine,
  /// ranked by shared-tag count DESC (spec: mutual friends first — deferred
  /// to the FRND-owned follow-up) then username ASC.
  ///
  /// Each returned row carries `shared_tags` (sorted intersection) and
  /// `shared_count`. Blocked users never appear (drops blocks I issued; hides
  /// users who blocked me) — mirrors [searchUsers] so a block lands
  /// immediately without re-deriving policy.
  Future<List<Map<String, dynamic>>> findMatches(List<String> myTags) async {
    final user = auth.currentUser;
    if (user == null || myTags.isEmpty) return const [];

    final res = await client
        .from('discovery_view')
        .select('id, username, avatar_url, interest_tags')
        .neq('id', user.id)
        .overlaps('interest_tags', myTags)
        .limit(50);
    final results = res.map((e) => Map<String, dynamic>.from(e)).toList();
    if (results.isEmpty) return results;

    final myTagSet = myTags.toSet();
    for (final row in results) {
      final shared = UserInterests.fromDb(row['interest_tags']).tags
          .intersection(myTagSet)
          .toList()
        ..sort();
      row['shared_tags'] = shared;
      row['shared_count'] = shared.length;
    }
    results.sort((a, b) {
      final byCount =
          (b['shared_count'] as int).compareTo(a['shared_count'] as int);
      if (byCount != 0) return byCount;
      return (a['username'] as String? ?? '')
          .compareTo(b['username'] as String? ?? '');
    });

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
    for (final row in frRows) {
      if (row['status'] != 'blocked') continue;
      if (row['requester_id'] == user.id) {
        blockedByMe.add(row['addressee_id'] as String);
      } else {
        blockedByThem.add(row['requester_id'] as String);
      }
    }

    return results
        .where((r) => !blockedByMe.contains(r['id']))
        .where((r) => !blockedByThem.contains(r['id']))
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
      final friendId = row['requester_id'] == user.id
          ? row['addressee_id'] as String
          : row['requester_id'] as String;
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
}
