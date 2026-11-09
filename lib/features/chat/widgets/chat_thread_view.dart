import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/models/user_profile.dart';
import 'package:samay/core/models/group_member.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/core/theme/app_theme_scope.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/report_sheet.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_spinner.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/shared/widgets/v_thinking_dots.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:samay/core/theme/app_palette_context.dart';

/// The E2EE message thread, reusable across entry points: the 1:1 chat screen
/// and the group detail Chat tab mount the SAME widget. It shows decrypted
/// history, WhatsApp-style message statuses (✓ sent / ✓✓ received / blue ✓✓
/// read via `messages.read_at`), per-message time, sticky day chips, and flat
/// monochrome bubbles — own bubbles are `surfaceAlt`, peer bubbles `surface`,
/// both separated by a hairline; the send button is a flat white circular
/// up-arrow control.
///
/// [groupId] switches the thread into GROUP mode: peer bubbles label their
/// SENDER (the username resolved from [groupMembersProvider] — member rows
/// carry `users.username`, the short-uid-prefix fallback never crashes) and
/// the 1:1-only peer-reinstall notice is skipped. With a null [groupId] the
/// thread renders exactly the 1:1 experience.
///
/// E2EE invariant (DO NOT break): every message path still goes through the
/// E2EE-wired [ChatRepository] — encrypt-on-send, decrypt-on-load and
/// decrypt-on-realtime are untouched. The read-receipt channel
/// ([ChatRepository.subscribeToMessageReads]) merges ONLY `read_at` into the
/// local state; it never decrypts and never renders envelope content.
class ChatThreadView extends ConsumerStatefulWidget {
  final String chatId;

  /// The group id when this thread is a group chat (sender labels on peer
  /// bubbles); null for the 1:1 thread.
  final String? groupId;

  const ChatThreadView({super.key, required this.chatId, this.groupId});

  @override
  ConsumerState<ChatThreadView> createState() => _ChatThreadViewState();
}

class _ChatThreadViewState extends ConsumerState<ChatThreadView> {
  final TextEditingController _controller = TextEditingController();

  /// Drives the thread's [CustomScrollView]: auto-scroll to the newest message
  /// on first load and on arrivals while the user is at the bottom. The
  /// controller lives in [State], [hasClients] guards the un-attached period,
  /// and [animateTo]/[jumpTo] move the position.
  final ScrollController _scrollController = ScrollController();

  /// Distance (px) from the newest message that still counts as "at the
  /// bottom" — arrivals auto-scroll only inside this trigger zone (60 px ≈
  /// one short bubble), so a reader just a couple of messages up is never
  /// yanked down.
  static const double _bottomThreshold = 60;

  /// True while the viewport is within [_bottomThreshold] of the newest
  /// message. Updated by the scroll listener; only read by the auto-scroll
  /// decision (never rendered), so no rebuild is needed.
  bool _isAtBottom = false;

  RealtimeChannel? _channel;
  RealtimeChannel? _readsChannel;
  RealtimeChannel? _deletesChannel;
  RealtimeChannel? _groupReadsChannel;

  /// True while [chatMessagesProvider].send is in flight — drives the
  /// [VThinkingDots] send-button loading state and the optimistic bubble's
  /// single-check status.
  bool _sending = false;

  /// Diameter of the circular send button. The composer's single-line input
  /// is forced to this height so field and button align; the button keeps
  /// this fixed height while the input grows on wrap.
  static const double _sendButtonSize = 44;

  /// Per-thread username cache for group senders with NO row in
  /// [groupMembersProvider] (an invited-then-accepted user's member list can
  /// be a stale empty cache). [groupMembersProvider] stays the primary
  /// source — this map only holds senders the members list did not resolve.
  final Map<String, String> _resolvedSenders = {};

  /// In-flight username lookups (one per sender id): concurrent bubbles for
  /// the same sender coalesce onto the single in-flight future — strictly one
  /// lookup per sender id per thread.
  final Map<String, Future<void>> _senderLookups = {};

  /// Sender ids whose profile lookup found no row (or failed) — never
  /// retried within this thread; the uid-prefix fallback is their final
  /// label (a genuinely unresolvable id is the ONLY case that keeps it).
  final Set<String> _unresolvedSenders = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _subscribeRealtime();
    _subscribeReads();
    _subscribeDeletes();
    if (widget.groupId != null) {
      // GROUP mode: per-member read receipts — the
      // sender's ticks flip blue the moment the LAST member reads.
      _subscribeGroupReads();
    } else {
      // 1:1 only — a group thread has no single peer session to rekey.
      _checkPeerReinstall();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _readsChannel?.unsubscribe();
    _deletesChannel?.unsubscribe();
    _groupReadsChannel?.unsubscribe();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Tracks "at the bottom" while the user scrolls: the thread auto-scrolls
  /// on new arrivals ONLY inside the [_bottomThreshold] trigger zone.
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    _isAtBottom =
        position.pixels >= position.maxScrollExtent - _bottomThreshold;
  }

  /// True while the scroll-to-bottom loop is in flight. New arrivals during
  /// it COALESCE onto the running loop (each step re-targets the newest
  /// extent), so concurrent chains can never cancel each other's animations
  /// mid-flight (the ping-pong that made pumpAndSettle spin forever).
  bool _scrollingToBottom = false;

