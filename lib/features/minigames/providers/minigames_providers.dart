import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/config/app_constants.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/realtime_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/utils/async_ops.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/minigames/logic/minigame_cipher.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/features/minigames/logic/truth_dare.dart';
import 'package:samay/features/notifications/providers/notifications_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// The E2EE answer cipher for one minigame session (202_minigame_play_v2):
/// the per-round key model — the host mints `K_r` and distributes it
/// pairwise through `minigame_e2ee_bundles`; answers are AES-GCM-encrypted
/// with the round's own key and only ciphertext ever reaches the server.
final minigameCipherProvider = Provider.family<MinigameCipher, String>((ref, sessionId) {
  final user = ref.watch(authStateProvider).valueOrNull?.user;
  final uid = user?['id'] as String? ?? '';
  return MinigameCipher(
    sessionId: sessionId,
    ownerUserId: uid,
    keyStore: ref.watch(e2eeKeyStoreProvider),
    sessionStore: ref.watch(e2eeSessionStoreProvider),
    prekeyService: ref.watch(e2eePrekeyServiceProvider),
    service: ref.watch(minigameServiceProvider),
  );
});

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
    final notifications = await ref.watch(notificationsProvider.future);
    final rows = await _service.listMyPendingInvites();
    // 2026-09-02: a session whose invite the user has ALREADY accepted (e.g.
    // a kicked-and-re-invited player who accepted again, or a stale realtime
    // read) must NOT show as a pending Accept/Decline row — the game landing
    // would otherwise list the partida as "pending" even though the user is a
    // participant. The session row already carries the authoritative
    // `participants` array, so drop any row where the caller is in it.
    final myId = ref.read(authStateProvider).valueOrNull?.user?['id'];
    final notYetJoined =
        rows.where((row) {
          final participants = row['participants'];
          if (participants is! List) return true;
          return myId == null || !participants.contains(myId);
        }).toList();
    // The invitee cannot read the inviter username (RLS user_search_view) or
    // the group name (RLS groups_read_member) for a session they are not yet a
    // member of. The notification trigger (200_minigame_invite_notice) embeds
    // them in the notification data, so attach them to each pending row here —
    // the accept surfaces show "from <inviter> / <group>" without re-querying.
    final bySessionId = <String, Map<String, dynamic>>{};
    for (final n in notifications) {
      if (n.type != 'minigame_invite') continue;
      final sessionId = n.data?['sessionId'] as String?;
      if (sessionId == null) continue;
      bySessionId[sessionId] = n.data!;
    }
    return [
      for (final row in notYetJoined)
        {
          ...row,
          if (row['inviterName'] == null)
            'inviterName': bySessionId[row['id']]?['inviterName'],
          if (row['groupName'] == null)
            'groupName': bySessionId[row['id']]?['groupName'],
        },
    ];
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
    int rounds = 5,
    int prizePositions = kDefaultPrizePositions,
    MinigamePlayMode playMode = MinigamePlayMode.byTurns,
    bool anonymous = false,
    int asyncRoundsPerPlayer = 1,
    DateTime? asyncEndsAt,
  }) async {
    final id = await _service.createSession(
      arg,
      type,
      wager,
      inviteeIds: inviteeIds,
      name: name,
      rounds: rounds,
      prizePositions: prizePositions,
      playMode: playMode,
      anonymous: anonymous,
      asyncRoundsPerPlayer: asyncRoundsPerPlayer,
      asyncEndsAt: asyncEndsAt,
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

/// One group's chat notices (216_minigame_group_message, 2026-09-15) — the
/// "match created" bubbles [ChatThreadView] renders inline as a direct access
/// to the minigame. Family over the group id; invalidated by
/// [MinigameSessionsRealtimeListener] on any session row event (the notice is
/// written in the same transaction as the session insert).
class GroupMinigameMessagesNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<List<Map<String, dynamic>>> build(String groupId) {
    return _service.listGroupMinigameMessages(groupId);
  }

  /// Re-runs [build] (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

final groupMinigameMessagesProvider =
    AsyncNotifierProvider.family<
      GroupMinigameMessagesNotifier,
      List<Map<String, dynamic>>,
      String
    >(GroupMinigameMessagesNotifier.new);

/// The current user's sessions — DIRECT and GROUP — newest first, where the
/// caller is a participant (creator is participant[0]). RLS bounds the read
/// (`ms_read_direct_participant` / `ms_read_group_member`); the client-side
/// `participants @> {uid}` filter keeps it to the caller's own games. This is
/// the direct hub's list AND the per-game PARTIDAS EN CURSO source, so group
/// partidas surface there too (each row keeps its `group_id` for the group
/// tag); the group-scoped [minigameSessionsProvider] stays for the group hub.
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
    int rounds = 5,
    int prizePositions = kDefaultPrizePositions,
    MinigamePlayMode playMode = MinigamePlayMode.byTurns,
    bool anonymous = false,
    int asyncRoundsPerPlayer = 1,
    DateTime? asyncEndsAt,
  }) async {
    final id = await _service.createSession(
      null,
      type,
      wager,
      inviteeIds: inviteeIds,
      name: name,
      rounds: rounds,
      prizePositions: prizePositions,
      playMode: playMode,
      anonymous: anonymous,
      asyncRoundsPerPlayer: asyncRoundsPerPlayer,
      asyncEndsAt: asyncEndsAt,
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

/// The OPEN LOBBY (210_minigame_public): published partidas anyone can see
/// and join, keyed by game_type wire value (empty string = every game).
class PublicMinigamesNotifier
    extends FamilyAsyncNotifier<List<Map<String, dynamic>>, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<List<Map<String, dynamic>>> build(String gameType) {
    return _service.listPublicMinigames(
      gameType: gameType.isEmpty ? null : gameType,
    );
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _service.listPublicMinigames(
        gameType: arg.isEmpty ? null : arg,
      ),
    );
  }

  /// Joins a published partida (no invite needed) and refreshes the feed.
  Future<void> join(String sessionId) async {
    await _service.joinSession(sessionId);
    ref.invalidate(myMinigameSessionsProvider);
    await refresh();
  }
}

