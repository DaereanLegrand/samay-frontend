import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/glass/v_glass.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_aurora.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/shared/widgets/v_thinking_dots.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// E2EE chat screen (LUXE v2 peach family — ORCHESTRATION-LUXE.md "Gradient
/// family → screen map"): message history (decrypted on load), realtime live
/// inserts (decrypted on delivery), and a send input row.
///
/// LUXE restyle (XL-12, XL-18): content-first thread on a whisper-faint
/// peach aurora (α0.04); own messages are liquid radius-16 bubbles filled
/// with the peach family watered 45% toward white (Gemma 14_chat "Lacks
/// focus" → less saturated fill) and a 1px white α0.2 hairline instead of
/// the glow halo; peer messages are white-only liquid glass (no peach —
/// the composer row is the single peach accent). Bubbles cap at 320 logical
/// px so the thread reads as ONE conversation surface. The send button is
/// the family gradient and shows [VThinkingDots] while a send is in flight.
/// E2EE behavior is untouched.
class ChatScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  RealtimeChannel? _channel;

  /// True while [chatMessagesProvider].send is in flight — drives the
  /// [VThinkingDots] send-button loading state (the provider exposes no
  /// typing/sending state; see ORCHESTRATION-LUXE component vocabulary).
  bool _sending = false;

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
    _channel = ref.read(chatE2eeRepositoryProvider).subscribe(widget.chatId, (
      row,
    ) {
      ref.read(chatMessagesProvider(widget.chatId).notifier).addMessage(row);
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() => _sending = true);
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
    } finally {
      if (mounted) setState(() => _sending = false);
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
      // LUXE v2: chat is content-first — the peach aurora stays a whisper
      // (α0.04, the floor of the VAurora range) under the thread, one blob
      // per anchor (all peach: monochrome family, no pink mains).
      body: VAurora(
        gradients: const [
          AppGradients.peach,
          AppGradients.peach,
          AppGradients.peach,
        ],
        opacity: 0.04,
        child: Column(
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
                    padding: const EdgeInsets.all(AppSpacing.lg),
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
      child: TextButton(onPressed: _loadOlder, child: Text(l10n.chatLoadOlder)),
    );
  }

  /// Glass input (VInput — untouched, LUXE liquid input) + the peach
  /// gradient send button. While a send is in flight the button drops its
  /// label and pulses [VThinkingDots] — the campaign's AI-thinking accent.
  Widget _composer(AppLocalizations l10n) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.sm,
        ),
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
                gradient: AppGradients.peach,
                label: l10n.chatSend,
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const VThinkingDots(color: AppColors.discoBlack)
                    : null,
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

  /// LUXE v2 liquid corners (ORCHESTRATION-LUXE: "radius 16–20 for
  /// chips-inputs-sheets (liquid)") — the chat bubbles are the liquid island
  /// of the sharp design language; the previous radius-0 bubble rule was a
  /// pre-LUXE decision and is replaced here.
  static const BorderRadius _bubbleRadius = BorderRadius.all(
    Radius.circular(16),
  );

  static const EdgeInsets _bubblePadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 10,
  );

  /// LUXE v2 "one conversation surface": bubbles cap at 320 logical px —
  /// the thread is the visual center with maximum width utilization, never
  /// over-wide islands.
  static const double _maxBubbleWidth = 320;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decryptFailed = row['decryptFailed'] == true;
    final text = decryptFailed
        ? l10n.chatUndecryptable
        : (row['content'] as String? ?? '');
    final id = row['id'];

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxBubbleWidth),
          child: isOwn
              ? _ownBubble(id, text, decryptFailed)
              : _peerBubble(id, text, decryptFailed),
        ),
      ),
    );
  }

  /// Own message: the peach family **watered 45% toward white** (Gemma
  /// 14_chat: saturated fills read as "lacking focus" — the directive recipe
  /// `AppGradients.watered(peach.colors, mix: 0.45)`) with a 1px white α0.2
  /// hairline replacing the glow halo. Black text keeps AA+ on the watered
  /// fill.
  Widget _ownBubble(Object? id, String text, bool decryptFailed) {
    return DecoratedBox(
      key: ValueKey('chatBubbleOwn-$id'),
      decoration: BoxDecoration(
        borderRadius: _bubbleRadius,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppGradients.watered(
            AppGradients.peach.colors,
            mix: 0.45,
          ),
        ),
        border: Border.all(
          color: AppColors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: _bubblePadding,
        child: Text(
          text,
          style: TextStyle(
            // §2.4: informational text is mutedStrong (#999999 AA) — `muted`
            // #666666 fails 1.4.3 at normal size.
            color: decryptFailed ? AppColors.mutedStrong : AppColors.discoBlack,
            fontStyle: decryptFailed ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ),
    );
  }

  /// Peer message: white-only liquid glass (no peach ring/glow — the
  /// composer row is the single peach accent), white text.
  Widget _peerBubble(Object? id, String text, bool decryptFailed) {
    return VGlass(
      key: ValueKey('chatBubblePeer-$id'),
      gradient: null,
      radius: _bubbleRadius,
      glowAlpha: 0.0,
      padding: _bubblePadding,
      child: Text(
        text,
        style: TextStyle(
          color: decryptFailed ? AppColors.mutedStrong : AppColors.white,
          fontStyle: decryptFailed ? FontStyle.italic : FontStyle.normal,
        ),
      ),
    );
  }
}