  /// Scrolls the thread to the newest message (max scroll extent). Runs in a
  /// post-frame callback so the item that just arrived (or the just-built
  /// list on first load) is laid out first — [maxScrollExtent] is only known
  /// after layout.
  void _scrollToBottom() {
    if (_scrollingToBottom) return;
    _scrollingToBottom = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _scrollingToBottom = false;
        return;
      }
      _animateToNewest(_scrollController.position);
    });
  }

  /// Animates (or jumps, under reduced motion) the thread to the newest
  /// message, REPEATING until the position truly reaches the extent. The
  /// lazy list's [ScrollMetrics.maxScrollExtent] is an ESTIMATE that refines
  /// as the bottom items build during the scroll (api.flutter.dev —
  /// ScrollMetrics), so one scroll can stop short of the real bottom; each
  /// post-frame re-check converges once every item is laid out.
  Future<void> _animateToNewest(ScrollPosition position) async {
    final target = position.maxScrollExtent;
    if (position.pixels >= target - 1) {
      _scrollingToBottom = false;
      return;
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      position.jumpTo(target);
    } else {
      await position.animateTo(
        target,
        duration: SamayDurations.fast,
        curve: SamayDurations.defaultCurve,
      );
    }
    if (!mounted || !_scrollController.hasClients) {
      _scrollingToBottom = false;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        _scrollingToBottom = false;
        return;
      }
      _animateToNewest(_scrollController.position);
    });
  }

  /// The thread opened (or a live message arrived while open) → bump the
  /// read watermark so the feed button's unread badge drops (RPC
  /// `mark_chat_read`). Best-effort.
  void _markRead() {
    ref.read(chatInboxProvider.notifier).markRead(widget.chatId);
  }

  /// Read receipts: stamps `read_at` on the caller's peer's unread messages
  /// (RPC `mark_messages_read`) so the SENDER's thread flips grey → blue
  /// ticks live. Skipped entirely when the caller's read-receipts privacy
  /// switch is OFF — no receipts are ever sent. Best-effort:
  /// a failure only delays the flip until the next refresh.
  Future<void> _markMessagesRead() async {
    final enabled = ref.read(readReceiptsEnabledProvider).valueOrNull ?? true;
    if (!enabled) return;
    try {
      await ref
          .read(chatE2eeRepositoryProvider)
          .markMessagesRead(widget.chatId);
    } catch (e, st) {
      AppLogger.instance.error(
        'chat markMessagesRead failed chat=${widget.chatId} '
            'type=${e.runtimeType}',
        '$st',
      );
    }
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
      _markRead();
      _markMessagesRead();
    });
  }

  /// Live `read_at` flips (the peer's device stamped our messages read):
  /// only the status field is merged — the raw row's envelope is never
  /// touched, decrypted or rendered on this channel.
  void _subscribeReads() {
    _readsChannel = ref
        .read(chatE2eeRepositoryProvider)
        .subscribeToMessageReads(widget.chatId, (row) {
          final id = row['id'];
          if (id is! String) return;
          final raw = row['read_at'];
          ref
              .read(chatMessagesProvider(widget.chatId).notifier)
              .updateMessageRead(
                id,
                raw is String ? DateTime.tryParse(raw) : null,
              );
        });
  }

  /// Live hard-deletes (the sender deleted for everyone, or the undecryptable
  /// cleanup): the row leaves the thread live.
  void _subscribeDeletes() {
    _deletesChannel = ref
        .read(chatE2eeRepositoryProvider)
        .subscribeToMessageDeletes(widget.chatId, (row) {
          final id = row['id'];
          if (id is! String) return;
          ref
              .read(chatMessagesProvider(widget.chatId).notifier)
              .removeDeletedMessage(id);
        });
  }

  /// Live per-member read flips in GROUP chats: each
  /// `message_reads` INSERT carries one (message_id, user_id, read_at)
  /// receipt — merged into the row's read set so the sender's ticks flip
  /// blue the moment the LAST other member reads (and never before).
  void _subscribeGroupReads() {
    _groupReadsChannel = ref
        .read(chatE2eeRepositoryProvider)
        .subscribeToGroupMessageReads(widget.chatId, (row) {
          final messageId = row['message_id'];
          final userId = row['user_id'];
          if (messageId is! String || userId is! String) return;
          final raw = row['read_at'];
          final readAt = raw is DateTime
              ? raw
              : raw is String
              ? DateTime.tryParse(raw)
              : null;
          if (readAt == null) return;
          ref
              .read(chatMessagesProvider(widget.chatId).notifier)
              .markMessageRead(messageId, userId, readAt);
        });
  }

  /// E2EE §7.5 reinstall notice: once per chat, when the peer's
  /// PUBLISHED identity differs from the one bound to the stored session,
  /// inform the user ("El otro usuario reinstaló la app o cambió de
  /// dispositivo"). Informational only — the session heals automatically on
  /// this device's next send (unacknowledged-init semantics). The seen-flag
  /// persists in the Hive config box; failures are logged and swallowed.
  /// 1:1 only — group threads have no single peer session to rekey.
  Future<void> _checkPeerReinstall() async {
    try {
      final repo = ref.read(chatE2eeRepositoryProvider);
      if (!await repo.peerNeedsRekey(widget.chatId)) return;
      final flagKey = 'reinstall_notice_seen_${widget.chatId}';
      final hive = ref.read(hiveServiceProvider);
      if (hive.getCachedConfig()?[flagKey] == '1') return;
      await hive.cacheConfig({flagKey: '1'});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).chatPeerReinstalled),
        ),
      );
    } catch (e, st) {
      AppLogger.instance.error(
        'chat peer-reinstall notice failed chat=${widget.chatId}: $e',
        '$st',
      );
    }
  }

  /// Long-press message actions:
  /// a bottom sheet with "Eliminar para todos" (OWN messages only — the
  /// server enforces sender + a 5-minute window with ITS clock) and
  /// "Eliminar para mí" (any message, any age, this device only). Own
  /// committed messages additionally expose the message-status sheet.
  Future<void> _showMessageActions(Map<String, dynamic> row, bool isOwn) async {
    final l10n = AppLocalizations.of(context);
    final id = row['id'];
    if (id is! String) return;
    final notifier = ref.read(chatMessagesProvider(widget.chatId).notifier);
    final pending = row['pending'] == true;

    // Local UX pre-check for the 5-minute window (server remains the
    // authority): own messages older than 5 min lose the for-everyone option.
    final rawSent = row['sent_at'];
    final sentAt = rawSent is DateTime
        ? rawSent
        : rawSent is String
        ? DateTime.tryParse(rawSent)
        : null;
    final withinWindow =
        sentAt != null &&
        DateTime.now().toUtc().difference(sentAt.toUtc()) <=
            const Duration(minutes: 5);

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Own committed messages expose the delivery/read status
            // ("Enviado / Leído por N de M") — peer messages only offer
            // deletion (their status is not this device's information).
            if (isOwn && !pending) ...[
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.chatMessageInfo),
                onTap: () => Navigator.pop(context, 'info'),
              ),
              const Divider(height: 1),
            ],
            if (isOwn && withinWindow)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: Text(l10n.chatDeleteForEveryone),
                onTap: () => Navigator.pop(context, 'everyone'),
              ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined),
              title: Text(l10n.chatDeleteForMe),
              onTap: () => Navigator.pop(context, 'me'),
            ),
            if (!pending)
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.chatReportMessage),
                onTap: () => Navigator.pop(context, 'report'),
              ),
            if (!isOwn)
              ListTile(
                leading: const Icon(Icons.block),
                title: Text(l10n.chatBlockUser),
                onTap: () => Navigator.pop(context, 'block'),
              ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'info':
        await _showMessageInfo(row);
      case 'everyone':
        final outcome = await notifier.deleteForEveryone(widget.chatId, id);
        if (!mounted) return;
        if (outcome == MessageDeleteOutcome.tooOld) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.chatDeleteTooOld)));
        } else if (outcome == MessageDeleteOutcome.failed) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.chatDeleteFailed)));
        }
      case 'me':
        await notifier.deleteForMe(widget.chatId, id);
      case 'report':
        await _reportMessage(row);
      case 'block':
        await _blockSender(row);
    }
  }

  /// Reports ONE message through `report_message` (226_chat_moderation). The
  /// chat is E2EE, so the DECRYPTED text of the specific reported row is
  /// disclosed to the moderator queue (the reported row only). Categories and
  /// priority are validated server-side (234_safety_moderation).
  Future<void> _reportMessage(Map<String, dynamic> row) async {
    final id = row['id'];
    if (id is! String) return;
    await showReportSheet(
      context,
      ref,
      targetType: 'message',
      targetId: id,
      plaintext: row['content'] as String?,
      isMessage: true,
      title: AppLocalizations.of(context).chatReportMessage,
    );
  }

  /// Blocks the sender of a peer message (friendships.status='blocked'; the
  /// server now also refuses new direct chats and direct messages between the
  /// blocked pair — 226_chat_moderation). Group-chat senders can be blocked
  /// too; the group thread itself is unaffected.
  Future<void> _blockSender(Map<String, dynamic> row) async {
    final l10n = AppLocalizations.of(context);
    final senderId = row['sender_id'];
    if (senderId is! String || senderId.isEmpty) return;
    try {
      await ref.read(friendsRepositoryProvider).blockUser(senderId);
      ref.invalidate(friendsListProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileUserBlocked)));
    } catch (e) {
      if (mounted) showAppError(context, e);
    }
  }

  /// Message-status sheet: "Enviado" with the send time, and
  /// the read state — per-member "Leído por N de M" (+ names) in GROUP
  /// chats, "Leído HH:mm" / "No leído" in 1:1.
  Future<void> _showMessageInfo(Map<String, dynamic> row) async {
    final l10n = AppLocalizations.of(context);
    final time = _timeLabelOf(row);
    final sentLabel = time.isNotEmpty ? time : '—';
    final Widget readSection;
    if (widget.groupId != null) {
      final readers = ChatMessagesState.readersOf(row);
      final names = <String>[
        for (final r in readers)
          if (r['user_id'] is String) ?_memberNameOf(r['user_id'] as String),
      ];
      readSection = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.chatMessageInfoReadBy(readers.length, otherMembersFor(row)),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (names.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              names.join(', '),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: context.palette.mutedForeground),
            ),
          ],
        ],
      );
    } else {
      final raw = row['read_at'];
      final readAt = raw is DateTime
          ? raw
          : raw is String
          ? DateTime.tryParse(raw)
          : null;
      readSection = Text(
        readAt != null
            ? '${l10n.chatMessageInfoReadAt}: ${_timeOf(readAt)}'
            : l10n.chatMessageInfoNotRead,
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }
    await showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chatMessageInfo,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Text(
                '${l10n.chatMessageInfoSent}: $sentLabel',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              readSection,
            ],
          ),
        ),
      ),
    );
  }

  /// The current other-member count for [row]'s group info sheet (the
  /// CURRENT active roster, minus the caller).
  int otherMembersFor(Map<String, dynamic> row) {
    final currentUserId = ref.read(authStateProvider).valueOrNull?.user?['id'];
    if (widget.groupId == null || currentUserId == null) return 0;
    return _groupMembers
        .map((m) => m.userId)
        .where((id) => id != currentUserId)
        .length;
  }

  static String _timeLabelOf(Map<String, dynamic> row) {
    final raw = row['created_at'];
    final created = raw is DateTime
        ? raw
        : raw is String
        ? DateTime.tryParse(raw)
        : null;
    if (created == null) return '';
    return DateFormat('HH:mm').format(created.toLocal());
  }

  static String _timeOf(DateTime t) => DateFormat('HH:mm').format(t.toLocal());

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() => _sending = true);
    AppLogger.instance.debug(
      'chat send start chat=${widget.chatId} chars=${text.length}',
    );
    try {
      await ref
          .read(chatMessagesProvider(widget.chatId).notifier)
          .send(widget.chatId, text);
      AppLogger.instance.debug('chat send ok chat=${widget.chatId}');
    } catch (e, st) {
      // Send failures surface through the list's error state on refresh;
      // keep the composer usable. Log the REAL error (never the message
      // content): runtime type, message, mapped AppError code + stack.
      final mapped = e.toAppError();
      AppLogger.instance.error(
        'chat send failed chat=${widget.chatId} '
            'type=${e.runtimeType} error=${mapped.code} "${mapped.message}"',
        '$st',
      );
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
  /// Rendered as a button rather than a scroll listener for testability;
  /// failures keep the loaded thread and show a snackbar.
  Future<void> _loadOlder() async {
    try {
      await ref.read(chatMessagesProvider(widget.chatId).notifier).loadOlder();
    } catch (e, st) {
      final mapped = e.toAppError();
      AppLogger.instance.error(
        'chat loadOlder failed chat=${widget.chatId} '
            'type=${e.runtimeType} error=${mapped.code} "${mapped.message}"',
        '$st',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context).chatLoadError)),
        );
      }
    }
  }

  /// GROUP mode: the sender's username for [row] (member rows carry
  /// `users.username`), a per-thread directly-resolved username, or a short
  /// uid prefix while that lookup is pending / for an id that has genuinely no
  /// profile — never crashes, never null for a sendable id.
  String? _senderNameOf(Map<String, dynamic> row) {
    final senderId = row['sender_id'];
    if (senderId is! String || senderId.isEmpty) return null;
    return _memberNameOf(senderId);
  }

  /// The best-known display name for [userId] (see [_senderNameOf]).
  String? _memberNameOf(String userId) {
    for (final m in _groupMembers) {
      if (m.userId == userId) {
        final username = m.username;
        if (username != null && username.isNotEmpty) return username;
      }
    }
    final resolved = _resolvedSenders[userId];
    if (resolved != null) return resolved;
    // Not a member row and not resolved yet: kick off the direct lookup
    // (coalesced to one per user id) and keep the uid prefix for THIS
    // frame — the resolved username replaces it once the lookup lands.
    if (!_senderLookups.containsKey(userId) &&
        !_unresolvedSenders.contains(userId)) {
      _resolveSenderName(userId);
    }
    return userId.length > 8 ? userId.substring(0, 8) : userId;
  }

  /// Resolves the sender's username directly (user_search_view via the friends
  /// repository — never throws, null for missing) when the members list cannot,
  /// so the label of a resolvable user NEVER stays a uid prefix. One lookup per
  /// sender id per thread: the in-flight map coalesces concurrent bubbles,
  /// [_resolvedSenders] caches the username and [_unresolvedSenders] stops
  /// retries for ids without a profile. Best-effort: failures are logged with
  /// the id only (never the username) and swallowed — the uid-prefix fallback
  /// remains.
  Future<void> _resolveSenderName(String senderId) {
    final inFlight = _senderLookups[senderId];
    if (inFlight != null) return inFlight;
    final future = _lookupSender(
      senderId,
    ).whenComplete(() => _senderLookups.remove(senderId));
    _senderLookups[senderId] = future;
    return future;
  }

  Future<void> _lookupSender(String senderId) async {
    UserProfile? profile;
    try {
      profile = await ref
          .read(friendsRepositoryProvider)
          .getUserProfile(senderId);
    } catch (e, st) {
      AppLogger.instance.error(
        'chat sender resolve failed sender=$senderId type=${e.runtimeType}',
        '$st',
      );
    }
    if (!mounted) return;
    setState(() {
      if (profile != null && profile.username.isNotEmpty) {
        _resolvedSenders[senderId] = profile.username;
      } else {
        _unresolvedSenders.add(senderId);
      }
    });
  }

  /// GROUP mode: the group's member rows, watched once in [build] and reused
  /// by the list builder and callbacks (resolved lazily — loading/error
  /// degrade to the uid-prefix fallback, never crash).
  List<GroupMember> _groupMembers = const <GroupMember>[];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messages = ref.watch(chatMessagesProvider(widget.chatId));
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.user?['id'];
    final groupId = widget.groupId;
    _groupMembers = groupId == null
        ? const <GroupMember>[]
        : ref.watch(groupMembersProvider(groupId)).valueOrNull ??
              const <GroupMember>[];
    // Group-chat "match created" notices render inline with the thread as a
    // direct access to the minigame. Group threads only.
    final notices = groupId == null
        ? const <Map<String, dynamic>>[]
        : ref.watch(groupMinigameMessagesProvider(groupId)).valueOrNull ??
              const <Map<String, dynamic>>[];

    // First successful thread load → the user is reading it: mark the chat
    // read so the feed badge drops (see [_markRead]), stamp read receipts,
    // and open the thread AT the newest message (standard chat UX).
    // Afterwards, a NEW tail message (realtime arrival, the optimistic send
    // row, the send-confirm refresh) auto-scrolls ONLY while the user is at
    // the bottom — a reader scrolled up into history is never yanked down.
    ref.listen(chatMessagesProvider(widget.chatId), (previous, next) {
      if (next.hasValue && previous?.hasValue != true) {
        _markRead();
        _markMessagesRead();
        _scrollToBottom();
        return;
      }
      if (next.hasValue && previous?.hasValue == true) {
        final prev = previous?.valueOrNull;
        final curr = next.valueOrNull;
        if (prev != null && curr != null) {
          final newTail =
              curr.messages.isNotEmpty &&
              (prev.messages.isEmpty ||
                  curr.messages.last['id'] != prev.messages.last['id']);
          if (newTail && _isAtBottom) _scrollToBottom();
        }
      }
    });

    return Column(
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
              if (state.messages.isEmpty && notices.isEmpty) {
                // VEmptyView resolves the themed inks itself.
                return VEmptyView(
                  icon: Icons.chat_bubble_outline,
                  title: l10n.chatEmpty,
                );
              }
              final showHeader = state.hasMore || state.loadingOlder;
              final entries = _buildThreadEntries(state.messages, notices);
              return _buildThread(
                entries: entries,
                showHeader: showHeader,
                state: state,
                currentUserId: currentUserId,
                l10n: l10n,
              );
            },
          ),
        ),
        _composer(l10n),
      ],
    );
  }

  /// The thread as a `CustomScrollView`: entries split into day sections, each
  /// led by a pinned date chip so the current day stays visible while its
  /// messages scroll. The message list stays lazy via sliver builders.
  Widget _buildThread({
    required List<Object> entries,
    required bool showHeader,
    required ChatMessagesState state,
    required String? currentUserId,
    required AppLocalizations l10n,
  }) {
    final sections = <_ThreadSection>[];
    _ThreadSection? section;
    for (final entry in entries) {
      if (entry is _DateEntry) {
        section = _ThreadSection(label: entry.label(l10n));
        sections.add(section);
      } else {
        section ??= _ThreadSection(label: '');
        if (sections.isEmpty) sections.add(section);
        section.entries.add(entry);
      }
    }
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        if (showHeader)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: _olderHeader(l10n, state),
            ),
          ),
        for (final s in sections)
          SliverMainAxisGroup(
            slivers: [
              if (s.label.isNotEmpty)
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _DateHeaderDelegate(label: s.label),
                ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) =>
                        _buildEntry(s.entries[i], currentUserId, l10n),
                    childCount: s.entries.length,
                  ),
                ),
              ),
            ],
          ),
        const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.lg)),
      ],
    );
  }

  /// One thread entry as a widget: a minigame notice card or a message bubble.
  Widget _buildEntry(
    Object entry,
    String? currentUserId,
    AppLocalizations l10n,
  ) {
    if (entry is _MinigameEntry) {
      return _MinigameNoticeCard(row: entry.row);
    }
    final row = (entry as _MessageEntry).row;
    final isOwn = currentUserId != null && row['sender_id'] == currentUserId;
    final isPeerGroupMessage = widget.groupId != null && !isOwn;
    // The readers that matter for the sender's blue check are the CURRENT
    // other active members — a departed member's stale receipt never counts.
    final otherMemberIds = widget.groupId != null && currentUserId != null
        ? _groupMembers
              .map((m) => m.userId)
              .where((id) => id != currentUserId)
              .toSet()
        : const <String>{};
    return _MessageBubble(
      row: row,
      isOwn: isOwn,
      senderName: isPeerGroupMessage ? _senderNameOf(row) : null,
      senderAvatarUrl: isPeerGroupMessage ? _memberAvatarOf(row) : null,
      isGroup: widget.groupId != null,
      otherMemberIds: otherMemberIds,
      onLongPress: () => _showMessageActions(row, isOwn),
    );
  }

  /// GROUP mode: the sender's avatar for [row] when a member row carries one.
  String? _memberAvatarOf(Map<String, dynamic> row) {
    final senderId = row['sender_id'];
    if (senderId is! String || senderId.isEmpty) return null;
    for (final m in _groupMembers) {
      if (m.userId == senderId) {
        final avatar = m.avatarUrl;
        if (avatar != null && avatar.isNotEmpty) return avatar;
      }
    }
    return null;
  }

  /// The thread as display entries: a date separator ([_DateEntry]) before
  /// the first message of each day, then every message. Dates are compared
  /// in local time. Group-chat minigame notices are merged in by `created_at`
  /// and rendered as [_MinigameEntry].
  List<Object> _buildThreadEntries(
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> notices,
  ) {
    final combined = <Map<String, dynamic>>[
      ...rows,
      for (final notice in notices) {...notice, '_minigameNotice': true},
    ];
    // Stable chronological order: real messages and notices interleave by
    // creation time (messages already arrive ordered; the sort keeps the
    // merged stream honest).
    combined.sort((a, b) {
      final ca = _createdOf(a);
      final cb = _createdOf(b);
      if (ca == null || cb == null) return 0;
      return ca.compareTo(cb);
    });
    final entries = <Object>[];
    DateTime? lastDay;
    for (final row in combined) {
      final created = _createdOf(row);
      final day = created == null
          ? null
          : DateTime(created.year, created.month, created.day);
      if (day != null && day != lastDay) {
        entries.add(_DateEntry(day));
        lastDay = day;
      }
      entries.add(
        row['_minigameNotice'] == true
            ? _MinigameEntry(row)
            : _MessageEntry(row),
      );
    }
    return entries;
  }

  static DateTime? _createdOf(Map<String, dynamic> row) {
    final raw = row['created_at'];
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  /// Top-of-list pagination row: a small loader while an older page is
  /// in flight, otherwise the "Cargar anteriores" button (hidden when the
  /// server has no more history).
  Widget _olderHeader(AppLocalizations l10n, ChatMessagesState state) {
    if (state.loadingOlder) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: VSpinner(size: 20)),
      );
    }
    return Center(
      child: TextButton(onPressed: _loadOlder, child: Text(l10n.chatLoadOlder)),
    );
  }

  /// Glass input (VInput) + the flat WHITE send button: "instead of orange
  /// use white for buttons and bubbles" — no peach gradient on the chat
  /// controls. While a send is in flight the button drops its label and
  /// pulses [VThinkingDots] (black on white).
  Widget _composer(AppLocalizations l10n) {
    // The input is borderless/backgroundless, so the composer docks as a bar
    // — surface fill + hairline top edge divide it from the thread. The send
    // control is a circular white up-arrow button.
    final palette = AppThemeScope.paletteOf(context);
    final themed = AppThemeScope.isThemed(context);
    return Container(
      decoration: BoxDecoration(
        color: themed ? palette.surface : context.palette.surface,
        border: Border(
          top: BorderSide(color: themed ? palette.hairline : context.palette.hairline),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.sm,
          ),
          // The button pins to the bottom (end) at a fixed size while the
          // input grows upward as text wraps.
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // 1:1 chats open the DIRECT hub, group chats the group hub —
              // both offer the Direct/Group toggle, so playing with either is
              // reachable from inside any chat. Flag-gated (kill-switch).
              if (ref.isEnabled(AppFeatureFlag.minigames)) ...[
                _minigamesButton(l10n),
                const SizedBox(width: 8),
              ],
              Expanded(
                // minHeight == the button's diameter so an empty/single-line
                // field is exactly the button's height; maxLines 3 caps the
                // vertical growth. textAlignVertical centers the single-line
                // text inside that forced height.
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: _sendButtonSize),
                  child: VInput(
                    label: l10n.chatInputHint,
                    controller: _controller,
                    maxLines: 3,
                    textAlignVertical: TextAlignVertical.center,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _sendButton(l10n),
            ],
          ),
        ),
      ),
    );
  }

  /// Circular minigames entry button: a muted sports icon that opens the
  /// DIRECT hub from a 1:1 chat or the GROUP hub from a group chat — both
  /// carry the Direct/Group toggle inside.
  Widget _minigamesButton(AppLocalizations l10n) {
    return SizedBox(
      key: const ValueKey('chatMinigameButton'),
      width: _sendButtonSize,
      height: _sendButtonSize,
      child: Tooltip(
        message: l10n.minigamesTitle,
        child: Material(
          color: AppColors.transparent,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _openMinigames,
            child: Icon(
              Icons.sports_esports,
              color: context.palette.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }

  /// 1:1 chat → the DIRECT hub (play with this friend without a group);
  /// group chat → that group's hub. The hub toggle covers the other scope.
  void _openMinigames() {
    final groupId = widget.groupId;
    context.push(
      groupId == null
          ? RoutePaths.minigamesDirect
          : RoutePaths.minigames(groupId),
    );
  }

  /// Circular white send button — black up arrow; [VThinkingDots] (black)
  /// while a send is in flight. Stays at its fixed diameter regardless of
  /// the input's height.
  Widget _sendButton(AppLocalizations l10n) {
    final Widget content = Center(
      child: _sending
          ? VThinkingDots(color: context.palette.background)
          : Icon(Icons.arrow_upward, color: context.palette.background),
    );
    return SizedBox(
      key: const ValueKey('chatSendButton'),
      width: _sendButtonSize,
      height: _sendButtonSize,
      child: Tooltip(
        message: l10n.chatSend,
        child: Material(
          color: context.palette.foreground,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: _sending ? null : _send, child: content),
        ),
      ),
    );
  }
}

/// A day separator entry in the thread (see
/// [_ChatThreadViewState._buildThreadEntries]).
class _DateEntry {
  final DateTime day;

  const _DateEntry(this.day);

  String label(AppLocalizations l10n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day == today) return l10n.commonToday;
    if (day == today.subtract(const Duration(days: 1))) {
      return l10n.commonYesterday;
    }
    return DateFormat('dd/MM/yyyy').format(day);
  }
}

class _MessageEntry {
  final Map<String, dynamic> row;

  const _MessageEntry(this.row);
}

/// A group-chat notice entry ("match created") — see [_MinigameNoticeCard].
class _MinigameEntry {
  final Map<String, dynamic> row;

  const _MinigameEntry(this.row);
}

/// The group-chat "match created" bubble (216_minigame_group_message): the
/// game name plus a direct-access action that opens the partida. The session
/// detail resolves the caller's state (participant lobby, pending-invite
/// accept card, or finished summary), so one destination covers all cases.
class _MinigameNoticeCard extends StatelessWidget {
  const _MinigameNoticeCard({required this.row});

  final Map<String, dynamic> row;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sessionId = row['session_id'] as String?;
    final rawSession = row['session'];
    final session = rawSession is Map
        ? Map<String, dynamic>.from(rawSession)
        : null;
    final finished = session?['status'] == 'finished';
    final gameName = session == null
        ? l10n.minigamesTitle
        : minigameGameName(l10n, session['game_type'] as String?);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: VCard(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sports_esports, color: context.palette.foreground),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.minigamesGroupMessage(gameName),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                if (sessionId != null)
                  VButton.emphasized(
                    label: finished ? l10n.minigamesView : l10n.minigamesJoin,
                    onPressed: () =>
                        context.push(RoutePaths.minigameSession(sessionId)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One day's entries under a single (pinned) date chip.
class _ThreadSection {
  _ThreadSection({required this.label});

  final String label;
  final List<Object> entries = [];
}

/// Pinned header rendering one day's chip over the black page, so the day
/// label stays visible while that day's messages scroll past.
class _DateHeaderDelegate extends SliverPersistentHeaderDelegate {
  _DateHeaderDelegate({required this.label});

  final String label;

  static const double _height = 40;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // The pinned band must match the actual page background — on a themed
    // group chat a black band cut a hole across the thread.
    final palette = AppThemeScope.paletteOf(context);
    return ColoredBox(
      color: palette.background,
      child: Center(child: _DateChip(label: label)),
    );
  }

  @override
  bool shouldRebuild(covariant _DateHeaderDelegate oldDelegate) =>
      oldDelegate.label != label;
}

/// A centered day chip ("Today" / "Yesterday" / dd/MM/yyyy) separating the
/// thread into date groups — WhatsApp-style date context.
class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final palette = AppThemeScope.paletteOf(context);
    final themed = AppThemeScope.isThemed(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: themed ? palette.surfaceAlt : context.palette.surfaceAlt,
        border: Border.fromBorderSide(
          BorderSide(color: themed ? palette.hairline : context.palette.hairline),
        ),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: themed ? palette.foreground : context.palette.mutedForeground,
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isOwn;

  /// GROUP mode: the sender's username shown above the message inside PEER
  /// bubbles (null in 1:1 threads — the bubble renders exactly as before).
  final String? senderName;

  /// GROUP mode: the sender's avatar, shown beside peer bubbles. Identity is
  /// carried by the avatar and the bold name, never by hue.
  final String? senderAvatarUrl;

  /// GROUP mode: the sender's ticks flip BLUE only when every CURRENT other
  /// active member has read the message.
  final bool isGroup;
  final Set<String> otherMemberIds;

  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.row,
    required this.isOwn,
    this.senderName,
    this.senderAvatarUrl,
    this.isGroup = false,
    this.otherMemberIds = const {},
    this.onLongPress,
  });

  /// Bubble corners — sharp, matching the rest of the design language.
  static const BorderRadius _bubbleRadius = AppRadius.sharp;

  static const EdgeInsets _bubblePadding = EdgeInsets.symmetric(
    horizontal: AppSpacing.md,
    vertical: AppSpacing.sm,
  );

  /// Bubbles cap at 320 logical px so the thread reads as ONE conversation
  /// surface. Group peer bubbles add the avatar column beside that cap.
  static const double _maxBubbleWidth = 320;

  /// Group peer avatar diameter.
  static const double _avatarSize = 28;

  /// In-bubble clock: 24h local time of `created_at`.
  static String _timeLabel(Map<String, dynamic> row) {
    final raw = row['created_at'];
    final created = raw is DateTime
        ? raw
        : raw is String
        ? DateTime.tryParse(raw)
        : null;
    if (created == null) return '';
    return DateFormat('HH:mm').format(created.toLocal());
  }

  /// `read_at` of the message, if the peer's device has stamped it (the
  /// read-receipt flip — blue double check).
  static DateTime? _readAtOf(Map<String, dynamic> row) {
    final raw = row['read_at'];
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final decryptFailed = row['decryptFailed'] == true;
    final text = decryptFailed
        ? l10n.chatUndecryptable
        : (row['content'] as String? ?? '');
    final id = row['id'];
    final pending = row['pending'] == true;

    final name = senderName;
    final showAvatar = !isOwn && name != null && name.isNotEmpty;
    final bubble = isOwn
        ? _ownBubble(context, id, text, decryptFailed, pending, l10n)
        : _peerBubble(context, id, text, decryptFailed, l10n);

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth:
                  _maxBubbleWidth +
                  (showAvatar ? _avatarSize + AppSpacing.sm : 0),
            ),
            child: showAvatar
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProfileAvatar(
                        size: _avatarSize,
                        imageUrl: senderAvatarUrl,
                        initials: _initials(name),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Flexible(child: bubble),
                    ],
                  )
                : bubble,
          ),
        ),
      ),
    );
  }

  /// Two-glyph initials for the group avatar fallback.
  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '';
    final first = parts.first;
    final second = parts.length > 1 ? parts[1] : '';
    final a = first[0];
    final b = second.isNotEmpty
        ? second[0]
        : (first.length > 1 ? first[1] : '');
    return (a + b).toUpperCase();
  }

  /// Own message: a flat `surfaceAlt` bubble with a hairline edge, white text,
  /// and a bottom-right footer with the time + the delivery ticks (✓ sent /
  /// ✓✓ received / blue ✓✓ read). In GROUP mode the blue ticks require every
  /// other member's read.
  Widget _ownBubble(
    BuildContext context,
    Object? id,
    String text,
    bool decryptFailed,
    bool pending,
    AppLocalizations l10n,
  ) {
    final readAt = _readAtOf(row);
    final time = _timeLabel(row);
    final palette = AppThemeScope.paletteOf(context);
    final themed = AppThemeScope.isThemed(context);
    final timeStyle = AppTypography.bodySmall.copyWith(
      color: themed ? palette.mutedForeground : AppColors.statusGrey,
    );
    return DecoratedBox(
      key: ValueKey('chatBubbleOwn-$id'),
      decoration: BoxDecoration(
        color: themed ? palette.surfaceAlt : context.palette.surfaceAlt,
        border: Border.fromBorderSide(
          BorderSide(color: themed ? palette.hairline : context.palette.hairline),
        ),
        borderRadius: _bubbleRadius,
      ),
      child: Padding(
        padding: _bubblePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                color: decryptFailed
                    ? (themed ? palette.mutedForeground : context.palette.mutedForeground)
                    : (themed ? palette.foreground : context.palette.foreground),
                fontStyle: decryptFailed ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 2),
            // The hour + the delivery checks stay on ONE footer row at the
            // bottom-right of the bubble (checks at the hour's right — the
            // classic WhatsApp shape).
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decorative clock — excluded from semantics so the bubble
                // announces exactly its content.
                ExcludeSemantics(child: Text(time, style: timeStyle)),
                const SizedBox(width: AppSpacing.xs),
                _MessageStatus(
                  pending: pending,
                  readAt: readAt,
                  l10n: l10n,
                  isGroup: isGroup,
                  otherMemberIds: otherMemberIds,
                  readers: ChatMessagesState.readersOf(row),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Peer message: a flat `surface` bubble with a hairline edge and white
  /// text. GROUP mode labels the sender above the text with a bold name and
  /// the avatar beside the bubble; 1:1 renders the plain bubble.
  Widget _peerBubble(
    BuildContext context,
    Object? id,
    String text,
    bool decryptFailed,
    AppLocalizations l10n,
  ) {
    final time = _timeLabel(row);
    final senderName = this.senderName;
    final palette = AppThemeScope.paletteOf(context);
    final themed = AppThemeScope.isThemed(context);
    final msgStyle = TextStyle(
      color: decryptFailed
          ? (themed ? palette.mutedForeground : context.palette.mutedForeground)
          : (themed ? palette.foreground : context.palette.foreground),
      fontStyle: decryptFailed ? FontStyle.italic : FontStyle.normal,
    );
    final timeStyle = AppTypography.bodySmall.copyWith(
      color: themed ? palette.mutedForeground : context.palette.mutedForeground,
    );
    return DecoratedBox(
      key: ValueKey('chatBubblePeer-$id'),
      decoration: BoxDecoration(
        color: themed ? palette.surface : context.palette.surface,
        border: Border.fromBorderSide(
          BorderSide(color: themed ? palette.hairline : context.palette.hairline),
        ),
        borderRadius: _bubbleRadius,
      ),
      child: Padding(
        padding: _bubblePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (senderName != null && senderName.isNotEmpty) ...[
              // The name must NOT expand the bubble: a ConstrainedBox caps
              // long names (ellipsis still applies) and shrink-wraps short
              // ones.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Text(
                  senderName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: themed ? palette.foreground : context.palette.foreground,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
            ],
            // Message + hour in their own right-aligned column so the hour
            // always sits at the BOTTOM-RIGHT of the bubble (the classic
            // WhatsApp shape) while the sender name above stays left.
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(text, style: msgStyle),
                if (time.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  // Decorative clock (see the own-bubble footer note).
                  ExcludeSemantics(child: Text(time, style: timeStyle)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// WhatsApp-style delivery ticks for OWN messages:
/// - single grey check → sent (optimistic pending row, in flight)
/// - double grey check → received/delivered (committed, not read)
/// - double BLUE check → read (1:1: `read_at` stamped by the peer's device;
///   GROUP: every CURRENT other active member's `message_reads` row exists —
///    — a single reader must NOT turn the ticks blue)
class _MessageStatus extends StatelessWidget {
  final bool pending;
  final DateTime? readAt;
  final AppLocalizations l10n;

  /// GROUP mode: the per-member read set + the CURRENT
  /// roster's other-member ids — blue only when ALL of them read (a
  /// departed member's stale receipt never satisfies the check).
  final bool isGroup;
  final Set<String> otherMemberIds;
  final List<Map<String, dynamic>> readers;

  const _MessageStatus({
    required this.pending,
    required this.readAt,
    required this.l10n,
    this.isGroup = false,
    this.otherMemberIds = const {},
    this.readers = const [],
  });

  @override
  Widget build(BuildContext context) {
    // On a themed group bubble the fixed grey/blue ticks are unreadable against
    // the coloured surface, so the neutral tick uses the derived muted tone and
    // the "read" tick uses the group's own accent (its semantic highlight).
    final palette = AppThemeScope.paletteOf(context);
    final themed = AppThemeScope.isThemed(context);
    final neutral = themed ? palette.mutedForeground : AppColors.statusGrey;
    final read = themed ? palette.accent : AppColors.statusRead;
    final Color color;
    final IconData icon;
    final String label;
    if (pending) {
      color = neutral;
      icon = Icons.check;
      label = l10n.chatSent;
    } else if (isGroup
        ? ChatMessagesState.isReadByAll({
            'message_reads': readers,
          }, otherMemberIds)
        : readAt != null) {
      color = read;
      icon = Icons.done_all;
      label = l10n.chatRead;
    } else {
      color = neutral;
      icon = Icons.done_all;
      label = l10n.chatReceived;
    }
    return Semantics(
      label: label,
      child: Icon(icon, size: 15, color: color),
    );
  }
}
