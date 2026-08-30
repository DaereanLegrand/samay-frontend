import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/realtime_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/truth_dare.dart';
import 'package:samay/features/notifications/providers/notifications_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Number of pending minigame invites the current user has NOT read yet —
/// derived from the notification center (2026-08-27 red-circle badge
/// directive). The 140_minigame_invites pipeline inserts a `minigame_invite`
/// notification when an invite lands, so the unread count of that type IS
/// the pending-invite count — no extra query, live via the notification
/// center's realtime subscription.
///
/// Zero while the notifications list is loading (a red badge must never
/// flash from a stale/absent value).
final pendingMinigameInvitesProvider = Provider<int>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull;
  if (notifications == null) return 0;
  return notifications
      .where((n) => n.type == 'minigame_invite' && !n.read)
      .length;
});

/// Pending minigame invites grouped by game type — the per-game feed badges
/// (170_minigame_invite_badges). Derived from the unread `minigame_invite`
/// notifications, using the `gameType` the notify trigger now embeds in
/// `data` (no extra round-trip). Missing/unknown types fall under a `null`
/// key, which the feed simply ignores (the badge only renders for the five
/// known tiles).
final pendingMinigameInvitesByTypeProvider = Provider<Map<String?, int>>((ref) {
  final notifications = ref.watch(notificationsProvider).valueOrNull;
  if (notifications == null) return const {};
  final byType = <String?, int>{};
  for (final n in notifications) {
    if (n.type != 'minigame_invite' || n.read) continue;
    final gameType = n.data?['gameType'] as String?;
    byType[gameType] = (byType[gameType] ?? 0) + 1;
  }
  return byType;
});

/// The current user's PENDING minigame invites as SESSION rows — the
/// invitee-side "partida-N ready to accept" list (170_minigame_invite_badges).
/// RLS bounds every read (`mi_read_own` invites + `ms_read_invitee` sessions),
/// so this never leaks a partida the user was not invited to.
class MyPendingInvitesNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<List<Map<String, dynamic>>> build() async {
    // Live via the notification stream: any new invite (or read-state
    // change) invalidates notificationsProvider — awaiting it here re-runs
    // the list so the invitee's "partida-N ready to accept" rows follow
    // realtime without a pull (the `...future` watch is the settled pattern
    // from recentFriendsProvider — a plain ref.watch would double-build).
    await ref.watch(notificationsProvider.future);
    return _service.listMyPendingInvites();
  }

  /// Re-runs [build] after an accept/decline or a realtime invite landing
  /// (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// The current user's pending minigame invites (session rows, newest invite
/// first). Kept fresh by the shell's [MinigameInvitesRealtimeListener] via
/// the notification realtime stream.
final myPendingInvitesProvider =
    AsyncNotifierProvider<MyPendingInvitesNotifier, List<Map<String, dynamic>>>(
      MyPendingInvitesNotifier.new,
    );

/// Sessions of one group, newest first (GMCR foundation — the game list the
/// hub screen renders). Family over the group id so each group carries its
/// own list, and the create/join actions live on this notifier so the list
/// refreshes after every mutation.
class MinigameSessionsNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<List<Map<String, dynamic>>> build(String groupId) async {
    return _service.listSessions(groupId);
  }

  /// Re-runs [build] (pull-to-refresh, finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Creates a session of [type] in this group with an optional [wager]
  /// (0 = no wager), an optional partida [name] (160_minigame_names) and
  /// optional [inviteeIds] (any searchable user — the friends-only + blocked
  /// gates are enforced server-side) and reloads the list.
  ///
  /// Server rejections surface as the typed [MinigameSessionRejectedException]
  /// (insufficient shards / not a member / invalid game / invitee gates) —
  /// the screen maps [MinigameSessionRejection] to friendly localized
  /// messages.
  Future<String> create(
    MinigameType type,
    int wager, {
    List<String> inviteeIds = const [],
    String? name,
  }) async {
    final id = await _service.createSession(
      arg,
      type,
      wager,
      inviteeIds: inviteeIds,
      name: name,
    );
    await refresh();
    return id;
  }

  /// Joins the session [id] (self only) and reloads the list.
  Future<void> join(String id) async {
    await _service.joinSession(id);
    await refresh();
  }
}

