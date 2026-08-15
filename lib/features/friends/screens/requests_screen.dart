import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/glass/glass.dart';
import 'package:samay/shared/widgets/show_app_error.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_aurora.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_refreshable.dart';
import 'package:samay/shared/widgets/v_spinner.dart';

class RequestsScreen extends ConsumerStatefulWidget {
  const RequestsScreen({super.key});

  @override
  ConsumerState<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends ConsumerState<RequestsScreen>
    with SingleTickerProviderStateMixin {
  /// LUXE v2 mint ambient (ORCHESTRATION-LUXE: friends = mint family; the
  /// family's 3 anchor blobs keep the 2–3 blob geometry single-family).
  static const List<AppGradient> _aurora = [
    AppGradients.mint,
    AppGradients.mint,
    AppGradients.mint,
  ];

  late TabController _tabController;

  /// Row ids whose accept/decline/cancel action is in flight (R11, F4): the
  /// tapped row's buttons swap for a spinner; every other row stays
  /// interactive.
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Runs [action] with the [id]'s per-row busy state; clears it afterwards
  /// and surfaces failures as a transient snackbar (F7: snackbars for row
  /// actions — never a blocking dialog).
  Future<void> _run(String id, Future<void> Function() action) async {
    if (_processing.contains(id)) return;
    setState(() => _processing.add(id));
    try {
      await action();
    } catch (e, st) {
      AppLogger.instance.error('requests action error: $e', '$st');
      if (mounted) showErrorSnackBar(context, e);
    } finally {
      if (mounted) setState(() => _processing.remove(id));
    }
  }

  Future<void> _acceptFriend(String id) =>
      _run(id, () async {
        await ref.read(friendsRepositoryProvider).acceptFriendRequest(id);
        ref.invalidate(friendRequestsProvider);
        // The new friend must appear in the list immediately (2026-08-14).
        ref.invalidate(friendsListProvider);
      });

  Future<void> _declineFriend(String id) =>
      _run(id, () async {
        await ref.read(friendsRepositoryProvider).declineFriendRequest(id);
        ref.invalidate(friendRequestsProvider);
        // A declined request can't leave a stale accepted row behind.
        ref.invalidate(friendsListProvider);
      });

  Future<void> _acceptInvite(String membershipId) =>
      _run(membershipId, () async {
        await ref.read(groupsRepositoryProvider).acceptInvite(membershipId);
        ref.invalidate(groupInvitesProvider);
      });

  Future<void> _declineInvite(String membershipId) =>
      _run(membershipId, () async {
        await ref.read(groupsRepositoryProvider).declineInvite(membershipId);
        ref.invalidate(groupInvitesProvider);
      });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final requestsAsync = ref.watch(friendRequestsProvider);
    final invitesAsync = ref.watch(groupInvitesProvider);
    // R12 (F5): count badges on the received/invites tabs — the counts come
    // from the already-loaded providers; zero renders nothing (VCountBadge).
    final receivedCount =
        requestsAsync.valueOrNull?.requests
            .where((r) => r['type'] == 'received')
            .length ??
        0;
    final invitesCount = invitesAsync.valueOrNull?.length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.friendsRequestsTitle),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: _TabLabel(
                text: l10n.friendsTabReceived,
                count: receivedCount,
              ),
            ),
            Tab(child: _TabLabel(text: l10n.friendsTabSent, count: 0)),
            Tab(
              child: _TabLabel(
                text: l10n.friendsTabInvites,
                count: invitesCount,
              ),
            ),
          ],
        ),
      ),
      body: VAurora(
        gradients: _aurora,
        opacity: 0.08,
        child: requestsAsync.when(
          loading: () => const VLoadingView(),
          error: (e, _) => ErrorView(
            message: e.toAppError().message,
            onRetry: () => ref.invalidate(friendRequestsProvider),
          ),
          data: (data) => invitesAsync.when(
            loading: () => const VLoadingView(),
            error: (e, _) => ErrorView(
              message: e.toAppError().message,
              onRetry: () => ref.invalidate(groupInvitesProvider),
            ),
            data: (invites) {
              final received =
                  data.requests.where((r) => r['type'] == 'received').toList();
              final sent = data.requests
                  .where((r) => r['type'] == 'sent')
                  .toList();
              return TabBarView(
                controller: _tabController,
                children: [
                  _buildRequests(received, data.names, isReceived: true),
                  _buildRequests(sent, data.names, isReceived: false),
                  _buildInvites(invites),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildRequests(
    List<Map<String, dynamic>> items,
    Map<String, String> names, {
    required bool isReceived,
  }) {
    final l10n = AppLocalizations.of(context);
    // R13 (F3): every tab refreshes its own provider — requests (received +
    // sent) and invites separately.
    Future<void> onRequestsRefresh() =>
        ref.read(friendRequestsProvider.notifier).refresh();
    if (items.isEmpty) {
      return VRefreshable(
        onRefresh: onRequestsRefresh,
        child: VEmptyView(
          icon: isReceived ? Icons.inbox_outlined : Icons.send_outlined,
          title: isReceived ? l10n.friendsNoReceived : l10n.friendsNoSent,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onRequestsRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) {
          final r = items[i];
          // No-fallback (2026-08-14): every request row must resolve its
          // user's name in the provider — a missing entry is a bug, not a
          // placeholder to render.
          final name = names[r['user_id'] as String]!;
          final id = r['friendship_id'] as String;
          return VGlassCard(
            gradient: AppGradients.mint,
            glowAlpha: 0.10,
            child: ListTile(
              title: Text(name),
              subtitle: Text(
                isReceived ? l10n.friendsSentYouRequest : l10n.friendsRequestSent,
              ),
              trailing: isReceived
                  ? _ActionPair(
                      busy: _processing.contains(id),
                      onAccept: () => _acceptFriend(id),
                      onDecline: () => _declineFriend(id),
                    )
                  : _BusyButton(
                      busy: _processing.contains(id),
                      onPressed: () => _declineFriend(id),
                      label: l10n.commonCancel,
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInvites(List<Map<String, dynamic>> invites) {
    final l10n = AppLocalizations.of(context);
    Future<void> onInvitesRefresh() =>
        ref.read(groupInvitesProvider.notifier).refresh();
    if (invites.isEmpty) {
      return VRefreshable(
        onRefresh: onInvitesRefresh,
        child: VEmptyView(
          icon: Icons.group_outlined,
          title: l10n.friendsNoInvites,
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: onInvitesRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        itemCount: invites.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
        itemBuilder: (_, i) {
          final invite = invites[i];
          final id = invite['id'] as String;
          final groupName =
              (invite['groups'] as Map<String, dynamic>?)?['name']
                      as String? ??
                  l10n.commonGroup;
          return VGlassCard(
            gradient: AppGradients.mint,
            glowAlpha: 0.10,
            child: ListTile(
              title: Text(groupName),
              subtitle: Text(invite['role'] as String? ?? 'member'),
              trailing: _ActionPair(
                busy: _processing.contains(id),
                onAccept: () => _acceptInvite(id),
                onDecline: () => _declineInvite(id),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Requests tab label with the R12 (F5) pending-count badge — the badge
/// renders only when [count] > 0 (VCountBadge shrinks to nothing at 0). The
/// badge takes the screen's mint family (LUXE: count = pending accent).
class _TabLabel extends StatelessWidget {
  final String text;
  final int count;

  const _TabLabel({required this.text, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(text),
        if (count > 0) ...[
          const SizedBox(width: 4),
          VCountBadge(count: count, gradient: AppGradients.mint),
        ],
      ],
    );
  }
}

/// Accept/decline action pair (PERF-08: the repeated trailing action row of
/// the requests and invites lists is one const sub-widget).
///
/// LUXE v2: the accept action is the row's active mint accent — a compact
/// `VButton.emphasized` carrying the mint gradient face (black label on the
/// pastel-first fill); decline stays the theme `TextButton` (white label).
/// R11 (F4): when [busy], the pair collapses into a single 16px white
/// spinner (N3: never accent-colored) while the tapped row's request is in
/// flight — every other row keeps its buttons.
class _ActionPair extends StatelessWidget {
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool busy;

  const _ActionPair({
    required this.onAccept,
    required this.onDecline,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (busy) return const _RowSpinner();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 88,
          child: VButton.emphasized(
            label: l10n.commonAccept,
            gradient: AppGradients.mint,
            onPressed: onAccept,
          ),
        ),
        TextButton(onPressed: onDecline, child: Text(l10n.commonReject)),
      ],
    );
  }
}

/// Single action button with the same in-flight spinner swap (the sent-tab
/// cancel row, R11).
class _BusyButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  final bool busy;

  const _BusyButton({
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    if (busy) return const _RowSpinner();
    return TextButton(onPressed: onPressed, child: Text(label));
  }
}

/// The R11 per-row busy spinner: 16px white `CircularProgressIndicator`
/// (16-20px per the report; the U-04 progressIndicatorTheme is white).
/// ANIM-OFF (2026-08-14): renders as a static ring under reduced motion.
class _RowSpinner extends StatelessWidget {
  const _RowSpinner();

  @override
  Widget build(BuildContext context) {
    return const VSpinner(size: 16);
  }
}
