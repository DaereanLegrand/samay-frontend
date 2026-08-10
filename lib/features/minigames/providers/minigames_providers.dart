import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/realtime_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  /// (0 = no wager) and reloads the list.
  ///
  /// Server rejections surface as the typed [MinigameSessionRejectedException]
  /// (insufficient shards / not a member / invalid game) — the screen maps
  /// [MinigameSessionRejection] to friendly localized messages.
  Future<String> create(MinigameType type, int wager) async {
    final id = await _service.createSession(arg, type, wager);
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
