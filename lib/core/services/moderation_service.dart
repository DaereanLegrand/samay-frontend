import 'package:samay/core/errors/app_error.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Content moderation: user reports against content.
class ModerationService {
  final SupabaseClient client;

  ModerationService({required this.client});

  GoTrueClient get auth => client.auth;

  Future<void> reportContent(String targetType, String targetId, String reason) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    await client.from('reports').insert({
      'reporter_id': user.id,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'status': 'pending',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  /// Reports ONE chat message through `report_message` (226_chat_moderation).
  ///
  /// The chat is end-to-end encrypted, so the server cannot read the reported
  /// row on its own: the caller passes the row's DECRYPTED [plaintext] so the
  /// moderator queue can actually see it (any media URL is read server-side
  /// from the message row). Only the row the user chose to report is disclosed
  /// — the reporting exception to E2EE.
  Future<void> reportMessage(
    String messageId,
    String reason, {
    String? plaintext,
  }) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client.rpc('report_message', params: {
      'p_message_id': messageId,
      'p_reason': reason,
      'p_plaintext': plaintext,
    });
    final status = res is Map ? res['status'] : null;
    if (status == 'ok') return;
    switch (status) {
      case 'message_not_found':
        throw const NotFoundError('Mensaje');
      case 'not_allowed':
        throw PermissionError();
      case 'not_authenticated':
        throw const UnauthorizedError();
      default:
        throw const ServerError();
    }
  }
}
