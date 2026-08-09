import 'package:samay/core/services/realtime_service.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Chat messages: history, sending and realtime delivery.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11).
///
/// ## E2EE integration point (drives I-38)
///
/// Per `docs/security/E2EE-ARCHITECTURE.md` §12.2 step 3, this service is the
/// single seam where I-38 wires the E2EE cipher: once `E2eeMessageCipher`
/// (I-37) lands, `sendMessage` encrypts the payload into a base64url envelope
/// before insert, and `loadMessages`/`subscribeToMessages` decrypt envelopes
/// on the way out. Add `Future<void> sendEncrypted(...)` here without touching
/// call sites; `messages.content` stays the opaque envelope (E2EE §6.6).
class ChatService {
  final SupabaseClient client;
  final RealtimeService realtime;

  ChatService({required this.client, required this.realtime});

  GoTrueClient get auth => client.auth;

  Future<List<Map<String, dynamic>>> loadMessages(String chatId, {int limit = 50, int offset = 0}) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('messages')
        .select('id, sender_id, content, media_url, created_at')
        .eq('chat_id', chatId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    return (res as List).reversed.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> sendMessage(String chatId, String content, String? mediaUrl) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client.from('messages').insert({
      'chat_id': chatId,
      'sender_id': user.id,
      'content': InputSanitizer.sanitize(
        content,
        maxLength: InputSanitizer.messageMaxLength,
      ),
      'media_url': mediaUrl,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> subscribeToMessages(
    String chatId,
    void Function(Map<String, dynamic>) onInsert,
  ) {
    return realtime.subscribeToMessages(chatId, onInsert);
  }
}
