import 'dart:typed_data';

import 'package:samay/core/config/app_constants.dart';
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/services/realtime_service.dart';
import 'package:samay/core/utils/async_ops.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/truth_dare.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

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

  /// One of `p_invitees` is blocked (either direction) / deleted / the caller
  /// itself — the whole create is rejected atomically.
  inviteeNotAllowed,

  /// One of `p_invitees` opted into `minigame_invite_friends_only` and is
  /// not an accepted friend of the caller (140 privacy switch).
  inviteeFriendsOnly,

  /// More than 20 invitees were passed (defence in depth cap).
  tooManyInvitees,

  /// The create roster (creator + invitees) exceeds the session's frozen
  /// `player_limit` (free tier 8, scaled by the CREATOR's subscription tier
  /// via app_config — direct-minigames 2026-08-27).
  playerLimitReached,

  /// `p_rounds < 1` (201_minigame_voting).
  invalidRounds,

  /// `p_prize_positions < 1` (201_minigame_voting).
  invalidPrizePositions,

  /// `p_play_mode` is not `by_turns` / `async` (202_minigame_play_v2).
  invalidPlayMode,

  /// `p_async_rounds_per_player < 1` (202_minigame_play_v2).
  invalidAsyncRounds,

  /// `p_async_ends_at` is missing / in the past for an async session
  /// (202_minigame_play_v2 — the timer is settable at creation, no override).
  invalidAsyncEndsAt,

  /// A non-participant tried to join/finish a DIRECT session (group
  /// sessions still reject with [notMember]). Bystanders can never join or
  /// settle a direct game they are not in.
  notAllowed,
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
      'id, group_id, game_type, status, shard_wager, player_limit, '
      'participants, winner_id, created_at, name, auto_name';

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

  /// The current user's sessions — DIRECT and GROUP — newest first, where the
  /// caller is a participant (the creator is participant[0]). RLS bounds the
  /// read (`ms_read_direct_participant` for direct rows, `ms_read_group_member`
  /// for group rows); the `participants @> {uid}` filter keeps it to the
  /// caller's OWN games. This is the source for the per-game PARTIDAS EN CURSO
  /// list and the direct hub, so both scopes surface here — each group row
  /// carries its `group_id` for the group tag.
  Future<List<Map<String, dynamic>>> listMySessions() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client
        .from('minigame_sessions')
        .select(_columns)
        .contains('participants', [user.id])
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
  /// 20260809000006 + 140_minigame_invites) validates group membership and
  /// balance and performs the atomic deduct + `minigame_wager` ledger +
  /// session insert + one pending `minigame_invites` row per [inviteeIds]
  /// (the returned session id is the initiator's escrow anchor, GWAG).
  ///
  /// [groupId] is NULL for a DIRECT session (direct-minigames 2026-08-27) —
  /// playing with friends without belonging to a group. The server skips the
  /// group-membership gate for NULL (a non-null group still requires active
  /// membership) and freezes a `player_limit` from the creator's
  /// subscription tier (app_config `minigame.{free,pro,vip}_max_players`;
  /// free = 8). Invitees may be zero (some games are single-player).
  ///
  /// Invitees are anyone from the user-search pool (reusing the
  /// searchResultsProvider plumbing client-side); the RPC enforces the
  /// blocked-invitee and friends-only privacy gates server-side (typed
  /// statuses, never trusted client-side). Invitees need not be group
  /// members — `ms_read_invitee` opens the session row to them.
  ///
  /// Throws [MinigameSessionRejectedException] with the typed rejection when
  /// the RPC returns a non-created status.
  ///
  /// [name] is the optional partida title (160_minigame_names). Null or blank
  /// leaves the row unnamed — the UI then displays the computed `partida-XX`
  /// (auto-name stays client-side, never polluting the DB).
  ///
  /// 202_minigame_play_v2 additions: [playMode] (by_turns / async), [anonymous]
  /// (hide usernames during play — temp nicknames until the leaderboard),
  /// [asyncRoundsPerPlayer] (per-player target in async mode, default 1) and
  /// [asyncEndsAt] (the settable async deadline, no override after creation).
  Future<String> createSession(
    String? groupId,
    MinigameType type,
    int wager, {
    List<String> inviteeIds = const [],
    String? name,
    int rounds = 5,
    int prizePositions = kDefaultPrizePositions,
    MinigamePlayMode playMode = MinigamePlayMode.byTurns,
    bool anonymous = false,
    int asyncRoundsPerPlayer = 1,
    DateTime? asyncEndsAt,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'create_minigame_session',
      params: {
        'p_group_id': groupId,
        'p_game_type': type.value,
        'p_wager': wager,
        'p_invitees': inviteeIds,
        'p_name': name,
        'p_rounds': rounds,
        'p_prize_positions': prizePositions,
        'p_play_mode': playMode.wire,
        'p_anonymous': anonymous,
        'p_async_rounds_per_player': asyncRoundsPerPlayer,
        'p_async_ends_at': asyncEndsAt?.toIso8601String(),
      },
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    final status = result['status'] as String?;

    return switch (status) {
      'created' => result['sessionId'] as String,
      'not_authenticated' => throw const MinigameSessionRejectedException(
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
      'invitee_not_allowed' => throw const MinigameSessionRejectedException(
        MinigameSessionRejection.inviteeNotAllowed,
      ),
      'invitee_friends_only' => throw const MinigameSessionRejectedException(
        MinigameSessionRejection.inviteeFriendsOnly,
      ),
      'too_many_invitees' => throw const MinigameSessionRejectedException(
        MinigameSessionRejection.tooManyInvitees,
      ),
      'player_limit_reached' => throw const MinigameSessionRejectedException(
        MinigameSessionRejection.playerLimitReached,
      ),
      'invalid_rounds' => throw const MinigameSessionRejectedException(
        MinigameSessionRejection.invalidRounds,
      ),
      'invalid_prize_positions' => throw const MinigameSessionRejectedException(
        MinigameSessionRejection.invalidPrizePositions,
      ),
      'invalid_play_mode' => throw const MinigameSessionRejectedException(
        MinigameSessionRejection.invalidPlayMode,
      ),
      'invalid_async_rounds' => throw const MinigameSessionRejectedException(
        MinigameSessionRejection.invalidAsyncRounds,
      ),
      'invalid_async_ends_at' => throw const MinigameSessionRejectedException(
        MinigameSessionRejection.invalidAsyncEndsAt,
      ),
      _ => throw const ServerError('Unexpected create_minigame_session response'),
    };
  }

  /// Appends the current user to [sessionId]'s participants via the
  /// `join_minigame_session` SECURITY DEFINER RPC (migration
  /// 20260813000001) — `minigame_sessions` has no UPDATE policy under FORCE
  /// RLS, so the join is a server-side contract (self only — never another
  /// user): session-exists + group-membership validation, idempotent
  /// participants append, and — for wagered sessions — the atomic wager
  /// deduction + `minigame_wager` escrow ledger entry (GWAG, mirroring
  /// create_minigame_session). Business outcomes come back as jsonb statuses
  /// (I-57 contract).
  Future<void> joinSession(String id) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'join_minigame_session',
      params: {'p_session_id': id},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    final status = result['status'] as String?;

    switch (status) {
      case 'joined':
        return;
      case 'not_authenticated':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        );
      case 'not_member':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notMember,
        );
      case 'not_allowed':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAllowed,
        );
      case 'player_limit_reached':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.playerLimitReached,
        );
      case 'insufficient_shards':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.insufficientShards,
        );
      case 'session_not_found':
        throw const NotFoundError('Session');
      case 'session_not_active':
        throw ConflictError('Session is not active', code: 'session_not_active');
      default:
        throw const ServerError('Unexpected join_minigame_session response');
    }
  }

  /// Settles a finished minigame via the `finish_minigame_game` SECURITY
  /// DEFINER RPC (201_minigame_voting) — the single settlement seam that
  /// REPLACED `finish_minigame_session` (winner-takes-all) and
  /// `complete_minigame_game` (draw-only). The client-side UPDATE is
  /// RLS-blocked (`minigame_sessions` has no UPDATE policy under FORCE RLS)
  /// and the settlement MUST happen server-side.
  ///
  /// The RPC computes the leaderboard from the rounds history, pays the
  /// HARMONIC prize split (1/rank over N = prize_positions places, integer-
  /// exact) into `users.personal_shards` with `minigame_win` ledger rows,
  /// writes `minigame_results` and flips phase + session status to finished.
  /// Idempotent — repeat calls are a no-op. The finished screen reads the
  /// settled leaderboard via [getMinigameResult].
  Future<void> finishGame(String id) async {
    final res = await client.rpc(
      'finish_minigame_game',
      params: {'p_session_id': id},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    final status = result['status'] as String?;

    switch (status) {
      case 'finished':
      case 'already_finished':
        return;
      case 'not_authenticated':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        );
      case 'not_member':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notMember,
        );
      case 'not_allowed':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAllowed,
        );
      case 'session_not_found':
        throw const NotFoundError('Session');
      default:
        throw const ServerError('Unexpected finish_minigame_game response');
    }
  }

  /// Reads the settled leaderboard for [sessionId] from `minigame_results`
  /// (RLS `mgs_results_read` — participants/invitees/group members only), or
  /// null when the game has not settled yet.
  Future<MinigameResult?> getMinigameResult(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client
        .from('minigame_results')
        .select('session_id, results')
        .eq('session_id', sessionId)
        .maybeSingle();
    if (res == null) return null;
    return MinigameResult.fromJson(Map<String, dynamic>.from(res));
  }

  /// The raw E2EE answer rows of [sessionId] (ciphertext only), ordered by
  /// round ascending — the finished-leaderboard content source. RLS
  /// `mgs_answers_read` bounds the read to participants/invitees/group
  /// members; the app decrypts each `answer_ciphertext` locally.
  Future<List<Map<String, dynamic>>> getSessionAnswers(
    String sessionId,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client
        .from('minigame_answers')
        .select(
          'round, subject_id, prompt_type, prompt_id, '
          'answer_ciphertext, image_storage_path, passed',
        )
        .eq('session_id', sessionId)
        .order('round', ascending: true);
    return [for (final row in res) Map<String, dynamic>.from(row)];
  }

  /// The raw reaction rows of [sessionId], ordered by round ascending — the
  /// per-subject reaction tallies on the finished leaderboard. RLS
  /// `mgs_reactions_read` bounds the read to participants/invitees/group
  /// members. A NULL `reaction` is a reactor Pasar (no emoji).
  Future<List<Map<String, dynamic>>> getSessionReactions(
    String sessionId,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client
        .from('minigame_reactions')
        .select('round, voter_id, reaction')
        .eq('session_id', sessionId)
        .order('round', ascending: true);
    return [for (final row in res) Map<String, dynamic>.from(row)];
  }

  /// Resolves prompt ids to their question text — `{id: body}` — via one
  /// batched `minigame_prompts` read. RLS `mgs_prompts_select` exposes only
  /// `is_active = true` rows, so a deactivated/removed prompt is simply
  /// absent and the caller surfaces its load-error state.
  Future<Map<String, String>> getPromptsByIds(Set<String> ids) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    if (ids.isEmpty) return const {};
    final res = await client
        .from('minigame_prompts')
        .select('id, body')
        .inFilter('id', ids.toList());
    return {
      for (final row in res)
        if (row['id'] is String && row['body'] is String)
          row['id'] as String: row['body'] as String,
    };
  }

  /// The current user's invite row for [sessionId] (null when they have
  /// none). RLS `mi_read_own` limits the read to the caller's own invites,
  /// so the `invitee_id` filter is belt-and-suspenders.
  Future<Map<String, dynamic>?> myInviteForSession(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client
        .from('minigame_invites')
        .select('id, session_id, invitee_id, created_by, status, created_at')
        .eq('session_id', sessionId)
        .eq('invitee_id', user.id)
        .maybeSingle();
    return res == null ? null : Map<String, dynamic>.from(res);
  }

  /// The narrow INVITE CONTEXT for [sessionId] when the caller holds an
  /// invite (`215_minigame_invite_context`): the inviter's
  /// `{id, username, avatar_url}` plus the group name (null for a direct
  /// session). Returns null when the caller has no invite for the session
  /// (`invite_not_found`).
  ///
  /// This is deliberately the ONLY identity a pending invitee may resolve:
  /// `get_minigame_participants` would leak the whole roster into the client
  /// before the invitee accepts (2026-09-11 directive — a not-yet-accepted
  /// invitee must never see the player list).
  Future<Map<String, dynamic>?> getInviteContext(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc(
      'get_minigame_invite_context',
      params: {'p_session_id': sessionId},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'ok':
        return result;
      case 'invite_not_found':
        return null;
      case 'not_authenticated':
        throw const UnauthorizedError();
      default:
        throw const ServerError(
          'Unexpected get_minigame_invite_context response',
        );
    }
  }

  /// The HOST-side invite state for [sessionId], keyed by invitee id — the
  /// lobby picker's "already invited" tag (2026-09-02). RLS `mi_read_own`
  /// bounds the read to invites the caller CREATED, so only the host sees
  /// them; each entry maps `invitee_id -> status`. A declined invite deletes
  /// its row (2026-09-02), so a declined/kicked player simply has no entry
  /// and shows as a fresh invitee in the picker — there is no "declined"
  /// residue.
  Future<Map<String, String>> inviteeStates(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client
        .from('minigame_invites')
        .select('invitee_id, status')
        .eq('session_id', sessionId)
        .eq('created_by', user.id);
    return {
      for (final row in res)
        if (row['invitee_id'] is String && row['status'] is String)
          row['invitee_id'] as String: row['status'] as String,
    };
  }

  /// The current user's PENDING invites, as the SESSION rows of those
  /// invites (newest invite first) — the invitee-side "partida-N ready to
  /// accept" list (170_minigame_invite_badges).
  ///
  /// Two reads: the pending invite rows (`minigame_invites`, RLS
  /// `mi_read_own` bounds to the caller) then one `getSession` per session id
  /// (RLS `ms_read_invitee` opens the session row to an invitee even when
  /// they are not yet a participant). Bystanders see nothing — a pending
  /// invite is the narrowest read that lets an invited friend render the
  /// partida and accept while it is active.
  Future<List<Map<String, dynamic>>> listMyPendingInvites() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final invites = await client
        .from('minigame_invites')
        .select('id, session_id, invitee_id, created_by, status, created_at')
        .eq('invitee_id', user.id)
        .eq('status', 'pending')
        .order('created_at', ascending: false);
    final sessionIds = <String>[];
    for (final row in invites) {
      final sessionId = row['session_id'];
      if (sessionId is String && !sessionIds.contains(sessionId)) {
        sessionIds.add(sessionId);
      }
    }

    final sessions = <Map<String, dynamic>>[];
    for (final sessionId in sessionIds) {
      final session = await getSession(sessionId);
      if (session != null) sessions.add(session);
    }
    return sessions;
  }

  /// The group-chat "match created" notices for [groupId] (210,
  /// 2026-09-15) — one row per group partida, written server-side on creation
  /// by the `notify_minigame_group_message` trigger. The embedded session row
  /// (RLS `ms_read_group_member`) gives the thread everything it needs to
  /// render the direct-access bubble. RLS `mgm_read_group_member` bounds the
  /// read to active group members.
  Future<List<Map<String, dynamic>>> listGroupMinigameMessages(
    String groupId,
  ) async {
    final res = await client
        .from('minigame_group_messages')
        .select(
          'id, session_id, actor_id, created_at, '
          'session:minigame_sessions(id, game_type, status, name, auto_name, participants)',
        )
        .eq('group_id', groupId)
        .order('created_at', ascending: true);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Accepts [inviteId] via the `accept_minigame_invite` SECURITY DEFINER RPC
  /// (migration 140_minigame_invites) — the invitee (self only) joins the
  /// session while it is ACTIVE: participants append + — for wagered
  /// sessions — the atomic wager deduction + `minigame_wager` escrow ledger
  /// entry (GWAG mirror of join_minigame_session). A finished session cannot
  /// be joined (`session_finished`) — the product contract that once the
  /// game is over the invite closes.
  Future<void> acceptInvite(String inviteId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'accept_minigame_invite',
      params: {'p_invite_id': inviteId},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    final status = result['status'] as String?;

    switch (status) {
      case 'accepted':
      case 'already_accepted':
        return;
      case 'not_authenticated':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        );
      case 'invite_not_found':
        throw const NotFoundError('Invite');
      case 'invite_not_active':
        throw ConflictError('Invite is not active', code: 'invite_not_active');
      case 'session_not_found':
        throw const NotFoundError('Session');
      case 'session_finished':
        throw ConflictError(
          'The game has finished; the invite can no longer be accepted',
          code: 'session_finished',
        );
      case 'player_limit_reached':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.playerLimitReached,
        );
      case 'insufficient_shards':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.insufficientShards,
        );
      default:
        throw const ServerError('Unexpected accept_minigame_invite response');
    }
  }

  /// Declines [inviteId] via the `decline_minigame_invite` SECURITY DEFINER
  /// RPC (migration 140_minigame_invites) — pending → declined, idempotent.
  Future<void> declineInvite(String inviteId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'decline_minigame_invite',
      params: {'p_invite_id': inviteId},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    final status = result['status'] as String?;

    switch (status) {
      case 'declined':
        return;
      case 'not_authenticated':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        );
      case 'invite_not_found':
        throw const NotFoundError('Invite');
      case 'already_accepted':
        throw ConflictError(
          'Invite is already accepted',
          code: 'already_accepted',
        );
      default:
        throw const ServerError('Unexpected decline_minigame_invite response');
    }
  }

  /// Invites players into an ALREADY-CREATED session via the
  /// `invite_minigame_players` SECURITY DEFINER RPC (205_minigame_invite_lobby
  /// — the 2026-09-01 lobby flow: create with zero invitees, then the HOST
  /// invites while waiting in the lobby). CREATOR-ONLY (backend-enforced via
  /// `participants[1]` → `not_creator`), idempotent (self / already-participant
  /// / already-pending invitees are skipped) and re-checks the session's frozen
  /// player cap. Mirrors the create-time per-invitee gates (blocked/deleted +
  /// friends-only privacy); the existing `notify_minigame_invite` trigger
  /// dispatches each new invite's notification unchanged.
  Future<void> invitePlayers(String sessionId, List<String> inviteeIds) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'invite_minigame_players',
      params: {'p_session_id': sessionId, 'p_invitees': inviteeIds},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    final status = result['status'] as String?;

    switch (status) {
      case 'ok':
        return;
      case 'not_authenticated':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        );
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'session_not_active':
        throw ConflictError(
          'La partida ya terminó',
          code: 'session_not_active',
        );
      case 'not_creator':
        throw PermissionError();
      case 'invitee_not_allowed':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.inviteeNotAllowed,
        );
      case 'invitee_friends_only':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.inviteeFriendsOnly,
        );
      case 'too_many_invitees':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.tooManyInvitees,
        );
      case 'player_limit_reached':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.playerLimitReached,
        );
      default:
        throw const ServerError('Unexpected invite_minigame_players response');
    }
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

  /// The play-engine state row for [sessionId] (150_minigame_play), or null
  /// when the session has no game state yet (`not_started`). Gates: auth,
  /// session exists, caller is participant / invitee / group member —
  /// mirrored server-side (the same semantic as `mgs_read_participant`).
  ///
  /// The returned map is the full `minigame_game_state` row: the turn
  /// skeleton (judge_index / round / phase / subject_id / prompt_type /
  /// prompt) is nested under `state`.
  Future<Map<String, dynamic>?> getMinigameGameState(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'get_minigame_game_state',
      params: {'p_session_id': sessionId},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    return switch (result['status']) {
      'ok' => result['state'] as Map<String, dynamic>?,
      'not_started' => null,
      'not_authenticated' => throw const UnauthorizedError(),
      'session_not_found' => throw const NotFoundError('Partida'),
      'not_allowed' => throw PermissionError(),
      _ => throw const ServerError('Unexpected get_minigame_game_state response'),
    };
  }

  /// Cancels the pre-play countdown for [sessionId] (190_minigame_countdown):
  /// the CREATOR-only counterpart of [initMinigameGameState]. The server
  /// resets the game-state row back to a setup skeleton (`not_started`) so
  /// every participant stays on the match/lobby screen; the ready map is
  /// preserved. Non-creator callers get the typed `not_creator` rejection.
  Future<void> cancelMinigameStart(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'cancel_minigame_start',
      params: {'p_session_id': sessionId},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'cancelled':
        return;
      case 'not_authenticated':
        throw const UnauthorizedError();
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_allowed':
        throw PermissionError();
      case 'not_creator':
        throw PermissionError();
      case 'session_not_active':
        throw ConflictError(
          'La partida ya terminó',
          code: 'session_not_active',
        );
      case 'not_started':
        throw ConflictError(
          'La partida no está en cuenta atrás',
          code: 'not_started',
        );
      default:
        throw const ServerError('Unexpected cancel_minigame_start response');
    }
  }

  /// Initializes the play engine for [sessionId] (150_minigame_play): seeds
  /// the game-agnostic turn skeleton and picks the FIRST subject randomly
  /// server-side (players never self-select). Idempotent — an existing
  /// game-state row returns `already_started` with the current state.
  Future<Map<String, dynamic>> initMinigameGameState(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'init_minigame_game_state',
      params: {'p_session_id': sessionId},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    return switch (result['status']) {
      'started' || 'already_started' => result['state'] as Map<String, dynamic>,
      'not_authenticated' => throw const UnauthorizedError(),
      'session_not_found' => throw const NotFoundError('Partida'),
      'not_allowed' => throw PermissionError(),
      'not_creator' => throw PermissionError(),
      'session_not_active' => throw ConflictError(
        'La partida ya terminó',
        code: 'session_not_active',
      ),
      'no_participants' => throw const ServerError('No participants'),
      _ => throw const ServerError('Unexpected init_minigame_game_state response'),
    };
  }

  /// The HOST's device confirms the countdown finished without a cancel
  /// (203_minigame_host_start): flips the game-state phase countdown →
  /// playing. Creator-only, backend-enforced via participants[0]. The UPDATE
  /// streams via realtime — every participant navigates to the play screen
  /// together. Idempotent for an already-playing row.
  Future<Map<String, dynamic>> startMatch(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'start_minigame_match',
      params: {'p_session_id': sessionId},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    return switch (result['status']) {
      'started' => result['state'] as Map<String, dynamic>,
      'not_authenticated' => throw const UnauthorizedError(),
      'session_not_found' => throw const NotFoundError('Partida'),
      'not_allowed' => throw PermissionError(),
      'not_creator' => throw PermissionError(),
      'session_not_active' => throw ConflictError(
        'La partida ya terminó',
        code: 'session_not_active',
      ),
      'not_started' => throw ConflictError(
        'La partida no está en cuenta atrás',
        code: 'not_started',
      ),
      _ => throw const ServerError('Unexpected start_minigame_match response'),
    };
  }

  /// Draws a random active prompt of [promptType] for [sessionId]'s game and
  /// persists it into the game state (150_minigame_play). The draw is
  /// server-random (`ORDER BY random() LIMIT 1`); the client only passes the
  /// prompt_type ('verdad' | 'reto' for truth_dare).
  Future<Map<String, dynamic>> revealMinigamePrompt(
    String sessionId,
    String promptType,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'reveal_minigame_prompt',
      params: {'p_session_id': sessionId, 'p_prompt_type': promptType},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    return switch (result['status']) {
      'revealed' => result['state'] as Map<String, dynamic>,
      'not_authenticated' => throw const UnauthorizedError(),
      'session_not_found' => throw const NotFoundError('Partida'),
      'not_allowed' => throw PermissionError(),
      'session_not_active' => throw ConflictError(
        'La partida ya terminó',
        code: 'session_not_active',
      ),
      'invalid_prompt_type' => throw ValidationError(
        'prompt_type',
        'Tipo de prompt no válido',
      ),
      'no_prompts_available' => throw const NotFoundError('Prompt'),
      _ => throw const ServerError('Unexpected reveal_minigame_prompt response'),
    };
  }

  /// Closes the current turn: appends [round] (the completed-round record)
  /// and advances judge_index + picks the next subject randomly server-side
  /// (150_minigame_play).
  Future<Map<String, dynamic>> advanceMinigameTurn(
    String sessionId,
    Map<String, dynamic> round,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'advance_minigame_turn',
      params: {'p_session_id': sessionId, 'p_round': round},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    return switch (result['status']) {
      'advanced' => result['state'] as Map<String, dynamic>,
      'not_authenticated' => throw const UnauthorizedError(),
      'session_not_found' => throw const NotFoundError('Partida'),
      'not_allowed' => throw PermissionError(),
      'session_not_active' => throw ConflictError(
        'La partida ya terminó',
        code: 'session_not_active',
      ),
      'not_started' => throw const ServerError('Game not started'),
      'no_participants' => throw const ServerError('No participants'),
      'countdown_pending' => throw ConflictError(
        'La partida aún no empieza',
        code: 'countdown_pending',
      ),
      _ => throw const ServerError('Unexpected advance_minigame_turn response'),
    };
  }

  /// Submits the caller's ONE emoji vote for the CURRENT round via the
  /// `submit_minigame_reaction` SECURITY DEFINER RPC (201_minigame_voting).
  /// One vote per voter per round (re-voting replaces); the vote is persisted
  /// to `minigame_reactions` AND mirrored into the game-state payload so the
  /// whole lobby sees the live tally on the realtime channel. Gates:
  /// participant/invitee/group member + active playing session (typed jsonb
  /// statuses).
  Future<void> submitReaction(String sessionId, ReactionKind reaction) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'submit_minigame_reaction',
      params: {'p_session_id': sessionId, 'p_reaction': reaction.wire},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'submitted':
        return;
      case 'advanced':
        // The caller's was the LAST required reaction: `submit_minigame_reaction`
      // recorded it AND closed the round by delegating to
      // `_minigame_advance_round` (207), which returns `advanced` (or the
      // `finished` / `already_finished` variants at the round target). The
      // write succeeded — the caller's notifier refreshes into the next round.
      // Not an error (defect: the last reactor saw a bogus snackbar).
      case 'finished':
      case 'already_finished':
        return;
      case 'too_fast':
        // Controlled-spam window: the server dropped the write (no seq bump,
        // no event). The tapper's local rise already played — stay silent,
        // never surface an "already reacted"-style snackbar.
        return;
      case 'not_authenticated':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        );
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_allowed':
        throw PermissionError();
      case 'session_not_active':
        throw ConflictError(
          'La partida ya terminó',
          code: 'session_not_active',
        );
      case 'not_started':
        throw ConflictError(
          'La partida aún no empieza',
          code: 'not_started',
        );
      case 'own_round':
        throw PermissionError();
      case 'answer_pending':
        throw ConflictError(
          'La ronda aún no se puede valorar',
          code: 'answer_pending',
        );
      case 'invalid_reaction':
        throw ValidationError('reaction', 'Reacción no válida');
      case 'already_reacted':
        throw ConflictError(
          'Ya reaccionaste con un emoji — no puedes pasar en esta ronda',
          code: 'already_reacted',
        );
      case 'already_passed':
        throw ConflictError(
          'Ya pasaste — no puedes reaccionar con un emoji en esta ronda',
          code: 'already_passed',
        );
      default:
        throw const ServerError('Unexpected submit_minigame_reaction response');
    }
  }

  /// Submits the current-turn subject's E2EE answer via the
  /// `submit_minigame_answer` SECURITY DEFINER RPC (202_minigame_play_v2).
  /// Gates: caller IS the state.subject_id, by_turns mode, round not already
  /// answered/passed, prompt revealed. The answer rides the payload as
  /// CIPHERTEXT only (the server never sees plaintext) and streams to every
  /// participant via the game-state realtime channel. [imageStoragePath] is the
  /// optional private-bucket object path of the ENCRYPTED image bytes (reto) —
  /// see [uploadMinigameImage]; the server never stores the key or plaintext.
  Future<void> submitAnswer(
    String sessionId, {
    required String answerCiphertext,
    String? imageStoragePath,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'submit_minigame_answer',
      params: {
        'p_session_id': sessionId,
        'p_answer_ciphertext': answerCiphertext,
        'p_image_storage_path': imageStoragePath,
      },
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'submitted':
        return;
      case 'not_authenticated':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        );
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_allowed':
        throw PermissionError();
      case 'session_not_active':
        throw ConflictError(
          'La partida ya terminó',
          code: 'session_not_active',
        );
      case 'not_started':
        throw ConflictError(
          'La partida aún no empieza',
          code: 'not_started',
        );
      case 'wrong_mode':
        throw ConflictError(
          'No es el modo por turnos',
          code: 'wrong_mode',
        );
      case 'not_subject':
        throw PermissionError();
      case 'already_answered':
        throw ConflictError(
          'La ronda ya fue respondida',
          code: 'already_answered',
        );
      case 'no_prompt':
        throw ConflictError(
          'El reto aún no se ha revelado',
          code: 'no_prompt',
        );
      default:
        throw const ServerError('Unexpected submit_minigame_answer response');
    }
  }

  /// The current-turn subject passes via `submit_minigame_pasar`
  /// (202_minigame_play_v2): blocks ALL reactions on the round and
  /// auto-advances with score -1. Gates: caller IS the state.subject_id,
  /// by_turns mode, round not already answered.
  Future<void> submitPasar(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'submit_minigame_pasar',
      params: {'p_session_id': sessionId},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'advanced':
        return;
      // The pass closed the FINAL round (`_minigame_advance_round` delegates to
      // `finish_minigame_game` at the round target) — a success, not an error.
      case 'finished':
      case 'already_finished':
        return;
      case 'not_authenticated':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        );
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_allowed':
        throw PermissionError();
      case 'session_not_active':
        throw ConflictError(
          'La partida ya terminó',
          code: 'session_not_active',
        );
      case 'not_started':
        throw ConflictError(
          'La partida aún no empieza',
          code: 'not_started',
        );
      case 'wrong_mode':
        throw ConflictError(
          'No es el modo por turnos',
          code: 'wrong_mode',
        );
      case 'not_subject':
        throw PermissionError();
      case 'already_answered':
        throw ConflictError(
          'La ronda ya fue respondida',
          code: 'already_answered',
        );
      default:
        throw const ServerError('Unexpected submit_minigame_pasar response');
    }
  }

  /// Submits one async round of the caller via `submit_minigame_async_answer`
  /// (202_minigame_play_v2): the server draws a random prompt of
  /// [promptType], records the caller's per-player round, and mirrors it into
  /// the reactable rounds list. The answer is ciphertext-only; [imageStoragePath]
  /// is the optional private-bucket object path of the ENCRYPTED image bytes
  /// (see [uploadMinigameImage]). Auto-finishes when every participant reaches
  /// the per-player target (or the settable timer passes — no override).
  Future<void> submitAsyncAnswer(
    String sessionId, {
    required TruthDareKind kind,
    required String answerCiphertext,
    String? imageStoragePath,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'submit_minigame_async_answer',
      params: {
        'p_session_id': sessionId,
        'p_prompt_type': kind.wire,
        'p_answer_ciphertext': answerCiphertext,
        'p_image_storage_path': imageStoragePath,
      },
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'submitted':
        return;
      // The async answer completed the FINAL round and settled the game
      // (`finish_minigame_game`) — a success, not an error.
      case 'finished':
      case 'already_finished':
        return;
      case 'not_authenticated':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        );
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_allowed':
        throw PermissionError();
      case 'session_not_active':
        throw ConflictError(
          'La partida ya terminó',
          code: 'session_not_active',
        );
      case 'not_started':
        throw ConflictError(
          'La partida aún no empieza',
          code: 'not_started',
        );
      case 'wrong_mode':
        throw ConflictError(
          'No es el modo asíncrono',
          code: 'wrong_mode',
        );
      case 'invalid_prompt_type':
        throw ValidationError(
          'prompt_type',
          'Tipo de prompt no válido',
        );
      case 'no_prompts_available':
        throw const NotFoundError('Prompt');
      case 'rounds_exhausted':
        throw ConflictError(
          'Ya completaste tus rondas de esta partida',
          code: 'rounds_exhausted',
        );
      default:
        throw const ServerError('Unexpected submit_minigame_async_answer response');
    }
  }

  /// Uploads the ENCRYPTED image ciphertext bytes to the private
  /// `minigame_images` bucket at `<sessionId>/<round>/<uuid>.bin` and returns
  /// the object path (the `image_storage_path` column value). The server only
  /// ever stores the ciphertext blob — never the key, never the plaintext.
  Future<String> uploadMinigameImage(
    String sessionId,
    int round,
    Uint8List ciphertextBytes,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final path = '$sessionId/$round/${const Uuid().v4()}.bin';
    await resilient(
      () => client
          .storage
          .from('minigame_images')
          .uploadBinary(path, ciphertextBytes),
      timeout: AppConstants.minigameImageUploadTimeout,
      maxRetries: AppConstants.minigameImageUploadMaxRetries,
      initialDelay: AppConstants.minigameImageUploadRetryInitialDelay,
      backoffFactor: AppConstants.minigameImageUploadRetryBackoffFactor,
    );
    return path;
  }

  /// Signed URL (1h) for a participant to download the ENCRYPTED image blob —
  /// the private bucket has no public URL.
  Future<String> getSignedMinigameImageUrl(String storagePath) async {
    return client.storage.from('minigame_images').createSignedUrl(storagePath, 3600);
  }

  /// Downloads the ENCRYPTED image blob at [storagePath] from the private
  /// `minigame_images` bucket (the authenticated storage download — the
  /// bucket's read policy is participant-gated, so the caller's auth token
  /// bounds the read exactly like every other storage read). Returns the raw
  /// ciphertext bytes, or null when the download fails (the caller renders no
  /// image then).
  ///
  /// This is the read-side counterpart of [uploadMinigameImage]: the server
  /// never holds the plaintext — the app fetches the blob and
  /// `MinigameCipher.decryptAnswerImageBytes` recovers the image locally.
  Future<Uint8List?> downloadMinigameImageBytes(String storagePath) async {
    try {
      return await client.storage.from('minigame_images').download(storagePath);
    } catch (_) {
      return null;
    }
  }

  /// Reacts to an arbitrary COMPLETED round via `react_minigame_round`
  /// (202_minigame_play_v2) — the async reactable-rounds list. The caller
  /// cannot be the round's subject; a passed round rejects reactions.
  Future<void> reactToRound(
    String sessionId, {
    required int round,
    required ReactionKind reaction,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'react_minigame_round',
      params: {
        'p_session_id': sessionId,
        'p_round': round,
        'p_reaction': reaction.wire,
      },
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'submitted':
        return;
      case 'not_authenticated':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        );
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_allowed':
        throw PermissionError();
      case 'session_not_active':
        throw ConflictError(
          'La partida ya terminó',
          code: 'session_not_active',
        );
      case 'too_fast':
        // Controlled-spam window (see submitReaction): the write was dropped.
        return;
      case 'answer_pending':
        throw ConflictError(
          'La ronda aún no se puede valorar',
          code: 'answer_pending',
        );
      case 'own_round':
        throw ConflictError(
          'No puedes reaccionar a tu propia ronda',
          code: 'own_round',
        );
      case 'invalid_reaction':
        throw ValidationError('reaction', 'Reacción no válida');
      case 'already_reacted':
        throw ConflictError(
          'Ya reaccionaste con un emoji — no puedes pasar en esta ronda',
          code: 'already_reacted',
        );
      case 'already_passed':
        throw ConflictError(
          'Ya pasaste — no puedes reaccionar con un emoji en esta ronda',
          code: 'already_passed',
        );
      default:
        throw const ServerError('Unexpected react_minigame_round response');
    }
  }

  /// Sets/updates the caller's temp nickname for [sessionId] via
  /// `set_minigame_alias` (202_minigame_play_v2 anonymous mode). Participant-
  /// only; streams realtime via the `minigame_aliases` publication. Returns
  /// the persisted alias.
  Future<String> setAlias(String sessionId, String alias) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'set_minigame_alias',
      params: {'p_session_id': sessionId, 'p_alias': alias},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'alias_set':
        return result['alias'] as String? ?? alias;
      case 'not_authenticated':
        throw const MinigameSessionRejectedException(
          MinigameSessionRejection.notAuthenticated,
        );
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_allowed':
        throw PermissionError();
      case 'session_not_active':
        throw ConflictError(
          'La partida ya terminó',
          code: 'session_not_active',
        );
      case 'invalid_alias':
        throw ValidationError('alias', 'Apodo no válido');
      case 'alias_taken':
        throw ValidationError('alias', 'Ese apodo ya está en uso');
      default:
        throw const ServerError('Unexpected set_minigame_alias response');
    }
  }

  /// The temp nicknames of [sessionId] (`minigame_aliases`, RLS-bounded to
  /// participants) — the anonymous-mode display names.
  Future<Map<String, String>> getAliases(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client
        .from('minigame_aliases')
        .select('participant_id, alias')
        .eq('session_id', sessionId);
    return {
      for (final row in res)
        if (row['participant_id'] is String && row['alias'] is String)
          row['participant_id'] as String: row['alias'] as String,
    };
  }

  /// Upserts one sender-key distribution bundle row (202_minigame_play_v2
  /// E2EE): the sender's ciphertext envelope addressed to [recipientId]. The
  /// sender writes only their own rows (RLS `mgs_bundles_insert_own`).
  Future<void> putE2eeBundle(
    String sessionId, {
    required String senderId,
    required String recipientId,
    required String bundleCiphertext,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    await client.from('minigame_e2ee_bundles').upsert(
      {
        'session_id': sessionId,
        'sender_id': senderId,
        'recipient_id': recipientId,
        'bundle_ciphertext': bundleCiphertext,
      },
      onConflict: 'session_id,sender_id,recipient_id',
    );
  }

  /// Reads the sender-key distribution bundles addressed to the caller
  /// (RLS `mgs_bundles_read_recipient`) — the E2EE key delivery seam.
  Future<List<Map<String, dynamic>>> getE2eeBundles(String sessionId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client
        .from('minigame_e2ee_bundles')
        .select('session_id, sender_id, recipient_id, bundle_ciphertext')
        .eq('session_id', sessionId)
        .eq('recipient_id', user.id);
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Flags the caller as a round-key REQUESTER for [sessionId]
  /// (206_minigame_key_request, 2026-09-03): a participant who lost its
  /// device-local E2EE state (reinstall / data clear regenerated the identity,
  /// so the pairwise self-heal can never decrypt the host's old-identity
  /// bundles) appends itself to `state.key_requests`. ANY other participant
  /// who still holds the key history observes the marker and re-wraps it to
  /// the requester's CURRENT identity. The server only brokers the marker —
  /// no key material crosses this RPC.
  Future<void> requestMinigameRoundKeys(String sessionId) async {
    final res = await client.rpc(
      'request_minigame_round_keys',
      params: {'p_session_id': sessionId},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'requested':
      case 'resolved':
        return;
      case 'not_authenticated':
        throw const UnauthorizedError();
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_allowed':
        throw PermissionError();
      case 'session_not_active':
        throw ConflictError('La partida ya terminó', code: 'session_not_active');
      case 'not_started':
        throw ConflictError(
          'La partida no está en juego',
          code: 'not_started',
        );
      default:
        throw const ServerError('Unexpected request_minigame_round_keys response');
    }
  }

  /// A HOLDER clears a served round-key requester [requesterId] from
  /// [sessionId]'s `state.key_requests` (206_minigame_key_request) AFTER it
  /// successfully re-wrapped its key history to that peer via the bundle seam.
  /// Stops the ring from re-serving. Gates: participant-only, never self-clear.
  Future<void> resolveMinigameKeyRequest(
    String sessionId, {
    required String requesterId,
  }) async {
    final res = await client.rpc(
      'resolve_minigame_key_request',
      params: {
        'p_session_id': sessionId,
        'p_requester': requesterId,
      },
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'resolved':
      case 'requested':
        return;
      case 'not_authenticated':
        throw const UnauthorizedError();
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_allowed':
        throw PermissionError();
      case 'self_resolve':
        throw PermissionError();
      case 'session_not_active':
        throw ConflictError('La partida ya terminó', code: 'session_not_active');
      default:
        throw const ServerError('Unexpected resolve_minigame_key_request response');
    }
  }

  /// Sets the current user's Ready flag for [sessionId] via the
  /// `set_minigame_ready` SECURITY DEFINER RPC (180_minigame_lobby) — the
  /// authoritative per-participant ready map lives on the
  /// `minigame_game_state` row, so the whole lobby sees the toggle through
  /// the existing realtime subscription. Gates: participant/invitee/group
  /// member + active session (typed jsonb statuses).
  Future<void> setReady(String sessionId, bool ready) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'set_minigame_ready',
      params: {'p_session_id': sessionId, 'p_ready': ready},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'ready':
        return;
      case 'not_authenticated':
        throw const UnauthorizedError();
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_allowed':
        throw PermissionError();
      case 'session_not_active':
        throw ConflictError(
          'La partida ya terminó',
          code: 'session_not_active',
        );
      default:
        throw const ServerError('Unexpected set_minigame_ready response');
    }
  }

  /// The partida lobby's presence roster for [sessionId]
  /// (180_minigame_lobby): `{id, username, avatar_url}` rows for every
  /// participant, resolved in ONE round trip through the security-barrier
  /// `user_search_view` (deleted + blocked excluded) — works for NON-friends
  /// unlike `get_friend_profiles`. Gates: participant / invitee / group
  /// member (I-57 typed-jsonb-status contract).
  Future<List<Map<String, dynamic>>> getMinigameParticipants(
    String sessionId,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'get_minigame_participants',
      params: {'p_session_id': sessionId},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'ok':
        final roster = result['participants'];
        if (roster is! List) return const [];
        return roster
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      case 'not_authenticated':
        throw const UnauthorizedError();
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_allowed':
        throw PermissionError();
      default:
        throw const ServerError('Unexpected get_minigame_participants response');
    }
  }

  /// Removes [userId] from [sessionId]'s participants via the
  /// `remove_minigame_participant` SECURITY DEFINER RPC (180_minigame_lobby)
  /// — CREATOR-ONLY, backend-enforced via `participants[0]` (`not_creator`).
  /// In one server transaction: the removed player's wager escrow is refunded
  /// (GWAG `minigame_refund`), they leave `participants`, their invite closes
  /// and their ready flag clears. The creator can never remove themself.
  Future<void> removeParticipant(String sessionId, String userId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final res = await client.rpc(
      'remove_minigame_participant',
      params: {'p_session_id': sessionId, 'p_user_id': userId},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    switch (result['status']) {
      case 'removed':
        return;
      case 'not_authenticated':
        throw const UnauthorizedError();
      case 'session_not_found':
        throw const NotFoundError('Partida');
      case 'not_creator':
        throw PermissionError();
      case 'session_not_active':
        throw ConflictError(
          'La partida ya terminó',
          code: 'session_not_active',
        );
      case 'not_participant':
        throw const NotFoundError('Participante');
      default:
        throw const ServerError(
          'Unexpected remove_minigame_participant response',
        );
    }
  }

  /// Live subscription to one session's game-state row changes
  /// (150_minigame_play — init / reveal / advance / complete stream live to
  /// every participant via the `minigame_game_state` realtime publication).
  ///
  /// Returns the channel — the caller owns the unsubscribe handle. Rows are
  /// ALSO delivered through [minigameGameStateProvider]
  /// (lib/features/minigames/providers/minigames_providers.dart).
  RealtimeChannel subscribeToGameState(String sessionId) {
    return realtime.subscribeToChannel(
      'minigame-game-state:$sessionId',
      PostgresChangeEvent.update,
      'minigame_game_state',
      (_) {},
    );
  }
}
