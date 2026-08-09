import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/features/chat/chat_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// E2EE chat screen: message history (decrypted on load), realtime live
/// inserts (decrypted on delivery), and a send input row. Functional MVP
/// (visual polish is U-12's later restyle pass).
class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  /// Live inserts append to the thread (dispose-safe: the channel is
  /// unsubscribed on dispose). Rows arrive as raw envelopes and are
  /// decrypted by [ChatService.subscribeToMessages] before they reach the
  /// provider.
  void _subscribeRealtime() {
    _channel = ref
        .read(chatE2eeServiceProvider)
        .subscribeToMessages(widget.chatId, (row) {
      ref
          .read(chatMessagesProvider(widget.chatId).notifier)
          .addMessage(row);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await ref
          .read(chatMessagesProvider(widget.chatId).notifier)
          .send(widget.chatId, text);
    } catch (_) {
      // Send failures surface through the list's error state on refresh;
      // keep the composer usable.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).chatSendError)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messages = ref.watch(chatMessagesProvider(widget.chatId));
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.user?['id'];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chatTitle)),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text(
                  l10n.chatLoadError,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
              data: (rows) => rows.isEmpty
                  ? Center(
                      child: Text(
                        l10n.chatEmpty,
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: rows.length,
                      itemBuilder: (context, index) => _MessageBubble(
                        row: rows[index],
                        isOwn:
                            currentUserId != null &&
                            rows[index]['sender_id'] == currentUserId,
                      ),
                    ),
            ),
          ),
          _composer(l10n),
        ],
      ),
    );
  }

  Widget _composer(AppLocalizations l10n) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: VInput(
                label: l10n.chatInputHint,
                controller: _controller,
                maxLines: 3,
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 96,
              child: VButton.emphasized(
                label: l10n.chatSend,
                onPressed: _send,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isOwn;

  const _MessageBubble({required this.row, required this.isOwn});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decryptFailed = row['decryptFailed'] == true;
    final text = decryptFailed ? l10n.chatUndecryptable : (row['content'] as String? ?? '');
    final bubbleColor = isOwn ? AppColors.white : AppColors.discoBlack;
    final textColor = isOwn ? AppColors.discoBlack : AppColors.white;

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.white),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: decryptFailed ? AppColors.muted : textColor,
            fontStyle: decryptFailed ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
