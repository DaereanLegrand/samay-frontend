import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// Chat inbox (user request 2026-08-15): every chat the user participates in,
/// most-recent-first, with the peer identity, a best-effort last-message
/// preview (E2EE envelopes decrypt client-side; own messages via the outbox)
/// and the unread count. Tap → thread; opening a thread marks it read
/// (RPC `mark_chat_read`, migration 20260815000004). The feed button's unread
/// badge derives from [chatUnreadCountProvider], kept fresh by
/// [InboxRealtimeListener].
class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    super.dispose();
  }

  /// Inbound messages refresh the list live (the shell listener already
  /// keeps the badge; the screen additionally refreshes its own list —
  /// actually [chatInboxProvider] is shared, so an invalidation covers both).
  Future<void> _subscribeRealtime() async {
    try {
      final channel = await ref.read(realtimeServiceProvider).subscribeToInbox((
        _,
      ) {
        if (!mounted) return;
        ref.invalidate(chatInboxProvider);
      });
      if (!mounted) return;
      _channel = channel;
    } catch (e, st) {
      // Realtime is best-effort by design; pull-to-refresh remains.
      AppLogger.instance.error(
        'chat inbox realtime subscribe failed: $e',
        '$st',
      );
    }
  }

  Future<void> _openChat(String chatId) async {
    await context.push(RoutePaths.chat(chatId));
    if (!mounted) return;
    // Coming back from a thread: the watermark moved server-side, so the
    // badge must re-derive.
    ref.invalidate(chatInboxProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final inbox = ref.watch(chatInboxProvider);
    final me = ref.watch(authStateProvider).valueOrNull?.user?['id'];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      appBar: AppBar(
        title: Text(l10n.chatInboxTitle), 
	actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: l10n.socialSearchTooltip,
            onPressed: () => context.push(RoutePaths.userSearch),
          )
        ],
      ),
      body: inbox.when(
        skipLoadingOnRefresh: true,
        loading: () => const VLoadingView(),
        error: (_, _) => ErrorView(
          message: l10n.chatInboxLoadError,
          onRetry: () => ref.read(chatInboxProvider.notifier).refresh(),
        ),
        data: (items) {
          if (items.isEmpty) {
            return VEmptyView(
              icon: Icons.chat_bubble_outline,
              title: l10n.chatInboxEmpty,
              description: l10n.chatInboxEmptyBody,
            );
          }
          return RefreshIndicator(
            onRefresh: () => ref.read(chatInboxProvider.notifier).refresh(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) =>
                  _ChatListTile(item: items[index], me: me, onTap: _openChat),
            ),
          );
        },
      ),
    );
  }
}

/// One inbox row (LUXE chat voice): white liquid glass, peer identity +
/// preview + time on the left, unread [VCountBadge] on the right.
class _ChatListTile extends StatelessWidget {
  const _ChatListTile({
    required this.item,
    required this.me,
    required this.onTap,
  });

  final ChatInboxItem item;
  final String? me;
  final void Function(String chatId) onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final mine =
        item.lastMessageSenderId != null && item.lastMessageSenderId == me;
    final String preview;
    if (item.lastMessageContent == null) {
      preview = '';
    } else if (item.decryptFailed) {
      preview = mine
          ? '${l10n.chatInboxPreviewOwn}…'
          : chatUndecryptablePlaceholder;
    } else {
      preview =
          '${mine ? l10n.chatInboxPreviewOwn : ''}${item.lastMessageContent}';
    }
    final timeLabel = _relativeTime(item.lastMessageAt, l10n);
    final avatarUrl = item.peerAvatarUrl;

    return InkWell(
      onTap: () => onTap(item.chatId),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            // Avatar precedence: a real peer/group avatar URL (VNetworkImage,
            // loaded from Storage) wins; otherwise a group row shows the group
            // icon and a 1:1 row falls back to the peer's initial letter.
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: avatarUrl != null && avatarUrl.isNotEmpty
                  ? SizedBox.expand(
                      child: VNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                      ),
                    )
                  : item.type == 'group'
                  ? const Icon(Icons.group, size: 22, color: Colors.white)
                  : Text(
                      (item.peerUsername?.isNotEmpty ?? false)
                          ? item.peerUsername![0].toUpperCase()
                          : '?',
                      style: AppTypography.titleMedium.copyWith(
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.peerUsername ?? l10n.commonUser,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview.isEmpty ? l10n.chatInboxEmpty : preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMedium.copyWith(
                      color: item.unreadCount > 0
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurfaceVariant,
                      fontWeight: item.unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(timeLabel, style: AppTypography.labelSmall),
                const SizedBox(height: 6),
                VCountBadge(count: item.unreadCount),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Compact relative time ("ahora", "hace 5 m", "hace 3 h", else the date).
  static String _relativeTime(DateTime? at, AppLocalizations l10n) {
    if (at == null) return '';
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return l10n.commonNow;
    if (diff.inHours < 1) return '${diff.inMinutes} m';
    if (diff.inDays < 1) return '${diff.inHours} h';
    return '${at.day.toString().padLeft(2, '0')}/${at.month.toString().padLeft(2, '0')}';
  }
}
