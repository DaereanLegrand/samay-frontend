import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/chat/widgets/chat_thread_view.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// E2EE chat screen (ISSUE 4): a THIN scaffold over the reusable
/// [ChatThreadView] — the peer username (or the group name, which the inbox
/// RPC serves as `peer_username` for group chats) in the [VHeaderBar]. The
/// 1:1 thread and the group detail Chat tab mount the SAME [ChatThreadView];
/// the only difference is `groupId`, resolved here from the inbox row
/// (`reference_id` when the row is a group chat) so group peer bubbles carry
/// sender labels.
class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Peer identity for the AppBar: the inbox row carries the username (the
    // chat list is the normal entry, so the provider is warm); deep links
    // fall back to the generic title until the inbox resolves. For group
    // chats the row's `reference_id` resolves the group id that switches
    // the thread into group mode (sender labels).
    final inbox = ref.watch(chatInboxProvider);
    String? peerUsername;
    String? groupId;
    for (final item in inbox.valueOrNull ?? const <ChatInboxItem>[]) {
      if (item.chatId == widget.chatId) {
        peerUsername = item.peerUsername;
        if (item.type == 'group') groupId = item.referenceId;
      }
    }

    return Scaffold(
      body: VHeaderBar(
        title: peerUsername ?? l10n.chatTitle,
        child: ChatThreadView(chatId: widget.chatId, groupId: groupId),
      ),
    );
  }
}