/// The group's minigame sessions (RLS `ms_read_group_member`).
final minigameSessionsProvider =
    AsyncNotifierProvider.family<
      MinigameSessionsNotifier,
      List<Map<String, dynamic>>,
      String
    >(MinigameSessionsNotifier.new);

/// The current user's DIRECT sessions (group_id IS NULL), newest first —
/// the direct-play hub (direct-minigames 2026-08-27). RLS
/// `ms_read_direct_participant` bounds the read to sessions where the caller
/// is a participant (creator is participant[0]); the group-scoped
/// [minigameSessionsProvider] stays for the group hub.
class MyMinigameSessionsNotifier
    extends AsyncNotifier<List<Map<String, dynamic>>> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<List<Map<String, dynamic>>> build() {
    return _service.listMySessions();
  }

  /// Re-runs [build] (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Creates a DIRECT session (null group) of [type] with an optional
  /// [wager] (0 = no wager), an optional partida [name] (160_minigame_names)
  /// and optional [inviteeIds] (some games are single-player — the server
  /// freezes the player_limit from the creator's tier). Server rejections
  /// surface as the typed [MinigameSessionRejectedException] (insufficient
  /// shards / invitee gates / player limit) and reload the direct list.
  Future<String> create(
    MinigameType type,
    int wager, {
    List<String> inviteeIds = const [],
    String? name,
  }) async {
    final id = await _service.createSession(
      null,
      type,
      wager,
      inviteeIds: inviteeIds,
      name: name,
    );
    await refresh();
    return id;
  }

  /// Joins the direct session [id] (self only) and reloads.
  Future<void> join(String id) async {
    await _service.joinSession(id);
    await refresh();
  }
}

/// The current user's direct minigame sessions.
final myMinigameSessionsProvider =
    AsyncNotifierProvider<
      MyMinigameSessionsNotifier,
      List<Map<String, dynamic>>
    >(MyMinigameSessionsNotifier.new);

/// Live status of one session: the initial row from [MinigameService.getSession]
/// merged with realtime row changes on the session's channel (I-52
/// `realtimeChannelProvider` lifecycle — the GMCR Realtime sync contract).
///
/// The future detail screen watches this instead of re-fetching: every
/// `minigame_sessions` UPDATE (status flips, participant joins, winner set)
/// lands here while the session is open.
class MinigameSessionStatusNotifier
    extends FamilyAsyncNotifier<Map<String, dynamic>, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<Map<String, dynamic>> build(String sessionId) async {
    // Live updates ride the I-52 realtime lifecycle provider; ref.listen (not
    // watch) so the notifier's own state stays in control while emissions are
    // merged in.
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      realtimeChannelProvider((
        channelName: 'minigame-session:$sessionId',
        table: 'minigame_sessions',
        event: PostgresChangeEvent.update,
      )),
      (_, next) {
        final row = next.valueOrNull;
        if (row == null || row['id'] != sessionId) return;
        // Only apply once the build's own value is set — mutating state while
        // the notifier is still building trips Riverpod's cycle assertion.
        if (state.hasValue) {
          state = AsyncData(row);
        }
      },
    );

    final row = await _service.getSession(sessionId);
    if (row == null) throw Exception('Session not found');
    return row;
  }
}

/// One session's live row by id (family).
final sessionStatusProvider =
    AsyncNotifierProvider.family<
      MinigameSessionStatusNotifier,
      Map<String, dynamic>,
      String
    >(MinigameSessionStatusNotifier.new);

