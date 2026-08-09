import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Realtime: channel lifecycle and Postgres-change subscriptions.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11). Full lifecycle handling (reconnect/backoff) is
/// I-52's scope (lib/core/providers/realtime_provider.dart).
class RealtimeService {
  final SupabaseClient client;

  RealtimeService({required this.client});

  GoTrueClient get auth => client.auth;

  /// Subscribes to Postgres changes on [table] (schema `public`) over the
  /// channel [channelName], forwarding each `newRecord` to [callback].
  ///
  /// [onStatus] receives the channel subscription lifecycle: `subscribed`
  /// when the join is acknowledged, `channelError`/`timedOut` when the
  /// subscription fails (RLS denial, server decline, join timeout), `closed`
  /// when the socket closed. This is the seam the realtime provider (I-52)
  /// uses to drive connection state + reconnect backoff.
  ///
  /// Returns the channel — the caller owns the unsubscribe handle.
  RealtimeChannel subscribeToChannel(
    String channelName,
    PostgresChangeEvent event,
    String table,
    void Function(Map<String, dynamic>) callback, {
    void Function(RealtimeSubscribeStatus status, Object? error)? onStatus,
  }) {
    final channel = client.channel(channelName);
    channel.onPostgresChanges(
      event: event,
      schema: 'public',
      table: table,
      callback: (payload) => callback(payload.newRecord),
    );
    if (onStatus != null) {
      channel.subscribe(onStatus);
    } else {
      channel.subscribe();
    }
    return channel;
  }

  RealtimeChannel subscribeToMessages(String chatId, void Function(Map<String, dynamic>) onInsert) {
    return subscribeToChannel('messages:$chatId', PostgresChangeEvent.insert, 'messages', onInsert);
  }

  /// Returns the live channel so callers can unsubscribe on dispose
  /// (same contract as [subscribeToMessages] — the notification center keeps
  /// its screen-level subscription dispose-safe).
  Future<RealtimeChannel> subscribeToNotifications(
    void Function(Map<String, dynamic>) onInsert,
  ) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    return subscribeToChannel(
      'notifications:${user.id}',
      PostgresChangeEvent.insert,
      'notifications',
      onInsert,
    );
  }

  Future<void> subscribeToEventStatus(String eventId, void Function(String) onChange) async {
    final channel = client.channel('event-status:$eventId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'events',
      callback: (payload) {
        final newStatus = payload.newRecord['status'] as String?;
        if (newStatus != null) onChange(newStatus);
      },
    );
    channel.subscribe();
  }

  Future<void> subscribeToQRToken(String eventId, void Function(String) onUpdate) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final channel = client.channel('qr-token:$eventId:${user.id}');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'event_qr_tokens',
      callback: (payload) {
        final token = payload.newRecord['token'] as String?;
        if (token != null) onUpdate(token);
      },
    );
    channel.subscribe();
  }
}
