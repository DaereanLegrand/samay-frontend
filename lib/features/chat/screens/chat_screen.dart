import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
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
  /// decrypted by [ChatService.subscribeToMessages] (via the repository)
  /// before they reach the provider.
  void _subscribeRealtime() {
    _channel = ref
        .read(chatE2eeRepositoryProvider)
        .subscribe(widget.chatId, (row) {
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

  /// Fetches the next older page (CHAT spec "scroll up → paginate older").
  /// Rendered as a button rather than a scroll listener for testability
  /// (I-56 decision); failures keep the loaded thread and show a snackbar.
  Future<void> _loadOlder() async {
    try {
      await ref.read(chatMessagesProvider(widget.chatId).notifier).loadOlder();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).chatLoadError)),
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
              loading: () => const VLoadingView(),
              error: (error, _) => ErrorView(
                message: l10n.chatLoadError,
                onRetry: () =>
                    ref.invalidate(chatMessagesProvider(widget.chatId)),
              ),
              data: (state) {
                if (state.messages.isEmpty) {
                  return VEmptyView(
                    icon: Icons.chat_bubble_outline,
                    title: l10n.chatEmpty,
                  );
                }
                final showHeader = state.hasMore || state.loadingOlder;
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: state.messages.length + (showHeader ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (showHeader && index == 0) {
                      return _olderHeader(l10n, state);
                    }
                    final rowIndex = index - (showHeader ? 1 : 0);
                    final row = state.messages[rowIndex];
                    return _MessageBubble(
                      row: row,
                      isOwn:
                          currentUserId != null &&
                          row['sender_id'] == currentUserId,
                    );
                  },
                );
              },
            ),
          ),
          _composer(l10n),
        ],
      ),
    );
  }

  /// Top-of-list pagination row: a small loader while an older page is
  /// in flight, otherwise the "Cargar anteriores" button (hidden when the
  /// server has no more history).
  Widget _olderHeader(AppLocalizations l10n, ChatMessagesState state) {
    if (state.loadingOlder) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Center(
      child: TextButton(
        onPressed: _loadOlder,
        child: Text(l10n.chatLoadOlder),
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
          // U-25 (§4.2): every component radius = 0 — the 16px bubble pill
          // was the pre-disco Material default; the white 1px border + the
          // left/right alignment carry the bubble signal (§7.2).
          borderRadius: BorderRadius.zero,
          border: Border.all(color: AppColors.white),
        ),
        child: Text(
          text,
          style: TextStyle(
            // §2.4: informational text is mutedStrong (#999999 AA) — `muted`
            // #666666 fails 1.4.3 at normal size.
            color: decryptFailed ? AppColors.mutedStrong : textColor,
            fontStyle: decryptFailed ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }
}
