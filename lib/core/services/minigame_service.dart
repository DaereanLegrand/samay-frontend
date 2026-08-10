import 'package:samay/core/services/realtime_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The five group-scoped mini-game types (GMCR spec; DB enum
/// `mini_game_type`). `.value` is the wire value used by the RPC and the
/// `game_type` column.
enum MinigameType {
  pokeChain('poke_chain'),
  questions('questions'),
  truthDare('truth_dare'),
  drunkBottle('drunk_bottle'),
  challenge('challenge');

  const MinigameType(this.value);

  final String value;
}

/// Session lifecycle status (DB enum `mini_game_status`).
enum MinigameStatus {
  active('active'),
  finished('finished');

  const MinigameStatus(this.value);

  final String value;
}

/// Why [MinigameService.createSession] was rejected. The RPC returns these
/// as jsonb statuses (I-57 contract) so the client never parses exception
/// messages.
enum MinigameSessionRejection {
  /// The caller has no active session / anon caller.
  notAuthenticated,

  /// The caller is not an active member of the group (RLS-safe via the
  /// server-side `is_group_member` helper).
  notMember,

  /// `p_wager < 0` — the GWAG contract allows only integer shards >= 0.
  invalidWager,

  /// `p_game_type` is not one of the five `mini_game_type` values.
  invalidGameType,

  /// The caller's `personal_shards` are below the requested wager.
  insufficientShards,
}

/// Typed rejection thrown by [MinigameService.createSession] when the RPC
/// returns a non-created status — the UI maps [rejection] to a localized
/// message without pattern-matching raw exception strings (I-62 pattern).
class MinigameSessionRejectedException implements Exception {
  const MinigameSessionRejectedException(this.rejection);

  final MinigameSessionRejection rejection;

  @override
  String toString() => 'MinigameSessionRejectedException($rejection)';
}

/// Group-scoped mini-games (GMCR spec) with optional shard wagers (GWAG
/// spec), backed by the `minigame_sessions` table.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11).
class MinigameService {
  final SupabaseClient client;
  final RealtimeService realtime;

  MinigameService({required this.client, required this.realtime});

  GoTrueClient get auth => client.auth;

  static const _columns =
      'id, group_id, game_type, status, shard_wager, participants, '
      'winner_id, created_at';

  /// All sessions of [groupId], newest first (RLS `ms_read_group_member` —
  /// group members only).
  Future<List<Map<String, dynamic>>> listSessions(String groupId) async {
    final res = await client
        .from('minigame_sessions')
        .select(_columns)
        .eq('group_id', groupId)
        .order('created_at', ascending: false);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// One session row by id, or null when it does not exist / is not visible
  /// to the caller.
  Future<Map<String, dynamic>?> getSession(String id) async {
    final res = await client
        .from('minigame_sessions')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();
    return res == null ? null : Map<String, dynamic>.from(res);
  }

  /// Creates a session for [groupId] of type [type] with an optional
  /// [wager] (0 = no wager). The server-side RPC (migration
  /// 20260809000006) validates group membership and balance and performs the
  /// atomic deduct + `minigame_wager` ledger + session insert; the returned
  /// session id is the initiator's escrow anchor (GWAG).
  ///
  /// Throws [MinigameSessionRejectedException] with the typed rejection when
  /// the RPC returns a non-created status.
  Future<String> createSession(
    String groupId,
    MinigameType type,
    int wager,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final res = await client.rpc(
      'create_minigame_session',
      params: {
        'p_group_id': groupId,
        'p_game_type': type.value,
        'p_wager': wager,
      },
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    final status = result['status'] as String?;

    return switch (status) {
      'created' => result['sessionId'] as String,
      'not_authenticated' =>
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        ),
      'not_member' => throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notMember,
        ),
      'invalid_wager' => throw const MinigameSessionRejectedException(
          MinigameSessionRejection.invalidWager,
        ),
      'invalid_game_type' => throw const MinigameSessionRejectedException(
          MinigameSessionRejection.invalidGameType,
        ),
      'insufficient_shards' => throw const MinigameSessionRejectedException(
          MinigameSessionRejection.insufficientShards,
        ),
      _ => throw Exception('Unexpected create_minigame_session response: $res'),
    };
  }

  /// Appends the current user to [sessionId]'s participants array (self
  /// only — never another user).
  ///
  /// NOTE (server RPC gap): `minigame_sessions` has no UPDATE policy under
  /// FORCE RLS, so this client-side contract is blocked until a
  /// `join_minigame_session` SECURITY DEFINER RPC lands (handoff I-77/S-03;
  /// see the I-63 daily log).
  Future<void> joinSession(String id) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

    final session = await getSession(id);
    if (session == null) throw Exception('Session not found');

    final participants = (session['participants'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    if (participants.contains(user.id)) return;

    participants.add(user.id);
    await client
        .from('minigame_sessions')
        .update({'participants': participants})
        .eq('id', id);
  }

  /// Flips the session lifecycle status (GMCR: `active` → `finished`).
  ///
  /// NOTE (server RPC gap): the same FORCE-RLS UPDATE restriction applies,
  /// and the winner settlement (`minigame_win` ledger + escrow credit to the
  /// winner, `minigame_refund` on draw — GWAG §Wager Resolution) MUST happen
  /// server-side in a `finish_minigame_session` SECURITY DEFINER RPC, not on
  /// the client. Until that RPC lands, finishing a wagered session leaves
  /// the escrow in the ledger (handoff I-77/S-03).
  Future<void> updateStatus(String id, MinigameStatus status) async {
    await client
        .from('minigame_sessions')
        .update({'status': status.value})
        .eq('id', id);
  }

  /// Live subscription to one session's row changes (GMCR Realtime sync:
  /// all participants subscribe to the `minigame_sessions` row changes).
  ///
  /// Returns the channel — the caller owns the unsubscribe handle. Rows are
  /// ALSO delivered through [sessionStatusProvider]
  /// (lib/features/minigames/minigames_providers.dart), which drives the
  /// I-52 realtime lifecycle (reconnect/backoff).
  RealtimeChannel subscribeToSession(String id) {
    return realtime.subscribeToChannel(
      'minigame-session:$id',
      PostgresChangeEvent.update,
      'minigame_sessions',
      (_) {},
    );
  }
}
