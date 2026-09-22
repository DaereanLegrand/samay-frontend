import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// Remote-side freshness for the chat inbox / unread badge.
///
/// Lives for as long as the shell is mounted: subscribes to the current
/// user's `messages` insert stream (`sender_id <> me` — RLS restricts
/// delivery to chats the user participates in) and invalidates
/// [chatInboxProvider] on every inbound message, so the feed button's unread
/// badge and the chat list update without a pull-to-refresh.
///
/// Re-subscribes when the authenticated user changes. Failures are logged,
/// never silent (best-effort: the badge falls back to the next read).
class InboxRealtimeListener extends ConsumerStatefulWidget {
  const InboxRealtimeListener({super.key});

  @override
  ConsumerState<InboxRealtimeListener> createState() =>
      _InboxRealtimeListenerState();
}

class _InboxRealtimeListenerState extends ConsumerState<InboxRealtimeListener> {
  RealtimeChannel? _channel;
  String? _subscribedUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (_, _) => _sync());
    return const SizedBox.shrink();
  }

  void _sync() {
    final uid = ref.read(authStateProvider).valueOrNull?.user?['id'];
    if (uid == _subscribedUid) return;
    _unsubscribe();
    if (uid == null) {
      _subscribedUid = null;
      return;
    }
    _subscribedUid = uid;
    _subscribe(uid);
  }

  Future<void> _subscribe(String uid) async {
    try {
      final channel = await ref.read(realtimeServiceProvider).subscribeToInbox(
            (_) => ref.invalidate(chatInboxProvider),
          );
      if (!mounted || _subscribedUid != uid) {
        await channel.unsubscribe();
        return;
      }
      _channel = channel;
    } catch (e, st) {
      AppLogger.instance.error('inbox realtime subscribe failed: $e', '$st');
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
