import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/models/user_profile.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/services/chat_service.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/glass/v_glass.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_spinner.dart';
import 'package:samay/shared/widgets/v_input.dart';
import 'package:samay/shared/widgets/v_thinking_dots.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;

/// The E2EE message thread, reusable across entry points (ISSUE 4): the 1:1
/// chat screen and the group detail Chat tab mount the SAME widget — the
/// thread shows decrypted history, WhatsApp-style message statuses (✓ sent /
/// ✓✓ received / blue ✓✓ read via `messages.read_at`), per-message time +
/// day separators and a WHITE design voice — own bubbles are solid white
/// with black text, the send button is a flat white [VButton.emphasized].
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
  RealtimeChannel? _channel;
  RealtimeChannel? _readsChannel;
  RealtimeChannel? _deletesChannel;

  /// True while [chatMessagesProvider].send is in flight — drives the
  /// [VThinkingDots] send-button loading state and the optimistic bubble's
  /// single-check status.
  bool _sending = false;

  /// USER FIX 2: per-thread username cache for group senders with NO row in
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
    _subscribeRealtime();
    _subscribeReads();
    _subscribeDeletes();
    if (widget.groupId == null) {
      // 1:1 only — a group thread has no single peer session to rekey.
      _checkPeerReinstall();
    }
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _readsChannel?.unsubscribe();
    _deletesChannel?.unsubscribe();
    _controller.dispose();
    super.dispose();
  }

  /// The thread opened (or a live message arrived while open) → bump the
  /// read watermark so the feed button's unread badge drops (RPC
  /// `mark_chat_read`, migration 20260815000004). Best-effort.
  void _markRead() {
    ref.read(chatInboxProvider.notifier).markRead(widget.chatId);
  }

  /// Read receipts: stamps `read_at` on the caller's peer's unread messages
  /// (RPC `mark_messages_read`) so the SENDER's thread flips grey → blue
  /// ticks live. Skipped entirely when the caller's read-receipts privacy
  /// switch is OFF — no receipts are ever sent (2026-08-15). Best-effort:
  /// a failure only delays the flip until the next refresh.
  Future<void> _markMessagesRead() async {
    final enabled = ref.read(readReceiptsEnabledProvider).valueOrNull ?? true;
    if (!enabled) return;
    try {
      await ref.read(chatE2eeRepositoryProvider).markMessagesRead(widget.chatId);
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
    _readsChannel = ref.read(chatE2eeRepositoryProvider).subscribeToMessageReads(
      widget.chatId,
      (row) {
        final id = row['id'];
        if (id is! String) return;
        final raw = row['read_at'];
        ref
            .read(chatMessagesProvider(widget.chatId).notifier)
            .updateMessageRead(
              id,
              raw is String ? DateTime.tryParse(raw) : null,
            );
      },
    );
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

  /// E2EE §7.5 reinstall notice (2026-08-16): once per chat, when the peer's
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

  /// Long-press message actions (2026-08-16, WhatsApp-style both-options):
  /// a bottom sheet with "Eliminar para todos" (OWN messages only — the
  /// server enforces sender + a 5-minute window with ITS clock) and
  /// "Eliminar para mí" (any message, any age, this device only).
  Future<void> _showMessageActions(Map<String, dynamic> row, bool isOwn) async {
    final l10n = AppLocalizations.of(context);
    final id = row['id'];
    if (id is! String) return;
    final notifier = ref.read(chatMessagesProvider(widget.chatId).notifier);

    // Local UX pre-check for the 5-minute window (server remains the
    // authority): own messages older than 5 min lose the for-everyone option.
    final rawSent = row['sent_at'];
    final sentAt = rawSent is DateTime
        ? rawSent
        : rawSent is String
        ? DateTime.tryParse(rawSent)
        : null;
    final withinWindow = sentAt != null &&
        DateTime.now().toUtc().difference(sentAt.toUtc()) <=
            const Duration(minutes: 5);

    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;

    switch (action) {
      case 'everyone':
        final outcome = await notifier.deleteForEveryone(widget.chatId, id);
        if (!mounted) return;
        if (outcome == MessageDeleteOutcome.tooOld) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.chatDeleteTooOld)),
          );
        } else if (outcome == MessageDeleteOutcome.failed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.chatDeleteFailed)),
          );
        }
      case 'me':
        await notifier.deleteForMe(widget.chatId, id);
    }
  }

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
  /// Rendered as a button rather than a scroll listener for testability
  /// (I-56 decision); failures keep the loaded thread and show a snackbar.
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
  /// `users.username`), a per-thread directly-resolved username (USER FIX 2),
  /// or a short uid prefix while that lookup is pending / for an id that has
  /// genuinely no profile — never crashes, never null for a sendable id.
  String? _senderNameOf(Map<String, dynamic> row) {
    final senderId = row['sender_id'];
    if (senderId is! String || senderId.isEmpty) return null;
    for (final m in _groupMembers) {
      if (m['user_id'] == senderId) {
        final username = (m['users'] as Map<String, dynamic>?)?['username']
            as String?;
        if (username != null && username.isNotEmpty) return username;
      }
    }
    final resolved = _resolvedSenders[senderId];
    if (resolved != null) return resolved;
    // Not a member row and not resolved yet: kick off the direct lookup
    // (coalesced to one per sender id) and keep the uid prefix for THIS
    // frame — the resolved username replaces it once the lookup lands.
    if (!_senderLookups.containsKey(senderId) &&
        !_unresolvedSenders.contains(senderId)) {
      _resolveSenderName(senderId);
    }
    return senderId.length > 8 ? senderId.substring(0, 8) : senderId;
  }

  /// USER FIX 2: resolves the sender's username directly (user_search_view
  /// via the friends repository — never throws, null for missing) when the
  /// members list cannot, so the label of a resolvable user NEVER stays a
  /// uid prefix. One lookup per sender id per thread: the in-flight map
  /// coalesces concurrent bubbles, [_resolvedSenders] caches the username
  /// and [_unresolvedSenders] stops retries for ids without a profile.
  /// Best-effort: failures are logged with the id only (never the username)
  /// and swallowed — the uid-prefix fallback remains.
  Future<void> _resolveSenderName(String senderId) {
    final inFlight = _senderLookups[senderId];
    if (inFlight != null) return inFlight;
    final future = _lookupSender(senderId).whenComplete(
      () => _senderLookups.remove(senderId),
    );
    _senderLookups[senderId] = future;
    return future;
  }

  Future<void> _lookupSender(String senderId) async {
    UserProfile? profile;
    try {
      profile =
          await ref.read(friendsRepositoryProvider).getUserProfile(senderId);
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

  /// GROUP mode: the group's member rows (resolved lazily — loading/error
  /// degrade to the uid-prefix fallback, never crash).
  List<Map<String, dynamic>> get _groupMembers {
    final groupId = widget.groupId;
    if (groupId == null) return const [];
    return ref
        .watch(groupMembersProvider(groupId))
        .valueOrNull ??
        const <Map<String, dynamic>>[];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final messages = ref.watch(chatMessagesProvider(widget.chatId));
    final currentUserId = ref.watch(authStateProvider).valueOrNull?.user?['id'];

    // First successful thread load → the user is reading it: mark the chat
    // read so the feed badge drops (see [_markRead]) and stamp read receipts.
    ref.listen(chatMessagesProvider(widget.chatId), (previous, next) {
      if (next.hasValue && previous?.hasValue != true) {
        _markRead();
        _markMessagesRead();
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
              if (state.messages.isEmpty) {
                return VEmptyView(
                  icon: Icons.chat_bubble_outline,
                  title: l10n.chatEmpty,
                );
              }
              final showHeader = state.hasMore || state.loadingOlder;
              final entries = _buildThreadEntries(state.messages);
              return ListView.builder(
                padding: const EdgeInsets.all(AppSpacing.lg),
                itemCount: entries.length + (showHeader ? 1 : 0),
                itemBuilder: (context, index) {
                  if (showHeader && index == 0) {
                    return _olderHeader(l10n, state);
                  }
                  final entry = entries[index - (showHeader ? 1 : 0)];
                  if (entry is _DateEntry) {
                    return _DateChip(label: entry.label(l10n));
                  }
                  final row = (entry as _MessageEntry).row;
                  final isOwn =
                      currentUserId != null &&
                      row['sender_id'] == currentUserId;
                  return _MessageBubble(
                    row: row,
                    isOwn: isOwn,
                    // GROUP mode only: label the sender above PEER bubbles;
                    // own bubbles stay clean (and 1:1 renders exactly today's
                    // bubbles — senderName is always null there).
                    senderName:
                        widget.groupId != null && !isOwn
                            ? _senderNameOf(row)
                            : null,
                    onLongPress: () => _showMessageActions(row, isOwn),
                  );
                },
              );
            },
          ),
        ),
        _composer(l10n),
      ],
    );
  }

  /// The thread as display entries: a date separator ([_DateEntry]) before
  /// the first message of each day, then every message. Dates are compared
  /// in local time.
  List<Object> _buildThreadEntries(List<Map<String, dynamic>> rows) {
    final entries = <Object>[];
    DateTime? lastDay;
    for (final row in rows) {
      final created = _createdOf(row);
      final day = created == null
          ? null
          : DateTime(created.year, created.month, created.day);
      if (day != null && day != lastDay) {
        entries.add(_DateEntry(day));
        lastDay = day;
      }
      entries.add(_MessageEntry(row));
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

  /// Glass input (VInput) + the flat WHITE send button (user directive
  /// 2026-08-15: "instead of orange use white for buttons and bubbles" —
  /// no peach gradient on the chat controls). While a send is in flight the
  /// button drops its label and pulses [VThinkingDots] (black on white).
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

/// A centered day chip ("Today" / "Yesterday" / dd/MM/yyyy) separating the
/// thread into date groups — WhatsApp-style date context.
class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.mutedStrong,
            ),
          ),
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

  final VoidCallback? onLongPress;

  const _MessageBubble({
    required this.row,
    required this.isOwn,
    this.senderName,
    this.onLongPress,
  });

  /// Liquid corners — the chat bubbles are the liquid island of the sharp
  /// design language.
  static const BorderRadius _bubbleRadius = BorderRadius.all(
    Radius.circular(16),
  );

  static const EdgeInsets _bubblePadding = EdgeInsets.symmetric(
    horizontal: 14,
    vertical: 10,
  );

  /// Bubbles cap at 320 logical px so the thread reads as ONE conversation
  /// surface.
  static const double _maxBubbleWidth = 320;

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

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: GestureDetector(
          onLongPress: onLongPress,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxBubbleWidth),
            child: isOwn
                ? _ownBubble(id, text, decryptFailed, pending, l10n)
                : _peerBubble(context, id, text, decryptFailed, l10n),
          ),
        ),
      ),
    );
  }

  /// Own message (2026-08-15): SOLID WHITE bubble (user directive — no peach
  /// fill), black text, and a bottom-right footer with the time + the
  /// WhatsApp-style status ticks (✓ sent / ✓✓ received / blue ✓✓ read).
  Widget _ownBubble(
    Object? id,
    String text,
    bool decryptFailed,
    bool pending,
    AppLocalizations l10n,
  ) {
    final readAt = _readAtOf(row);
    final time = _timeLabel(row);
    return DecoratedBox(
      key: ValueKey('chatBubbleOwn-$id'),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: _bubbleRadius,
      ),
      child: Padding(
        padding: _bubblePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              text,
              style: TextStyle(
                color: decryptFailed
                    ? AppColors.mutedStrong
                    : AppColors.discoBlack,
                fontStyle: decryptFailed ? FontStyle.italic : FontStyle.normal,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Decorative clock — excluded from semantics so the bubble
                // announces exactly its content (4.1.2 label contract).
                ExcludeSemantics(
                  child: Text(
                    time,
                    style: const TextStyle(
                      color: AppColors.statusGrey,
                      fontSize: 11,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _MessageStatus(pending: pending, readAt: readAt, l10n: l10n),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Peer message: white-only liquid glass, white text, time in the footer.
  /// GROUP mode adds the sender's username as a small label above the text
  /// (WhatsApp-style); without it (1:1) the bubble renders exactly as today.
  Widget _peerBubble(
    BuildContext context,
    Object? id,
    String text,
    bool decryptFailed,
    AppLocalizations l10n,
  ) {
    final time = _timeLabel(row);
    final senderName = this.senderName;
    return VGlass(
      key: ValueKey('chatBubblePeer-$id'),
      gradient: null,
      radius: _bubbleRadius,
      glowAlpha: 0.0,
      padding: _bubblePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (senderName != null && senderName.isNotEmpty) ...[
            // Group sender label — mutedStrong informational text (AA).
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                senderName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.mutedStrong,
                ),
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            text,
            style: TextStyle(
              color: decryptFailed ? AppColors.mutedStrong : AppColors.white,
              fontStyle: decryptFailed ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          if (time.isNotEmpty) ...[
            const SizedBox(height: 2),
            // Decorative clock (see the own-bubble footer note).
            ExcludeSemantics(
              child: Text(
                time,
                style: const TextStyle(
                  color: AppColors.mutedStrong,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// WhatsApp-style delivery ticks for OWN messages:
/// - single grey check → sent (optimistic pending row, in flight)
/// - double grey check → received/delivered (committed, not read)
/// - double BLUE check → read (`read_at` stamped by the peer's device)
class _MessageStatus extends StatelessWidget {
  final bool pending;
  final DateTime? readAt;
  final AppLocalizations l10n;

  const _MessageStatus({
    required this.pending,
    required this.readAt,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;
    if (pending) {
      color = AppColors.statusGrey;
      icon = Icons.check;
      label = l10n.chatSent;
    } else if (readAt != null) {
      color = AppColors.statusRead;
      icon = Icons.done_all;
      label = l10n.chatRead;
    } else {
      color = AppColors.statusGrey;
      icon = Icons.done_all;
      label = l10n.chatReceived;
    }
    return Semantics(
      label: label,
      child: Icon(icon, size: 15, color: color),
    );
  }
}