/// The current user's invite row for one session (null when they are not
/// invited), plus the accept/decline actions. Family by session id so each
/// session detail carries its own invite state.
class MinigameInviteNotifier
    extends FamilyAsyncNotifier<Map<String, dynamic>?, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<Map<String, dynamic>?> build(String sessionId) async {
    return _service.myInviteForSession(sessionId);
  }

  /// Re-runs [build] after an accept/decline (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Accepts the pending invite (self) and reloads the invite + session
  /// status (participants grow). A finished session surfaces the typed
  /// `session_finished` ConflictError — the screen maps it to the
  /// invite-closed message.
  ///
  /// Stale-state repair (2026-08-30): accept also refreshes the roster (the
  /// lobby must show the new participant immediately), the pending-invite
  /// list (the game page must drop the "Invitación pendiente" row) and marks
  /// the invite's notification read (the feed tile's red badge clears in the
  /// same tap). Without these, only a hot restart reflected the accept.
  Future<void> accept() async {
    final inviteId = state.valueOrNull?['id'] as String?;
    if (inviteId == null) return;
    await _service.acceptInvite(inviteId);
    await refresh();
    ref.invalidate(sessionStatusProvider(arg));
    ref.invalidate(minigameParticipantsProvider(arg));
    ref.invalidate(myPendingInvitesProvider);
    await _markInviteNotificationRead(inviteId);
  }

  /// Declines the pending invite and reloads. The pending-invite list is
  /// invalidated too so the "Invitación pendiente" row disappears without a
  /// hot restart (2026-08-30 stale-state repair).
  Future<void> decline() async {
    final inviteId = state.valueOrNull?['id'] as String?;
    if (inviteId == null) return;
    await _service.declineInvite(inviteId);
    await refresh();
    ref.invalidate(myPendingInvitesProvider);
    await _markInviteNotificationRead(inviteId);
  }

  /// Marks the invite's notification read (best-effort — the notification
  /// center's read-on-tap is the fallback if the row is missing).
  Future<void> _markInviteNotificationRead(String inviteId) async {
    final notifications = ref.read(notificationsProvider).valueOrNull;
    if (notifications == null) return;
    for (final n in notifications) {
      if (n.type == 'minigame_invite' &&
          n.data?['inviteId'] == inviteId &&
          !n.read) {
        await ref.read(notificationsProvider.notifier).markRead(n.id);
        return;
      }
    }
  }
}

/// The current user's invite row for one session (family by session id).
final minigameInviteProvider =
    AsyncNotifierProvider.family<
      MinigameInviteNotifier,
      Map<String, dynamic>?,
      String
    >(MinigameInviteNotifier.new);

