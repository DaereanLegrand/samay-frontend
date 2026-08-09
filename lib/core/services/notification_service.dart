import 'package:samay/core/services/realtime_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// In-app notifications: history, read-state and realtime delivery.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11).
class NotificationService {
  final SupabaseClient client;
  final RealtimeService realtime;

  NotificationService({required this.client, required this.realtime});

  GoTrueClient get auth => client.auth;

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('notifications')
        .select('id, type, title, body, data, read, created_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(50);
    return (res as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> markNotificationRead(String id) async {
    await client.from('notifications').update({'read': true}).eq('id', id);
  }

  Future<void> subscribeToNotifications(
    void Function(Map<String, dynamic>) onInsert,
  ) {
    return realtime.subscribeToNotifications(onInsert);
  }
}
