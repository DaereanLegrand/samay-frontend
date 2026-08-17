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
    if (user == null) throw const UnauthorizedError();
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
}
