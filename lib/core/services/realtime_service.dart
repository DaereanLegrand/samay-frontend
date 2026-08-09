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

  RealtimeChannel _subscribeToChannel(
    String channelName,
    PostgresChangeEvent event,
    String table,
    void Function(Map<String, dynamic>) callback,
  ) {
    final channel = client.channel(channelName);
    channel.onPostgresChanges(
      event: event,
      schema: 'public',
      table: table,
      callback: (payload) => callback(payload.newRecord),
    );
    channel.subscribe();
    return channel;
  }

  Future<void> subscribeToMessages(String chatId, void Function(Map<String, dynamic>) onInsert) async {
    _subscribeToChannel('messages:$chatId', PostgresChangeEvent.insert, 'messages', onInsert);
  }

  Future<void> subscribeToNotifications(void Function(Map<String, dynamic>) onInsert) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    _subscribeToChannel('notifications:${user.id}', PostgresChangeEvent.insert, 'notifications', onInsert);
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
