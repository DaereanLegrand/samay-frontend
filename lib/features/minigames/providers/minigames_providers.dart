import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/realtime_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/minigame_service.dart';
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
  final notifications = ref
      .watch(notificationsProvider)
      .valueOrNull;
  if (notifications == null) return 0;
  return notifications
      .where((n) => n.type == 'minigame_invite' && !n.read)
      .length;
});

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
  /// (0 = no wager) and optional [inviteeIds] (any searchable user — the
  /// friends-only + blocked gates are enforced server-side) and reloads the
  /// list.
  ///
  /// Server rejections surface as the typed [MinigameSessionRejectedException]
  /// (insufficient shards / not a member / invalid game / invitee gates) —
  /// the screen maps [MinigameSessionRejection] to friendly localized
  /// messages.
  Future<String> create(
    MinigameType type,
    int wager, {
    List<String> inviteeIds = const [],
  }) async {
    final id = await _service.createSession(
      arg,
      type,
      wager,
      inviteeIds: inviteeIds,
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
final minigameSessionsProvider = AsyncNotifierProvider.family<
    MinigameSessionsNotifier, List<Map<String, dynamic>>, String>(
  MinigameSessionsNotifier.new,
);

/// The current user's DIRECT sessions (group_id IS NULL), newest first —
/// the direct-play hub (direct-minigames 2026-08-27). RLS
/// `ms_read_direct_participant` bounds the read to sessions where the caller
/// is a participant (creator is participant[0]); the group-scoped
/// [minigameSessionsProvider] stays for the group hub.
class MyMinigameSessionsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  MinigameService get _service => ref.read(minigameServiceProvider);

  @override
  Future<List<Map<String, dynamic>>> build() {
    return _service.listMySessions();
  }

  /// Re-runs [build] (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();

  /// Creates a DIRECT session (null group) of [type] with an optional
  /// [wager] (0 = no wager) and optional [inviteeIds] (some games are
  /// single-player — the server freezes the player_limit from the creator's
  /// tier). Server rejections surface as the typed
  /// [MinigameSessionRejectedException] (insufficient shards / invitee
  /// gates / player limit) and reload the direct list.
  Future<String> create(
    MinigameType type,
    int wager, {
    List<String> inviteeIds = const [],
  }) async {
    final id = await _service.createSession(
      null,
      type,
      wager,
      inviteeIds: inviteeIds,
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
    AsyncNotifierProvider<MyMinigameSessionsNotifier, List<Map<String, dynamic>>>(
  MyMinigameSessionsNotifier.new,
);

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
final sessionStatusProvider = AsyncNotifierProvider.family<
    MinigameSessionStatusNotifier, Map<String, dynamic>, String>(
  MinigameSessionStatusNotifier.new,
);

/// The current user's invite row for one session (null when they are not
/// invited), plus the accept/decline actions. Family by session id so each
/// session detail carries its own invite state.
class MinigameInviteNotifier extends FamilyAsyncNotifier<Map<String, dynamic>?, String> {
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
  Future<void> accept() async {
    final inviteId = state.valueOrNull?['id'] as String?;
    if (inviteId == null) return;
    await _service.acceptInvite(inviteId);
    await refresh();
    ref.invalidate(sessionStatusProvider(arg));
  }

  /// Declines the pending invite and reloads.
  Future<void> decline() async {
    final inviteId = state.valueOrNull?['id'] as String?;
    if (inviteId == null) return;
    await _service.declineInvite(inviteId);
    await refresh();
  }
}

/// The current user's invite row for one session (family by session id).
final minigameInviteProvider = AsyncNotifierProvider.family<
    MinigameInviteNotifier, Map<String, dynamic>?, String>(
  MinigameInviteNotifier.new,
);

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