/// Owns the current user's minigame-invite privacy switch
/// (`users.minigame_invite_friends_only`, default OFF = anyone may invite).
/// Reads + persists through [UserService] (RPC under the profile-RPC
/// lockdown), mirroring the Party Finder opt-in provider pattern.
class MinigameInviteFriendsOnlyNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(userServiceProvider).getMinigameInviteFriendsOnly();
  }

  /// Persists the toggle and flips the provider state on success; failures
  /// surface as [AsyncError] (established provider convention).
  Future<void> setFriendsOnly(bool value) async {
    try {
      await ref.read(userServiceProvider).setMinigameInviteFriendsOnly(value);
      state = AsyncData(value);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

/// The current user's minigame-invite privacy switch (false = anyone may
/// invite me).
final minigameInviteFriendsOnlyProvider =
    AsyncNotifierProvider<MinigameInviteFriendsOnlyNotifier, bool>(
      MinigameInviteFriendsOnlyNotifier.new,
    );

/// Live play-engine state of one session (150_minigame_play): the
/// [MinigameGameState] row from the RPC family merged with realtime row
/// changes on the game-state channel — init / reveal / advance / complete
/// stream live to every participant.
///
/// NO auto-init (180_minigame_lobby): a session with no game-state row yet
/// (`not_started`) stays a lobby with an empty skeleton — starting is the
/// CREATOR's explicit `start()` action (backend-enforced via `not_creator`).
/// The prior auto-init-on-read made the play screen the implicit starter,
/// which is wrong now that the lobby is the entry point.
class MinigameGameStateNotifier
    extends FamilyAsyncNotifier<MinigameGameState, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<MinigameGameState> build(String sessionId) async {
    // Live updates ride the I-52 realtime lifecycle provider (mirror of
    // MinigameSessionStatusNotifier); the game-state row key is session_id.
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      realtimeChannelProvider((
        channelName: 'minigame-game-state:$sessionId',
        table: 'minigame_game_state',
        event: PostgresChangeEvent.update,
      )),
      (_, next) {
        final row = next.valueOrNull;
        if (row == null || row['session_id'] != sessionId) return;
        if (state.hasValue) {
          state = AsyncData(MinigameGameState.fromRow(row));
        }
      },
    );

    final row = await _service.getMinigameGameState(sessionId);
    if (row == null) {
      // Not started — the lobby's empty skeleton (phase `setup`, no subject).
      return MinigameGameState.fromRow({
        'session_id': sessionId,
        'game_type': '',
        'state': <String, dynamic>{},
        'rounds': <dynamic>[],
        'ready': <String, dynamic>{},
      });
    }
    return MinigameGameState.fromRow(row);
  }

  /// Re-runs [build] (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Reveals a random prompt of [kind] (the server draws it randomly) and
  /// reloads the state.
  Future<void> reveal(TruthDareKind kind) async {
    await _service.revealMinigamePrompt(arg, kind.wire);
    await refresh();
  }

  /// Toggles the current user's Ready flag for the lobby (180_minigame_lobby)
  /// via `set_minigame_ready` and reloads the state — the authoritative ready
  /// map update streams back through the realtime channel and the roster
  /// recomputes.
  Future<void> setReady(bool ready) async {
    await _service.setReady(arg, ready);
    await refresh();
  }

  /// Starts the partida (creator-only, backend-enforced via `not_creator`):
  /// calls `init_minigame_game_state` (the lobby → countdown transition, which
  /// seeds the skeleton + random first subject + the 5s deadline +
  /// next_subject_id) and reloads the state. The whole lobby sees the
  /// countdown via the realtime stream.
  Future<void> start() async {
    await _service.initMinigameGameState(arg);
    await refresh();
  }

  /// Cancels the pre-play countdown (creator-only, backend-enforced via
  /// `not_creator`): calls `cancel_minigame_start` (190_minigame_countdown),
  /// which resets the game-state row back to a setup skeleton so every
  /// participant stays on the match/lobby screen. Reloads the state.
  Future<void> cancelStart() async {
    await _service.cancelMinigameStart(arg);
    await refresh();
  }

  /// The creator removes [userId] from the lobby (180_minigame_lobby):
  /// refunds the escrow, drops the participant, closes their invite, clears
  /// their ready flag — all server-side. Reloads the roster + session.
  Future<void> removeParticipant(String userId) async {
    await _service.removeParticipant(arg, userId);
    await refresh();
    ref.invalidate(sessionStatusProvider(arg));
    ref.invalidate(minigameParticipantsProvider(arg));
    ref.invalidate(myPendingInvitesProvider);
  }

  /// Closes the current turn with [outcome] and advances to the next
  /// (server-random subject) — the completed-round record rides the current
  /// skeleton's subject/prompt.
  Future<void> advance({PromptOutcome outcome = PromptOutcome.done}) async {
    final current = state.valueOrNull;
    final round = GameRoundRecord(
      subjectId: current?.skeleton.subjectId ?? '',
      promptType: current?.skeleton.promptType,
      promptId: current?.skeleton.prompt?['id'] as String?,
      outcome: outcome,
    );
    await _service.advanceMinigameTurn(arg, round.toJson());
    await refresh();
  }

  /// Ends the party game (draw settlement server-side) and reloads.
  Future<void> complete() async {
    await _service.completeMinigameGame(arg);
    await refresh();
  }
}

/// One session's live play-engine state (family by session id).
final minigameGameStateProvider =
    AsyncNotifierProvider.family<
      MinigameGameStateNotifier,
      MinigameGameState,
      String
    >(MinigameGameStateNotifier.new);

/// One lobby participant row — the id + profile from
/// [MinigameService.getMinigameParticipants] with the LIVE ready flag merged
/// from [minigameGameStateProvider]'s authoritative `ready` map
/// (180_minigame_lobby).
class MinigameParticipant {
  const MinigameParticipant({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.ready,
  });

  final String id;
  final String username;
  final String? avatarUrl;

  /// Whether the participant has toggled Ready (live via the
  /// `minigame_game_state` realtime stream).
  final bool ready;

  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  /// A copy with a new ready flag — the granular ready-state sync (2026-08-30)
  /// recomputes ONLY the affected row instead of rebuilding the whole roster.
  MinigameParticipant copyWithReady(bool ready) => MinigameParticipant(
    id: id,
    username: username,
    avatarUrl: avatarUrl,
    ready: ready,
  );
}

