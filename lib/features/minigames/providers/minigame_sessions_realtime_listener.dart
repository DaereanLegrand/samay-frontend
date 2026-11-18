import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// Remote-side freshness for the minigame session lists.
///
/// Lives for as long as the shell is mounted: subscribes to the current
/// user's `minigame_sessions` realtime stream and invalidates
/// [myMinigameSessionsProvider] + [minigameSessionsProvider] on ANY row event
/// (insert/update/delete) whose row the RLS policies let the user read — so an
/// invite accept, a host removal, a status flip or a brand-new match created
/// for the user lands in the per-game ongoing list (and the group hub) without
/// a pull-to-refresh or restart. [myPendingInvitesProvider] follows too: a
/// membership change shifts whether a session reads as a pending invite or an
/// ongoing match.
///
/// The pending-invite badge count ([pendingMinigameInvitesProvider]) is NOT
/// touched here — it rides the notification stream via
/// [MinigameInvitesRealtimeListener], which stays the single owner of that
/// signal.
///
/// Re-subscribes when the authenticated user changes. Failures are logged,
/// never silent (best-effort: pull-to-refresh remains the fallback).
class MinigameSessionsRealtimeListener extends ConsumerStatefulWidget {
  const MinigameSessionsRealtimeListener({super.key});

  @override
  ConsumerState<MinigameSessionsRealtimeListener> createState() =>
      _MinigameSessionsRealtimeListenerState();
}

class _MinigameSessionsRealtimeListenerState
    extends ConsumerState<MinigameSessionsRealtimeListener> {
  RealtimeChannel? _channel;
  String? _subscribedUid;

  @override
  void initState() {
    super.initState();
    // Late subscription: the auth state may not be resolved on first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  Widget build(BuildContext context) {
    // Re-sync whenever the auth state changes (sign-in/sign-out/restore) —
    // a post-frame probe alone misses the late-resolving provider.
    ref.listen(authStateProvider, (_, _) => _sync());
    return const SizedBox.shrink();
  }

  void _sync() {
    final uid = ref.read(authStateProvider).valueOrNull?.user?['id'];
    if (uid == _subscribedUid) return;
    _unsubscribe();
    if (uid == null) {
      // Signed out — nothing to subscribe to.
      _subscribedUid = null;
      return;
    }
    _subscribedUid = uid;
    _subscribe(uid);
  }

  Future<void> _subscribe(String uid) async {
    try {
      final channel = await ref
          .read(realtimeServiceProvider)
          .subscribeToMinigameSessions((row) {
            ref.invalidate(myMinigameSessionsProvider);
            ref.invalidate(myPendingInvitesProvider);
            final gid = row['group_id'];
            if (gid is String && gid.isNotEmpty) {
              ref.invalidate(minigameSessionsProvider(gid));
              // 210: the group-chat notice is written in the same
              // transaction as the session insert. Chat is not part of this
              // build, so there is no bubble to refresh.
            }
          });
      if (!mounted || _subscribedUid != uid) {
        // The user changed while subscribing — drop the stale channel.
        await channel.unsubscribe();
        return;
      }
      _channel = channel;
    } catch (e, st) {
      AppLogger.instance.error(
        'minigame sessions realtime subscribe failed: $e',
        '$st',
      );
    }
  }

  void _unsubscribe() {
    _channel?.unsubscribe();
    _channel = null;
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }
}
