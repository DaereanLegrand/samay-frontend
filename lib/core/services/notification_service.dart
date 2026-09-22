import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/services/realtime_service.dart';
import 'package:samay/core/services/rest_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app notifications: history, read-state and realtime delivery.
///
/// Migrated to [RestClient]: all table access goes through the typed
/// envelope; the `client` field remains for the auth accessor and
/// compatibility call sites until the facade deletion.
class NotificationService {
  final SupabaseClient client;
  final RealtimeService realtime;
  final RestClient rest;

  NotificationService({required this.client, required this.realtime})
      : rest = RestClient(client: client);

  GoTrueClient get auth => client.auth;

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
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
  /// returned channel lets callers unsubscribe on dispose.
  Future<RealtimeChannel> subscribeToNotifications(
    void Function(Map<String, dynamic>) onInsert,
  ) {
    return realtime.subscribeToNotifications(onInsert);
  }
}
