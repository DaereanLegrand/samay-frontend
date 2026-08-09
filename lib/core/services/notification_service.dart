import 'package:samay/core/services/realtime_service.dart';
import 'package:samay/core/services/rest_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app notifications: history, read-state and realtime delivery.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11).
///
/// Migrated to [RestClient] (I-51): all table access goes through the typed
/// envelope; the `client` field remains for the auth accessor and legacy
/// call sites until the facade deletion (STOP-100).
class NotificationService {
  final SupabaseClient client;
  final RealtimeService realtime;
  final RestClient rest;

  NotificationService({required this.client, required this.realtime})
      : rest = RestClient(client: client);

  GoTrueClient get auth => client.auth;

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    return rest.list<Map<String, dynamic>>(
      'notifications',
      fromJson: (row) => row,
      select: 'id, type, title, body, data, read, created_at',
      filters: [(column: 'user_id', op: 'eq', value: user.id)],
      order: 'created_at',
      ascending: false,
      limit: 50,
    );
  }

  Future<void> markNotificationRead(String id) async {
    await rest.update('notifications', 'id', id, {'read': true});
  }

  /// Subscribes to live notification inserts for the current user. The
  /// returned channel lets callers unsubscribe on dispose (I-53).
  Future<RealtimeChannel> subscribeToNotifications(
    void Function(Map<String, dynamic>) onInsert,
  ) {
    return realtime.subscribeToNotifications(onInsert);
  }
}