/// The partida lobby's realtime participant roster for one session: the
/// names/avatars from `get_minigame_participants` (one batched call, works
/// for non-friends) merged with each participant's LIVE ready flag from the
/// play-engine state's authoritative `ready` map.
///
/// Granular ready sync (2026-08-30): the roster is fetched ONCE in [build].
/// Live ready toggles stream in through [minigameGameStateProvider]'s
/// realtime channel; [ref.listen] diffs the ready map and updates ONLY the
/// changed rows in place (no re-fetch, no whole-list rebuild — a participant
/// flipping ready must not ripple the whole lobby on every device).
/// Participant joins/removes arrive through the session row's realtime stream
/// (the `minigame_sessions` realtime membership added in 180) and refresh the
/// roster via `sessionStatusProvider`.
class MinigameParticipantsNotifier
    extends FamilyAsyncNotifier<List<MinigameParticipant>, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<List<MinigameParticipant>> build(String sessionId) async {
    // Live ready flags: the authoritative map rides the play-engine state.
    ref.listen<AsyncValue<MinigameGameState>>(
      minigameGameStateProvider(sessionId),
      (_, next) {
        final nextReady = next.valueOrNull?.ready;
        if (nextReady == null) return;
        _applyReady(nextReady);
      },
    );

    // 2026-08-30 stale-state repair: the roster must follow the session's
    // AUTHORITATIVE participants array, not just realtime UPDATEs (which can
    // be dropped). Whenever the set of participant ids changes — the host
    // created the session after this client opened the lobby, someone joined,
    // was removed, or accepted an invite — the roster re-fetches so a new
    // player (or a kick) shows up immediately, even on a hot reload where
    // provider state is preserved.
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      sessionStatusProvider(sessionId),
      (_, next) {
        // Only react once the roster has an initial value — during the first
        // load a session emission would spuriously re-fetch (no double-build).
        if (!state.hasValue) return;
        final nextIds = _participantIdsOf(next.valueOrNull);
        if (nextIds.isEmpty) return;
        final currentIds = {
          for (final p in state.valueOrNull ?? const <MinigameParticipant>[])
            p.id,
        };
        if (currentIds.length != nextIds.length ||
            !currentIds.containsAll(nextIds)) {
          // Re-fetch the roster in place (no double-build: this listen only
          // fires on an actual participants change).
          refresh();
        }
      },
    );

    final rows = await _service.getMinigameParticipants(sessionId);
    // Read the ready map AFTER the fetch so the initial merge is never stale.
    final ready = ref.read(minigameGameStateProvider(sessionId)).valueOrNull;
    return [
      for (final row in rows)
        MinigameParticipant(
          id: row['id'] as String,
          username: row['username'] as String? ?? '',
          avatarUrl: row['avatar_url'] as String?,
          ready: ready?.isReady(row['id'] as String) ?? false,
        ),
    ];
  }

  /// The participant ids of a session row (tolerant — missing/unparseable
  /// yields an empty set).
  static Set<String> _participantIdsOf(Map<String, dynamic>? session) {
    final raw = session?['participants'];
    if (raw is! List) return const {};
    return {
      for (final id in raw)
        if (id is String) id,
    };
  }

  /// Updates ONLY the rows whose ready flag changed — the roster keeps its
  /// order/profiles and never re-fetches on a ready toggle (2026-08-30).
  void _applyReady(Map<String, bool> ready) {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = [
      for (final participant in current)
        if (ready[participant.id] != null &&
            ready[participant.id] != participant.ready)
          participant.copyWithReady(ready[participant.id]!)
        else
          participant,
    ];
    state = AsyncData(updated);
  }

  /// Re-runs [build] after a start / remove (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// One session's realtime participant roster (family by session id).
final minigameParticipantsProvider =
    AsyncNotifierProvider.family<
      MinigameParticipantsNotifier,
      List<MinigameParticipant>,
      String
    >(MinigameParticipantsNotifier.new);
