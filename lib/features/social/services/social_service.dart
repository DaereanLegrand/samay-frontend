import 'package:samay/core/errors/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Feature-scoped service for the Social tab (C-social, 2026-08-18): the
/// global user ranking RPC and the caller's `profile_public` privacy switch.
///
/// `getUserRanking` goes through `public.get_user_ranking(p_limit)` — a
/// SECURITY DEFINER RPC (migration 20260818000002) because `users.personal_shards`
/// is column-REVOKEd from clients (G-03, 20260809000002 §1.1); only the RPC
/// can surface the shard balance for the leaderboard. The RPC also returns
/// `profile_public`, which the CLIENT combines with the `ranking.anonymize_names`
/// app_config to decide whether to render a username or the censor placeholder.
class SocialService {
  SocialService({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// The global user ranking: non-deleted users, personal_shards DESC.
  /// Rows: `user_id, username, avatar_url, personal_shards, profile_public`.
  Future<List<Map<String, dynamic>>> getUserRanking({int limit = 100}) async {
    final res = await _client.rpc(
      'get_user_ranking',
      params: {'p_limit': limit},
    );
    return res
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList(growable: false);
  }

  /// The caller's public-profile switch (`users.profile_public`, default
  /// false — every account starts private). Read via the own-row SELECT
  /// policy (the same seam as `read_receipts_enabled`).
  Future<bool> getProfilePublic() async {
    final user = _client.auth.currentUser;
    if (user == null) return false;
    final res = await _client
        .from('users')
        .select('profile_public')
        .eq('id', user.id)
        .maybeSingle();
    return res?['profile_public'] == true;
  }

  /// Persists the caller's public-profile switch (own-row only — the
  /// `users_update_own` RLS policy; `profile_public` is USER-OWNED profile
  /// data, deliberately absent from the G-03 protected-column list so the
  /// self-edit stays allowed, same class as `discovery_opt_in`).
  Future<void> setProfilePublic(bool value) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    await _client
        .from('users')
        .update({'profile_public': value})
        .eq('id', user.id);
  }
}
