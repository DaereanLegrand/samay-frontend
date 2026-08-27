import 'package:samay/core/errors/app_error.dart';
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
      'participants, winner_id, created_at';

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

  /// The current user's DIRECT sessions (group_id IS NULL), newest first —
  /// the direct-play hub list. RLS `ms_read_direct_participant` bounds the
  /// read to sessions where the caller is a participant (the creator is
  /// participant[0]); the `group_id IS NULL` + `participants @> {uid}`
  /// filters mirror that server contract client-side.
  Future<List<Map<String, dynamic>>> listMySessions() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client
        .from('minigame_sessions')
        .select(_columns)
        .isFilter('group_id', null)
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
  Future<String> createSession(
    String? groupId,
    MinigameType type,
    int wager, {
    List<String> inviteeIds = const [],
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

  /// Flips the session lifecycle status (GMCR: `active` → `finished`) via the
  /// `finish_minigame_session` SECURITY DEFINER RPC (migration
  /// 20260813000001) — the client-side UPDATE is RLS-blocked
  /// (`minigame_sessions` has no UPDATE policy under FORCE RLS) and the
  /// settlement MUST happen server-side.
  ///
  /// The RPC settles the escrow in one transaction (GWAG §Wager Resolution):
  /// with a winner it credits `users.personal_shards` with the full pot and
  /// writes the `minigame_win` ledger row; with a null winner (draw) it
  /// refunds every participant (`minigame_refund`). This seam carries no
  /// winner id, so finishing through it resolves a wagered session as a
  /// draw — a future winner-aware caller can invoke `finish_minigame_session`
  /// directly with `p_winner_id`. Reactivating a finished session has no
  /// server contract and is rejected.
  Future<void> updateStatus(String id, MinigameStatus status) async {
    if (status != MinigameStatus.finished) {
      throw ConflictError(
        'Only MinigameStatus.finished has a server contract '
        '(finish_minigame_session); reactivation is not supported',
        code: 'reactivation_not_supported',
      );
    }

    final res = await client.rpc(
      'finish_minigame_session',
      params: {'p_session_id': id, 'p_winner_id': null, 'p_place': null},
    );
    final result = res is Map
        ? Map<String, dynamic>.from(res)
        : <String, dynamic>{};
    final statusResponse = result['status'] as String?;

    switch (statusResponse) {
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
      case 'invalid_winner':
        throw ConflictError('Invalid winner', code: 'invalid_winner');
      default:
        throw const ServerError('Unexpected finish_minigame_session response');
    }
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
