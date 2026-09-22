import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// Remote-side freshness for the friends surface.
///
/// Lives for as long as the shell is mounted: subscribes to the current
/// user's `friendships` realtime stream and invalidates
/// [friendsListProvider] + [friendRequestsProvider] on ANY row event that
/// touches them (insert/update/delete — the accepting side stays correct
/// without a pull-to-refresh). `pendingCountsProvider` derives from the
/// requests provider, so the shell badge follows automatically.
///
/// Re-subscribes when the authenticated user changes. Failures are logged,
/// never silent (best-effort: pull-to-refresh remains the fallback).
class FriendshipsRealtimeListener extends ConsumerStatefulWidget {
  const FriendshipsRealtimeListener({super.key});

  @override
  ConsumerState<FriendshipsRealtimeListener> createState() =>
      _FriendshipsRealtimeListenerState();
}

class _FriendshipsRealtimeListenerState
    extends ConsumerState<FriendshipsRealtimeListener> {
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
          .subscribeToFriendships((_) {
        ref.invalidate(friendsListProvider);
        ref.invalidate(friendRequestsProvider);
      });
      if (!mounted || _subscribedUid != uid) {
        // The user changed while subscribing — drop the stale channel.
        await channel.unsubscribe();
        return;
      }
      _channel = channel;
    } catch (e, st) {
      AppLogger.instance.error('friendships realtime subscribe failed: $e', '$st');
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
