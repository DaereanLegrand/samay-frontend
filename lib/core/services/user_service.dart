import 'package:samay/core/errors/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User profile operations: read/update own profile, avatar, bio, and
/// interest tags.
///
/// Friendship lifecycle lives in [FriendshipService].
/// User search lives in [DiscoveryService].
class UserService {
  final SupabaseClient client;

  UserService({required this.client});

  GoTrueClient get auth => client.auth;

  /// The profile of [userId], or null when the row does not exist.
  ///
  /// Own row → the full `users` table (bio, shards, subscription tier —
  /// own-row-only RLS).
  /// ANY OTHER user → the `user_search_view` security barrier
  /// (id/username/avatar_url/bio, deleted + blocked excluded) — reading the
  /// `users` table directly for another user returns an empty result (RLS),
  /// which would surface as the "Usuario" fallback.
  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final user = auth.currentUser;
    final isOwn = user != null && user.id == userId;
    if (isOwn) {
      final res = await client
          .from('users')
          .select(
            'id, username, avatar_url, bio, personal_shards, preshards, subscription_tier',
          )
          .eq('id', userId)
          .maybeSingle();
      if (res == null) return null;
      return Map<String, dynamic>.from(res);
    }
    // E3/E4 shadow block: the RPC returns the privacy projection AND the
    // block relation (blocked_by_me / blocked_me). The blocked side gets
    // username + avatar only; no lobby/lists can enumerate them.
    final res = await client.rpc(
      'get_profile_for_viewer',
      params: {'p_id': userId},
    );
    if (res is List && res.isNotEmpty) {
      return Map<String, dynamic>.from(res.first as Map);
    }
    return null;
  }

  /// The profiles of [userIds] in ONE `user_search_view` read (id/username/
  /// avatar_url/bio). Ids with no visible row are simply absent from the
  /// result (deleted or blocked users are excluded by the view).
  Future<List<Map<String, dynamic>>> getUserProfiles(
    List<String> userIds,
  ) async {
    if (userIds.isEmpty) return const [];
    // Q8: direct client SELECT on user_search_view is revoked. This RPC keeps
    // the same projection (bio/avatar NULL for a private non-friend) without
    // reopening directory enumeration.
    final res = await client.rpc(
      'get_public_profiles',
      params: {'p_ids': userIds},
    );
    return [
      for (final r in (res as List))
        Map<String, dynamic>.from(r as Map),
    ];
  }

  /// Persists the public avatar URL via the set_avatar_url RPC (clients hold
  /// NO table UPDATE privilege; the RPC
  /// scopes to auth.uid() and validates the https shape server-side).
  /// [userId] is kept for call-site stability; the server derives the scope.
  Future<void> updateAvatarUrl(String userId, String avatarUrl) async {
    await client
        .rpc('set_avatar_url', params: {'p_avatar_url': avatarUrl});
  }

  /// Persists the bio via the update_my_profile RPC (clients hold no table
  /// UPDATE privilege). Empty string clears the field; the RPC sanitizes + caps
  /// length server-side. [userId] is kept for call-site stability; the
  /// server derives the scope.
  Future<void> updateBio(String userId, String bio) async {
    await client.rpc('update_my_profile', params: {'p_bio': bio});
  }

  /// The minigame-invite privacy switch (`users.minigame_invite_friends_only`,
  /// migration 140_minigame_invites, default FALSE = anyone may invite me).
  Future<bool> getMinigameInviteFriendsOnly() async {
    final user = auth.currentUser;
    if (user == null) return false;
    final res = await client
        .from('users')
        .select('minigame_invite_friends_only')
        .eq('id', user.id)
        .maybeSingle();
    return res?['minigame_invite_friends_only'] as bool? ?? false;
  }

  /// Persists the minigame-invite privacy switch via the
  /// set_minigame_invite_friends_only RPC (profile-RPC lockdown — clients
  /// hold no UPDATE on `users`).
  Future<void> setMinigameInviteFriendsOnly(bool value) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    await client.rpc(
      'set_minigame_invite_friends_only',
      params: {'p_value': value},
    );
  }
}
