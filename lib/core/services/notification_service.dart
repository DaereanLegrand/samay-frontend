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

  /// Reads the server-persisted notification categories (Q4a). Returns the
  /// normalized map: chat/events/friends/minigames default on, marketing off,
  /// security/moderation/legal always on.
  Future<Map<String, bool>> getPreferences() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc('get_notification_preferences');
    return _prefsMap(res);
  }

  /// Persists the notification categories server-side and returns the
  /// server-normalized result (locked categories are forced back on).
  Future<Map<String, bool>> setPreferences(Map<String, bool> prefs) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc(
      'set_notification_preferences',
      params: {'p_prefs': prefs},
    );
    return _prefsMap(res);
  }

  Map<String, bool> _prefsMap(Object? raw) {
    final map = raw is Map ? Map<String, dynamic>.from(raw) : const {};
    return {
      for (final entry in map.entries)
        if (entry.value is bool) entry.key: entry.value as bool,
    };
  }

  /// Subscribes to live notification inserts for the current user. The
  /// returned channel lets callers unsubscribe on dispose.
  Future<RealtimeChannel> subscribeToNotifications(
    void Function(Map<String, dynamic>) onInsert,
  ) {
    return realtime.subscribeToNotifications(onInsert);
  }
}
