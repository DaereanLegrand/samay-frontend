import 'package:supabase_flutter/supabase_flutter.dart';

/// Content moderation: user reports against content.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11).
class ModerationService {
  final SupabaseClient client;

  ModerationService({required this.client});

  GoTrueClient get auth => client.auth;

  Future<void> reportContent(String targetType, String targetId, String reason) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client.from('reports').insert({
      'reporter_id': user.id,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }
}
