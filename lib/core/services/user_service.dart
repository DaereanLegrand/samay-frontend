import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/models/user_interests.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User profile operations: read/update own profile, avatar, bio,
/// interest tags, and Party Finder opt-in.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11).
///
/// Friendship lifecycle lives in [FriendshipService].
/// Search and Party Finder discovery lives in [DiscoveryService].
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

  /// Persists the public avatar URL via the set_avatar_url RPC (profile-RPC
  /// lockdown 2026-08-25 — clients hold NO table UPDATE privilege; the RPC
  /// scopes to auth.uid() and validates the https shape server-side).
  /// [userId] is kept for call-site stability; the server derives the scope.
  Future<void> updateAvatarUrl(String userId, String avatarUrl) async {
    await client
        .rpc('set_avatar_url', params: {'p_avatar_url': avatarUrl});
  }

  /// Persists the bio via the update_my_profile RPC (profile-RPC lockdown
  /// 2026-08-25). Empty string clears the field; the RPC sanitizes + caps
  /// length server-side. [userId] is kept for call-site stability; the
  /// server derives the scope.
  Future<void> updateBio(String userId, String bio) async {
    await client.rpc('update_my_profile', params: {'p_bio': bio});
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

  /// Persists the Party Finder opt-in via the set_discovery_opt_in RPC
  /// (profile-RPC lockdown 2026-08-25).
  Future<void> setDiscoveryOptIn(bool value) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    await client.rpc('set_discovery_opt_in', params: {'p_value': value});
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
}