/// Open-lobby feed for [gameType] (the wire value, or '' for all games).
final publicMinigamesProvider =
    AsyncNotifierProvider.family<
      PublicMinigamesNotifier,
      List<Map<String, dynamic>>,
      String
    >(PublicMinigamesNotifier.new);

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
        if (!state.hasValue) return;
        // 2026-09-02: the roster diff depends on the authoritative
        // `participants` array (REPLICA IDENTITY FULL now ships it on every
        // UPDATE). Guard against a partial payload anyway — if the update
        // omitted the array, keep the last full row so a stale roster never
        // displaces the real one.
        if (row['participants'] is! List) return;
        state = AsyncData(row);
      },
    );

    final row = await _service.getSession(sessionId);
    if (row == null) throw Exception('Session not found');
    return row;
  }

  /// Publishes / unpublishes the partida to the open lobby
  /// (210_minigame_public, host-only — backend-enforced via `not_creator`)
  /// and reloads the row so the lobby switch reflects the server truth.
  Future<void> setPublic(bool isPublic) async {
    await _service.setMinigamePublic(arg, isPublic);
    final row = await _service.getSession(arg);
    if (row != null) state = AsyncData(row);
    ref.invalidate(publicMinigamesProvider);
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
  ///
  /// E2EE round-key distribution (2026-08-31): after the accept lands, the
  /// HOST hands this new player the full `K_1..K_N` history it has minted so
  /// far (best-effort — a no-prekey peer is skipped and retried on the next
  /// roster change; a distribution failure never fails the accept).
  Future<void> accept() async {
    // Await the built value, not the possibly-loading state: the provider may
    // not be alive yet when invoked from the per-game list inline action, in
    // which case state.valueOrNull is null right after reading .notifier and
    // accept() would silently no-op (the RPC never runs, the detail then
    // still shows a pending invite). AsyncNotifier.future resolves with the
    // built invite row (and throws on error).
    final inviteId = (await future)?['id'] as String?;
    if (inviteId == null) return;
    await _service.acceptInvite(inviteId);
    await refresh();
    ref.invalidate(sessionStatusProvider(arg));
    ref.invalidate(minigameParticipantsProvider(arg));
    ref.invalidate(minigameInviteContextProvider(arg));
    ref.invalidate(myPendingInvitesProvider);
    await _markInviteNotificationRead(inviteId);
    await _distributeKeysOnAccept();
  }

  /// Best-effort E2EE history distribution to the roster at accept-time
  /// (2026-08-31): the new participant cannot decrypt any past round until
  /// the host hands them `K_1..K_N`. Carries the host's KNOWN round keys (the
  /// acceptor itself has no history yet, but the HOST-side accept — or the
  /// roster-change safety net) delivers the real history. Failures are logged
  /// and swallowed (best-effort contract).
  Future<void> _distributeKeysOnAccept() async {
    try {
      final myId = ref.read(authStateProvider).valueOrNull?.user?['id'];
      if (myId == null) {
        AppLogger.instance.warn(
          'minigame accept key distribution skipped session=$arg — no user',
        );
        return;
      }
      final session = ref.read(sessionStatusProvider(arg)).valueOrNull;
      final participants = (session?['participants'] as List?)?.cast<String?>();
      if (participants == null) return;
      final peers = [
        for (final p in participants)
          if (p != null && p != myId) p,
      ];
      final cipher = ref.read(minigameCipherProvider(arg));
      final history = await cipher.knownRoundKeys();
      AppLogger.instance.debug(
        'minigame accept key distribution session=$arg roster=${participants.length} '
        'peers=${peers.length} historyRounds=${history.keys.toList()}',
      );
      await cipher.distributeHistoryKeys(
        peerIds: peers,
        roundKeys: history,
      );
    } catch (e, st) {
      AppLogger.instance.warn('minigame accept key distribution skipped', '$st');
    }
  }

  /// Declines the pending invite and reloads. The pending-invite list is
  /// invalidated too so the "Invitación pendiente" row disappears without a
  /// hot restart (2026-08-30 stale-state repair).
  Future<void> decline() async {
    // Same await-the-built-value guard as accept(): a decline invoked from
    // the per-game list must not silently no-op because the provider was not
    // alive yet (state.valueOrNull would be null right after reading
    // .notifier while build() is still in flight).
    final inviteId = (await future)?['id'] as String?;
    if (inviteId == null) return;
    await _service.declineInvite(inviteId);
    await refresh();
    ref.invalidate(minigameInviteContextProvider(arg));
    ref.invalidate(myPendingInvitesProvider);
    await _markInviteNotificationRead(inviteId);
  }

  /// The HOST invites players into this ALREADY-CREATED session from the
  /// lobby (205_minigame_invite_lobby — the 2026-09-01 flow: create with zero
  /// invitees, then invite while waiting). Idempotent server-side; refreshes
  /// the pending-invite list (the invitee's "partida-N ready to accept" rows
  /// appear) and the session status. Typed rejections surface as
  /// [MinigameSessionRejectedException] (blocked / friends-only / cap).
  Future<void> invitePlayers(List<String> inviteeIds) async {
    if (inviteeIds.isEmpty) return;
    await _service.invitePlayers(arg, inviteeIds);
    ref.invalidate(myPendingInvitesProvider);
    ref.invalidate(sessionStatusProvider(arg));
    // The picker's "enviada/sent" tags must reflect the fresh pending rows.
    ref.invalidate(minigameInviteeStatesProvider(arg));
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

/// The narrow pending-invite CONTEXT for one session (family by session id):
/// the inviter's `{id, username, avatar_url}` + group name, or null when the
/// caller holds no invite. Backed by `get_minigame_invite_context`
/// (215_minigame_invite_context).
///
/// The pending lobby renders ONLY this — never `minigameParticipantsProvider`,
/// whose invite gate would otherwise stream the full roster into the client
/// before the invitee accepts (2026-09-11 directive).
class MinigameInviteContextNotifier
    extends FamilyAsyncNotifier<Map<String, dynamic>?, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<Map<String, dynamic>?> build(String sessionId) {
    return _service.getInviteContext(sessionId);
  }

  /// Re-runs [build] after an accept/decline (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// The pending-invite context (inviter + group name) for one session.
final minigameInviteContextProvider =
    AsyncNotifierProvider.family<
      MinigameInviteContextNotifier,
      Map<String, dynamic>?,
      String
    >(MinigameInviteContextNotifier.new);

/// The HOST-side per-invitee invite state for one session
/// (`{invitee_id: status}`) — the lobby picker's "enviada/sent" tag
/// (2026-09-02). RLS `mi_read_own` bounds it to invites the host created;
/// a declined invite deletes its row, so a declined/kicked player has no
/// entry and shows as a fresh invitee (a re-invite is a normal invite — no
/// special resend path).
final minigameInviteeStatesProvider =
    AsyncNotifierProvider.family<MinigameInviteeStatesNotifier,
        Map<String, String>, String>(MinigameInviteeStatesNotifier.new);

/// Notifier for [minigameInviteeStatesProvider].
class MinigameInviteeStatesNotifier
    extends FamilyAsyncNotifier<Map<String, String>, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<Map<String, String>> build(String sessionId) {
    return _service.inviteeStates(sessionId);
  }

  /// Re-runs [build] after an invite/remove (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

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

  /// Tracks the highest round the host has minted for this session so a round
  /// bump re-mints. Reset on [refresh] so a re-entered session re-arms.
  int? _mintedRound;

  @override
  Future<MinigameGameState> build(String sessionId) async {
    // Live updates ride the I-52 realtime lifecycle provider (mirror of
    // MinigameSessionStatusNotifier); the game-state row key is session_id.
    //
    // event: .all (not .update) — 2026-09-08 fix: `init_minigame_game_state`
    // INSERTs the very first row for a session that never had a Ready toggle
    // pressed (nobody upserted the row yet). An UPDATE-only subscription
    // never fires for that first write, so every OTHER participant's
    // countdown overlay silently never appears — only the host (who reads
    // its own RPC result directly, not via realtime) sees it. Subsequent
    // writes are UPDATEs either way, so widening to .all changes nothing for
    // the already-working path.
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      realtimeChannelProvider((
        channelName: 'minigame-game-state:$sessionId',
        table: 'minigame_game_state',
        event: PostgresChangeEvent.all,
      )),
      (_, next) {
        final row = next.valueOrNull;
        if (row == null || row['session_id'] != sessionId) return;
        final parsed = MinigameGameState.fromRow(row);
        if (state.hasValue) {
          final prevPhase = state.valueOrNull?.skeleton.phase;
          final prevRound = state.valueOrNull?.skeleton.round ?? 0;
          state = AsyncData(parsed);
          // The HOST mints + distributes round keys. Round 0 is minted
          // SYNCHRONOUSLY inside startMatch() (the host performs that flip
          // itself via start_minigame_match, so its own realtime listener
          // already reads prevPhase=playing and would never fire justStarted —
          // the 2026-08-31 race). This listener covers the ROUND BUMPS the
          // host observes from OTHER devices: every server-side advance
          // (rounds bump via _minigame_advance_round) re-mints and
          // re-delivers the FULL history K_0..K_r, catching up anyone who was
          // offline at start/accept. _mintedRound keeps both paths idempotent
          // (startMatch sets it, so a re-entrant listener can't double-mint).
          final newRound = parsed.skeleton.round;
          final justStarted =
              prevPhase == MinigamePhase.countdown &&
              parsed.skeleton.phase == MinigamePhase.playing;
          // 206_minigame_key_request (2026-09-03): ANY participant (not just
          // the host) who still holds the round-key history serves a peer who
          // flagged itself as having lost its device-local keys (reinstall).
          // Fire ONLY when the requester set actually CHANGED — a persistent
          // unserved requester (its holder is offline) must not re-trigger a
          // serve pass on every unrelated state UPDATE.
          final prevRequesters = state.valueOrNull?.skeleton.keyRequests ?? const <String>{};
          final nextRequesters = parsed.skeleton.keyRequests;
          final newRequesters = nextRequesters.difference(prevRequesters);
          final removedRequesters = prevRequesters.difference(nextRequesters);
          AppLogger.instance.debug(
            'minigame state realtime session=$sessionId '
            'prevPhase=${prevPhase?.name} phase=${parsed.skeleton.phase.name} '
            'prevRound=$prevRound newRound=$newRound justStarted=$justStarted '
            'mintedRound=$_mintedRound subject=${parsed.skeleton.subjectId?.substring(0, 8)}… '
            'keyRequesters=${nextRequesters.length} newRequesters=${newRequesters.length} '
            'removedRequesters=${removedRequesters.length}',
          );
          if (justStarted || (newRound > prevRound && newRound > (_mintedRound ?? -1))) {
            _mintedRound = newRound;
            _mintRoundKey(newRound);
          }
          _serveKeyRequests(parsed, requesterDelta: newRequesters.isNotEmpty);
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
    final initial = MinigameGameState.fromRow(row);
    // A holder who arrives at an already-flagged session serves immediately
    // (the requester may have flagged while this device was offline).
    _serveKeyRequests(initial);
    return initial;
  }

  /// Prevents concurrent serve passes (the ring helper is async and best-
  /// effort; a second realtime emission while one pass is in flight must not
  /// double-deliver to the same requester).
  bool _servingKeyRequests = false;

  /// 206_minigame_key_request serve side: a participant who still holds the
  /// round-key history re-wraps `K_0..K_<latest>` to every requester in
  /// [state] who is NOT this device, then clears the served markers. Works for
  /// ANY holder (the key ring is not host-dependent); best-effort — a holder
  /// with no keys logs and skips; a failed delivery leaves the requester
  /// flagged for the next holder.
  ///
  /// [requesterDelta] guards the realtime path: a serve pass runs only when
  /// the requester set actually CHANGED (someone new flagged, or a marker was
  /// cleared and a still-unsatisfied peer deserves a retry) — never on every
  /// unrelated game-state UPDATE. The initial-load call passes true.
  void _serveKeyRequests(
    MinigameGameState state, {
    bool requesterDelta = true,
  }) {
    if (!requesterDelta || _servingKeyRequests) return;
    final myId = ref.read(authStateProvider).valueOrNull?.user?['id'];
    final requesters = state.skeleton.keyRequests
        .where((id) => id != myId)
        .toList();
    if (requesters.isEmpty) return;
    _servingKeyRequests = true;
    unawaited(() async {
      try {
        final cipher = ref.read(minigameCipherProvider(arg));
        final served = await cipher.shareRoundHistoryWith(requesters);
        for (final requester in served) {
          await _service.resolveMinigameKeyRequest(arg, requesterId: requester);
        }
      } catch (e, st) {
        AppLogger.instance.warn(
          'minigame key-ring serve skipped session=$arg type=${e.runtimeType}: $e',
          '$st',
        );
      } finally {
        _servingKeyRequests = false;
      }
    }());
  }

  /// Best-effort: the HOST mints `K_round` and pairwise-distributes the round-key
  /// history to the roster. Called synchronously from [startMatch] (round 0 —
  /// the RPC result the host itself produced, closing the own-UPDATE race) and
  /// from the realtime listener on every server-side round advance (round 1+,
  /// cumulative `K_0..K_r` re-delivery). Failures are logged and swallowed
  /// (best-effort contract).
  ///
  /// Offline posture (2026-08-31): prekeys and bundles are server-persisted,
  /// so a peer offline at mint time can still be wrapped IF its prekeys are
  /// published (X3DH reads `e2ee_identity_keys` via `fetch_prekey_bundle`);
  /// a peer with NO published prekey throws [E2eeCryptoException], is skipped
  /// and stays missing — retried on the next roster change or round bump.
  /// Every delivered bundle row survives on the server, so an offline member
  /// self-heals on return via [MinigameCipher.ensureRoundKey].
  Future<void> _mintRoundKey(int round) async {
    try {
      final myId = ref.read(authStateProvider).valueOrNull?.user?['id'];
      if (myId == null) {
        AppLogger.instance.warn(
          'minigame mint skipped session=$arg round=$round — no authenticated user',
        );
        return;
      }
      final session = ref.read(sessionStatusProvider(arg)).valueOrNull;
      final participants = (session?['participants'] as List?)?.cast<String?>();
      if (participants == null || participants.isEmpty) {
        AppLogger.instance.warn(
          'minigame mint skipped session=$arg round=$round — empty participants',
        );
        return;
      }
      // Creator = participant[0] (the only role that can start the game).
      if (participants.first != myId) {
        AppLogger.instance.debug(
          'minigame mint skipped session=$arg round=$round — not creator '
          '(myId=${myId.substring(0, 8)}… first=${participants.first?.substring(0, 8)}…)',
        );
        return;
      }
      final peers = [
        for (final p in participants)
          if (p != null && p != myId) p,
      ];
      AppLogger.instance.debug(
        'minigame mint triggered session=$arg round=$round roster=${participants.length} '
        'peers=${peers.length} mintedSoFar=$_mintedRound',
      );
      await ref
          .read(minigameCipherProvider(arg))
          .mintRoundKeyAndDistribute(peerIds: peers, round: round);
      AppLogger.instance.debug(
        'minigame mint done session=$arg round=$round peers=${peers.length}',
      );
    } catch (e, st) {
      AppLogger.instance.warn(
        'minigame round key mint skipped session=$arg round=$round '
        'type=${e.runtimeType}: $e',
        '$st',
      );
    }
  }

  /// Re-runs [build] (finding SM-09).
  Future<void> refresh() async {
    _mintedRound = null;
    ref.invalidateSelf();
  }

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

  /// Drunk bottle (209_minigame_bottle_pizza): launches a spin. The server
  /// reseats the roster, so every device redraws the pizza in the new order.
  /// Reloads so the caller's own screen updates immediately; the rest of the
  /// table gets it over realtime.
  Future<void> spinBottle() async {
    await _service.spinDrunkBottle(arg);
    await refresh();
  }

  /// Drunk bottle: stops the spin. The server draws the angle, the winning
  /// sector and the reto — the client only renders what comes back.
  Future<void> stopBottle() async {
    await _service.stopDrunkBottle(arg);
    await refresh();
  }

  /// Charadas (211_minigame_charades): the caller takes the phone for a turn
  /// of [seconds] on [category] (null = every category).
  Future<void> startCharadesTurn({String? category, int seconds = 60}) async {
    await _service.startCharadesTurn(arg, category: category, seconds: seconds);
    await refresh();
  }

  /// Charadas: scores the word on screen and draws the next one.
  Future<void> charadesAnswer({required bool correct}) async {
    await _service.charadesAnswer(arg, correct: correct);
    await refresh();
  }

  /// Charadas: closes the running turn and banks its hits.
  Future<void> endCharadesTurn() async {
    await _service.endCharadesTurn(arg);
    await refresh();
  }

  /// Starts the partida (creator-only, backend-enforced via `not_creator`):
  /// calls `init_minigame_game_state` (the lobby → countdown transition, which
  /// seeds the skeleton + random first subject + next_subject_id) and reloads
  /// the state. The whole lobby sees the countdown via the realtime stream and
  /// each device runs its own on-device countdown (no server deadline — 203).
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

  /// The HOST's device confirms the countdown finished without a cancel
  /// (203_minigame_host_start): calls `start_minigame_match`, flipping the
  /// game-state phase countdown → playing. The realtime stream carries the
  /// flip to every participant, who navigate to the play screen together.
  ///
  /// E2EE round-key mint (2026-08-31 race fix): the HOST mints + distributes
  /// `K_0` HERE, synchronously from the RPC result — NOT from observing its
  /// own countdown → playing transition on the realtime channel. The host
  /// performs that flip itself via this RPC, so Riverpod already applied the
  /// UPDATE by the time its own realtime listener fires: `prevPhase` reads
  /// 'playing', `justStarted` is false and the observation-driven mint
  /// (the `_mintRoundKey` call in the listener) never runs — the subject's
  /// submit then self-heals to an empty bundle table and throws
  /// "round key 0 missing" → "Error del servidor". Minting here guarantees
  /// the persisted K_0 bundle exists (minigame_e2ee_bundles) before any
  /// participant can submit; an offline member self-heals on return via
  /// [MinigameCipher.ensureRoundKey]. Round 1+ keeps riding the realtime
  /// listener (cumulative K_0..K_r re-delivery on each server-side bump).
  Future<void> startMatch() async {
    final result = await _service.startMatch(arg);
    final round = MinigameGameState.fromRow(result).skeleton.round;
    _mintedRound = round;
    await _mintRoundKey(round);
    await refresh();
  }

  /// The creator removes [userId] from the lobby (180_minigame_lobby):
  /// refunds the escrow, drops the participant, closes their invite, clears
  /// their ready flag — all server-side. Reloads the roster + session.
  ///
  /// E2EE forward rotation (2026-08-31): after the kick lands, the creator
  /// mints `K_{r+1}` and hands it ONLY to the remaining roster — the kicked
  /// player is forward-rotated out (their stored keys still decrypt past
  /// rounds, but they never receive the new key). Best-effort: a
  /// distribution failure never fails the kick, and round keys are never
  /// wiped.
  Future<void> removeParticipant(String userId) async {
    await _service.removeParticipant(arg, userId);
    await refresh();
    ref.invalidate(sessionStatusProvider(arg));
    // ref.container.invalidate (not ref.invalidate): the roster provider
    // LISTENS to this provider (ready-flag sync), so a plain ref.invalidate
    // from here trips Riverpod's debug circular-dependency check. The
    // container-level invalidate is semantically identical and assert-safe.
    ref.container.invalidate(minigameParticipantsProvider(arg));
    ref.invalidate(myPendingInvitesProvider);
    // The kicked player's invite row is gone — the picker must drop their
    // "sent" tag so they render as a fresh invitee on re-invite.
    ref.invalidate(minigameInviteeStatesProvider(arg));
    await _rotateKeysOnKick(userId);
  }

  /// Best-effort E2EE forward rotation on a kick (2026-08-31): mints the
  /// next round key and distributes it ONLY to the remaining participants —
  /// the kicked player never receives `K_{r+1}`, so future rounds are
  /// revoked for them (their stored keys still decrypt their past rounds).
  /// Failures are logged and swallowed (best-effort contract); round keys
  /// are never wiped here — forward rotation is the only revoke mechanism.
  Future<void> _rotateKeysOnKick(String kickedUserId) async {
    try {
      final myId = ref.read(authStateProvider).valueOrNull?.user?['id'];
      if (myId == null) return;
      final session = ref.read(sessionStatusProvider(arg)).valueOrNull;
      final participants = (session?['participants'] as List?)?.cast<String?>();
      if (participants == null) return;
      // Only the creator rotates (remove is creator-only; belt-and-suspenders).
      if (participants.isEmpty || participants.first != myId) return;
      final peers = [
        for (final p in participants)
          if (p != null && p != myId && p != kickedUserId) p,
      ];
      final current = state.valueOrNull?.skeleton.round ?? 0;
      await ref.read(minigameCipherProvider(arg)).rotateRoundKey(
        peerIds: peers,
        round: current + 1,
      );
    } catch (e, st) {
      AppLogger.instance.warn('minigame kick rotation skipped', '$st');
    }
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

  /// Ends the party game via the leaderboard settlement RPC
  /// (`finish_minigame_game`, 201_minigame_voting — replaces the old
  /// draw-only completer) and reloads. The finished screen then reads the
  /// settled leaderboard from [minigameResultProvider].
  Future<void> finish() async {
    await _service.finishGame(arg);
    await refresh();
    ref.invalidate(minigameResultProvider(arg));
    // On-device match summary (202_minigame_play_v2): the durable history /
    // summary record lives in the encrypted Hive cache (the server purge is
    // deferred — decision 2026-08-30).
    await _cacheSummary();
  }

  /// Writes the finished match summary (results + answers + reactions +
  /// aliases) into the encrypted on-device Hive box.
  Future<void> _cacheSummary() async {
    try {
      final result = await ref.read(minigameResultProvider(arg).future);
      final gameState = state.valueOrNull;
      final session =
          ref.read(sessionStatusProvider(arg)).valueOrNull;
      await ref.read(hiveServiceProvider).cacheMinigameSummary(arg, {
        'finished_at': DateTime.now().toIso8601String(),
        'game_type': gameState?.gameType ?? '',
        'play_mode': gameState?.skeleton.playMode.wire ?? 'by_turns',
        'anonymous': gameState?.skeleton.anonymous ?? false,
        'results': result?.rows
                .map(
                  (r) => {
                    'participant_id': r.participantId,
                    'username': r.username,
                    'score': r.score,
                    'rank': r.rank,
                    'prize': r.prize,
                  },
                )
                .toList() ??
            const [],
        'answers': [
          for (final a in gameState?.skeleton.answers ?? const <MinigameAnswer>[])
            {
              'round': a.round,
              'subject_id': a.subjectId,
              'answer_ciphertext': a.answerCiphertext,
              'image_storage_path': a.imageStoragePath,
              'passed': a.passed,
            },
        ],
        'participants': session?['participants'] ?? const <dynamic>[],
      });
    } catch (_) {
      // Best-effort: a summary write failure must never break settlement.
    }
  }

  /// Submits the caller's emoji vote for the current round (201_minigame_voting)
  /// and reloads the state (the live tally streams back through the realtime
  /// channel for the whole lobby).
  Future<void> react(ReactionKind reaction) async {
    await _service.submitReaction(arg, reaction);
    await refresh();
  }

  /// The current-turn subject submits their E2EE answer (202_minigame_play_v2)
  /// and reloads the state — the ciphertext streams to every participant and
  /// opens the reaction row for the others.
  Future<void> submitAnswer({
    required String answerCiphertext,
    String? imageStoragePath,
  }) async {
    await _service.submitAnswer(
      arg,
      answerCiphertext: answerCiphertext,
      imageStoragePath: imageStoragePath,
    );
    await refresh();
  }

  /// The current-turn subject passes (202_minigame_play_v2): blocks all
  /// reactions and auto-advances with score -1.
  Future<void> pasar() async {
    await _service.submitPasar(arg);
    await refresh();
  }

  /// Completes one async round of the caller (202_minigame_play_v2): the
  /// server draws a random [kind] prompt and records the round; the reactable
  /// list streams the ciphertext to the others.
  Future<void> submitAsyncAnswer({
    required TruthDareKind kind,
    required String answerCiphertext,
    String? imageStoragePath,
  }) async {
    await _service.submitAsyncAnswer(
      arg,
      kind: kind,
      answerCiphertext: answerCiphertext,
      imageStoragePath: imageStoragePath,
    );
    await refresh();
  }

  /// Reacts to an arbitrary COMPLETED round (202_minigame_play_v2) — the
  /// async reactable-rounds list.
  Future<void> reactToRound({
    required int round,
    required ReactionKind reaction,
  }) async {
    await _service.reactToRound(arg, round: round, reaction: reaction);
    await refresh();
  }
}

/// The temp nicknames of one session (202_minigame_play_v2 anonymous mode) —
/// `{participant_id: alias}` read from `minigame_aliases`, with every live
/// set/update merged in so the realtime stream and the local write stay in
/// sync.
///
/// The subscription listens to ALL postgres changes: a nickname's FIRST save
/// is an INSERT, later renames are UPDATEs, and both must reach the other
/// lobby members. Deletes/other tables are filtered out by the row guards
/// below (an event's `newRecord` is not a valid alias row).
class MinigameAliasesNotifier
    extends FamilyAsyncNotifier<Map<String, String>, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<Map<String, String>> build(String sessionId) {
    // Live alias updates ride the I-52 realtime lifecycle provider: a
    // participant's nickname set/change streams in on the minigame_aliases
    // channel and merges into the map (anonymous mode, 202_minigame_play_v2).
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      realtimeChannelProvider((
        channelName: 'minigame-aliases:$sessionId',
        table: 'minigame_aliases',
        event: PostgresChangeEvent.all,
      )),
      (_, next) {
        final row = next.valueOrNull;
        if (row == null || row['session_id'] != sessionId) return;
        if (!state.hasValue) return;
        final alias = row['alias'];
        if (row['participant_id'] is! String || alias is! String) return;
        state = AsyncData({
          ...state.valueOrNull!,
          row['participant_id'] as String: alias,
        });
      },
    );
    return _service.getAliases(sessionId);
  }

  /// Re-runs [build] after a set/update (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Sets/updates the caller's temp nickname and reloads the map.
  Future<void> setAlias(String sessionId, String alias) async {
    await _service.setAlias(sessionId, alias);
    await refresh();
  }
}

/// One session's temp nicknames (family by session id; empty map when none).
final minigameAliasesProvider =
    AsyncNotifierProvider.family<
      MinigameAliasesNotifier,
      Map<String, String>,
      String
    >(MinigameAliasesNotifier.new);

/// One session's live play-engine state (family by session id).
final minigameGameStateProvider =
    AsyncNotifierProvider.family<
      MinigameGameStateNotifier,
      MinigameGameState,
      String
    >(MinigameGameStateNotifier.new);

/// The settled leaderboard of one session (201_minigame_voting) — read from
/// `minigame_results` once the game has finished. Null while the game is
/// still active (no settlement row yet).
class MinigameResultNotifier
    extends FamilyAsyncNotifier<MinigameResult?, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<MinigameResult?> build(String sessionId) async {
    return _service.getMinigameResult(sessionId);
  }

  /// Re-runs [build] after the game settles (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// One session's settled leaderboard (family by session id; null before the
/// game ends).
final minigameResultProvider =
    AsyncNotifierProvider.family<
      MinigameResultNotifier,
      MinigameResult?,
      String
    >(MinigameResultNotifier.new);

/// The finished-match player content of one session — each player's
/// decrypted answers, each carrying the question it answered and the
/// reactions it received. Built from the participant-readable tables
/// (`minigame_answers`, `minigame_reactions`) plus a batch `minigame_prompts`
/// lookup for the question text: answers are decrypted locally through
/// [minigameCipherProvider] and grouped by author, reactions are tallied per
/// round (one subject per round) and attached to that round's answer.
///
/// Best-effort by design: an undecryptable answer (the device lost the round
/// key) simply carries no text/image, and an unresolvable prompt stays null —
/// neither ever fails the whole screen.
class MinigamePlayerContentNotifier
    extends FamilyAsyncNotifier<MinigamePlayerContent, String> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<MinigamePlayerContent> build(String sessionId) {
    // The finished leaderboard must never hang on the answer content: a slow
    // or stuck download surfaces as an error after a short, tunable window so
    // the card can offer a discreet retry (2026-09-11 user directive).
    return withTimeout(
      () => _load(sessionId),
      timeout: AppConstants.leaderboardAnswersTimeout,
    );
  }

  Future<MinigamePlayerContent> _load(String sessionId) async {
    final rawAnswers = await _service.getSessionAnswers(sessionId);
    final rawReactions = await _service.getSessionReactions(sessionId);
    final cipher = ref.read(minigameCipherProvider(sessionId));

    final answersByPlayer = <String, List<MinigamePlayerAnswer>>{};

    // Reactions first, keyed by round — each round has exactly one subject, so
    // a round's reactions belong to the answer that round produced.
    final reactionsByRound = <int, Map<ReactionKind, int>>{};
    for (final row in rawReactions) {
      final round = row['round'] is num ? (row['round'] as num).toInt() : 0;
      final kind = reactionKindFromWire(row['reaction'] as String?);
      if (kind == null || kind == ReactionKind.pass) continue;
      final tally = reactionsByRound[round] ??= <ReactionKind, int>{};
      tally[kind] = (tally[kind] ?? 0) + 1;
    }

    for (final row in rawAnswers) {
      final round = row['round'] is num ? (row['round'] as num).toInt() : 0;
      final subjectId = row['subject_id'] as String? ?? '';
      if (subjectId.isEmpty) continue;

      final passed = row['passed'] == true;
      final cipherText = row['answer_ciphertext'] as String?;
      final imagePath = row['image_storage_path'] as String?;

      String? text;
      Uint8List? imageBytes;
      if (!passed) {
        if (cipherText != null && cipherText.isNotEmpty) {
          text = await cipher.decryptAnswerText(cipherText, round);
        }
        if (imagePath != null && imagePath.isNotEmpty) {
          final rawBytes = await _service.downloadMinigameImageBytes(imagePath);
          if (rawBytes != null) {
            imageBytes = await cipher.decryptAnswerImageBytes(rawBytes, round);
          }
        }
      }

      (answersByPlayer[subjectId] ??= <MinigamePlayerAnswer>[]).add(
        MinigamePlayerAnswer(
          round: round,
          subjectId: subjectId,
          promptType: row['prompt_type'] as String?,
          promptId: row['prompt_id'] as String?,
          passed: passed,
          text: text,
          imageBytes: imageBytes,
          reactions: reactionsByRound[round] ?? const {},
        ),
      );
    }

    // Order each player's answers: real answers by round ascending, PASSED
    // rounds last (they carry no content and must sit at the bottom).
    for (final answers in answersByPlayer.values) {
      answers.sort((a, b) {
        if (a.passed != b.passed) return a.passed ? 1 : -1;
        return a.round.compareTo(b.round);
      });
    }

    // Resolve the question text in ONE batch (client join to
    // `minigame_prompts`). A prompt that fails to resolve (deactivated/
    // removed) stays null — the card shows its load-error state, never a
    // question with no answer.
    var content = MinigamePlayerContent(answersByPlayer: answersByPlayer);
    final ids = content.promptIds;
    if (ids.isNotEmpty) {
      final bodies = await _service.getPromptsByIds(ids);
      content = content.withPromptBodies(bodies);
    }
    return content;
  }

  /// Re-runs [build] (e.g. after key recovery completes).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// One session's finished-match player content (family by session id; empty
/// before the game ends / while loading).
final minigamePlayerContentProvider =
    AsyncNotifierProvider.family<
      MinigamePlayerContentNotifier,
      MinigamePlayerContent,
      String
    >(MinigamePlayerContentNotifier.new);

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

  /// Participants this notifier has already handed the round-key history to
  /// (2026-08-31) — the roster-change safety net fires ONCE per newcomer,
  /// never on every session emission. A delivered-mark is dropped when the
  /// participant leaves the roster so a re-join re-delivers.
  final Set<String> _deliveredRecipients = {};

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
    //
    // E2EE roster-change safety net (2026-08-31): the same id-set change ALSO
    // hands the NEW members the full `K_1..K_N` history — the accept-time
    // [MinigameInviteNotifier._distributeKeysOnAccept] is the acceptor-side
    // best-effort shot, but the HOST's copy here is authoritative (a peer who
    // skipped at accept for lack of a prekey gets retried on the next roster
    // change, exactly the cipher's retry contract). Participants whose
    // delivered-mark is dropped (left the roster) re-deliver on re-join.
    ref.listen<AsyncValue<Map<String, dynamic>>>(
      sessionStatusProvider(sessionId),
      (_, next) {
        // Only react once the roster has an initial value — during the first
        // load a session emission would spuriously re-fetch (no double-build).
        if (!state.hasValue) return;
        final nextIds = _participantIdsOf(next.valueOrNull);
        if (nextIds.isEmpty) return;
        // Drop delivered-marks for participants no longer in the roster so a
        // re-join (or a kicked-and-reinvited player) re-delivers.
        _deliveredRecipients.removeWhere((id) => !nextIds.contains(id));
        final currentIds = {
          for (final p in state.valueOrNull ?? const <MinigameParticipant>[])
            p.id,
        };
        // 2026-09-02: compare the participant id SETS directly. The old
        // `length != || !containsAll` missed a re-join after a kick when the
        // count returned to the same value (e.g. 3 -> kick -> 3) — the sets
        // differed (one player swapped) but length + containsAll both passed,
        // so the roster never re-fetched and other devices kept showing the
        // pre-kick roster (the "3 devices see 3, one sees 4" staleness). Set
        // equality catches ANY membership change regardless of count.
        if (currentIds != nextIds) {
          // Re-fetch the roster in place (no double-build: this listen only
          // fires on an actual participants change).
          refresh();
          _distributeToNewMembers(nextIds);
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

  /// Best-effort E2EE history distribution to the roster's NEW members
  /// (2026-08-31): fires exactly when the participant id-set changes (the
  /// same condition that re-fetches the roster) and hands each newcomer NOT
  /// yet in [_deliveredRecipients] the full `K_1..K_N` history. The host
  /// being the key custodian, this is the authoritative delivery — it also
  /// retries peers that a no-prekey skip left missing at accept. Failures are
  /// logged and swallowed (best-effort contract); delivered-marks are set
  /// only after a successful call so a transient failure retries on the next
  /// roster change.
  Future<void> _distributeToNewMembers(Set<String> nextIds) async {
    try {
      final myId = ref.read(authStateProvider).valueOrNull?.user?['id'];
      if (myId == null) return;
      final cipher = ref.read(minigameCipherProvider(arg));
      final peers = [
        for (final id in nextIds)
          if (id != myId && !_deliveredRecipients.contains(id)) id,
      ];
      if (peers.isEmpty) return;
      await cipher.distributeHistoryKeys(
        peerIds: peers,
        roundKeys: await cipher.knownRoundKeys(),
      );
      _deliveredRecipients.addAll(peers);
    } catch (e, st) {
      AppLogger.instance.warn('minigame roster distribution skipped', '$st');
    }
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
