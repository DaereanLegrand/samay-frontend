import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/models/group.dart';
import 'package:samay/core/models/group_member.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/chat/providers/chat_providers.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/groups/widgets/group_events_section.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/full_screen_image.dart';
import 'package:samay/shared/widgets/rank_badge.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_network_image.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

/// Group detail — ONE scroll (2026-09-15 restructure): the Info | Chat |
/// Miembros | Eventos tab bar is gone. The screen shows the group identity,
/// a 2×2 sharp action grid (Chat · Donar · Miembros · Crear partida) and the
/// inline events section; invite/create-event/leave live in the header's
/// three-dot menu. Chat always opens the shared [ChatScreen] (the same chat
/// screen the feed flow uses) — never an embedded thread.
class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> {
  /// One-shot guard: the screen-open refresh runs once per mount in
  /// [didChangeDependencies] (ref.invalidate is illegal in initState).
  bool _refreshedOnOpen = false;

  /// Height of the full-bleed hero banner (the cover region; the pinned bar
  /// lays the status-bar inset on top).
  static const double _kBannerHeight = 260;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_refreshedOnOpen) return;
    _refreshedOnOpen = true;
    _refreshOnOpen();
  }

  /// Invalidates every detail-scoped provider on mount so a member who
  /// joined/accepted on another device appears on open.
  void _refreshOnOpen() {
    ref.invalidate(groupDetailCombinedProvider(widget.groupId));
  }

  void _invalidateData() {
    ref.invalidate(groupDetailCombinedProvider(widget.groupId));
  }

  Widget _scaffold(Widget body, {String? title, List<Widget>? actions}) {
    return Scaffold(
      body: VHeaderBar(title: title, actions: actions, child: body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final detailAsync = ref.watch(groupDetailCombinedProvider(widget.groupId));

    return detailAsync.when(
      loading: () => _scaffold(const VSkeletonDetail(rows: 1)),
      error: (e, _) => _scaffold(
        ErrorView(
          message: e.toAppError().message,
          onRetry: () =>
              ref.invalidate(groupDetailCombinedProvider(widget.groupId)),
        ),
      ),
      data: (data) {
        if (data.group == null) {
          return _scaffold(
            ErrorView(
              message: l10n.groupsNotFound,
              onRetry: () =>
                  ref.invalidate(groupDetailCombinedProvider(widget.groupId)),
            ),
          );
        }
        // ISSUE 2: an invited user has not joined — a single Aceptar/Rechazar
        // panel, nothing else. A missing membership row (null) is active.
        if (data.membership?['status'] == 'invited') {
          return _buildInvitedPanel(data.group!, data.membership!);
        }
        return _buildDetail(data.group!, data.members, data.contributions);
      },
    );
  }

  /// ISSUE 2: the invited (pending) state — explanation + Aceptar/Rechazar.
  Widget _buildInvitedPanel(Group g, Map<String, dynamic> membership) {
    final l10n = AppLocalizations.of(context);
    final membershipId = membership['id'] as String;
    return _scaffold(
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.groupsInvitePendingBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              VButton.dark(
                label: l10n.commonAccept,
                onPressed: () => _acceptInvite(membershipId),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => _declineInvite(membershipId),
                child: Text(l10n.commonReject),
              ),
            ],
          ),
        ),
      ),
      title: g.name,
    );
  }

  Future<void> _acceptInvite(String membershipId) async {
    await ref.read(groupsRepositoryProvider).acceptInvite(membershipId);
    _invalidateData();
    ref.invalidate(groupInvitesProvider);
    ref.invalidate(myGroupsProvider);
  }

  Future<void> _declineInvite(String membershipId) async {
    await ref.read(groupsRepositoryProvider).declineInvite(membershipId);
    if (!mounted) return;
    context.pop();
  }

  Widget _buildDetail(
    Group g,
    List<GroupMember> members,
    GroupContributionsData contributions,
  ) {
    final l10n = AppLocalizations.of(context);
    final isFrozen = g.frozenAt != null;

    // Modern hero (user directive 2026-09-15): the cover is full-bleed from
    // the very top of the viewport (under the status bar) with a transparent
    // header overlay. The banner is a NORMAL sliver (not the app bar's
    // flexibleSpace) so it stays reliably tappable.
    final statusBar = MediaQuery.paddingOf(context).top;
    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: statusBar + _kBannerHeight,
                  child: _banner(l10n, g, members),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isFrozen) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(AppSpacing.sm),
                          color: AppColors.errorFill,
                          child: Text(
                            l10n.groupsFrozenBanner,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (g.description != null &&
                          g.description!.isNotEmpty) ...[
                        Text(
                          g.description!,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (contributions.myContribution > 0) ...[
                        Text(
                          l10n.groupsMyContribution(
                            contributions.myContribution,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _actionRow(l10n),
                      const SizedBox(height: AppSpacing.lg),
                      GroupEventsSection(groupId: widget.groupId),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Transparent header overlay (back + three-dot menu) over the banner.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: kToolbarHeight,
                child: Row(
                  children: [
                    const BackButton(color: AppColors.white),
                    const Spacer(),
                    _menu(l10n),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// The full-bleed banner: cover image (or a flat surface when absent), a
  /// legibility scrim, and the shards + members rows with the rank letter
  /// right-aligned and vertically centered against them.
  Widget _banner(AppLocalizations l10n, Group g, List<GroupMember> members) {
    final hasCover = g.coverUrl != null && g.coverUrl!.isNotEmpty;
    final content = Stack(
      fit: StackFit.expand,
      children: [
        if (hasCover)
          VNetworkImage(imageUrl: g.coverUrl!, fit: BoxFit.cover)
        else
          const ColoredBox(color: AppColors.surfaceAlt),
        const DecoratedBox(
          decoration: BoxDecoration(
            // Clean for the top 65%, then a single ramp to full black at the
            // bottom where the shards/members/rank sit (user directive
            // 2026-09-15: stronger, bottom only).
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.transparent, Color(0xFF000000)],
              stops: [0, 0.65, 1],
            ),
          ),
        ),
        Positioned(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: AppSpacing.lg,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const VShardIcon(color: AppColors.discoViolet),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            l10n.groupsShardsCountShort(g.groupShards),
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      l10n.groupsMembersCountShort(members.length),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (g.rankBracket != null) ...[
                const SizedBox(width: AppSpacing.md),
                RankBadge(bracket: g.rankBracket!),
              ],
            ],
          ),
        ),
      ],
    );
    if (!hasCover) return content;
    // Tap the banner to pop the shared zoomable full-screen viewer. `opaque`
    // keeps the whole area tappable even while the image loads / on error.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => showFullScreenImage(context, url: g.coverUrl!),
      child: content,
    );
  }

  /// The header three-dot menu: Invitar · Crear evento · Abandonar.
  Widget _menu(AppLocalizations l10n) {
    return PopupMenuButton<String>(
      tooltip: l10n.commonMoreOptions,
      iconColor: AppColors.white,
      onSelected: _onMenu,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'invite', child: Text(l10n.commonInvite)),
        PopupMenuItem(value: 'create_event', child: Text(l10n.groupsCreateEvent)),
        PopupMenuItem(value: 'leave', child: Text(l10n.groupsAbandon)),
      ],
    );
  }

  void _onMenu(String value) {
    switch (value) {
      case 'invite':
        context.push(RoutePaths.inviteToGroup(widget.groupId));
      case 'create_event':
        context.push(RoutePaths.createGroupEvent(widget.groupId));
      case 'leave':
        _leaveGroup();
    }
  }

  /// Minimal icon-only action row: Chat · Donar · Miembros · Crear partida.
  Widget _actionRow(AppLocalizations l10n) {
    final showGames = ref.isEnabled(AppFeatureFlag.minigames);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionIcon(
          icon: Icons.chat_bubble_outline,
          tooltip: l10n.chatTitle,
          onTap: _openChat,
        ),
        _ActionIcon(
          icon: Icons.volunteer_activism_outlined,
          tooltip: l10n.groupsDonateTitle,
          onTap: () async {
            await context.push(RoutePaths.donateToGroup(widget.groupId));
            _invalidateData();
          },
        ),
        _ActionIcon(
          icon: Icons.people_outline,
          tooltip: l10n.groupsTabMembers,
          onTap: () => context.push(RoutePaths.groupMembers(widget.groupId)),
        ),
        if (showGames)
          _ActionIcon(
            icon: Icons.sports_esports_outlined,
            tooltip: l10n.minigamesNewPartida,
            onTap: () => context.push(RoutePaths.minigames(widget.groupId)),
          ),
      ],
    );
  }

  /// Opens the group's chat in the shared [ChatScreen] (the feed flow's chat
  /// screen). The inbox is refreshed so the screen resolves the group name +
  /// `referenceId` (sender labels).
  Future<void> _openChat() async {
    final chatId = await ref.read(groupChatIdProvider(widget.groupId).future);
    if (!mounted || chatId == null) return;
    ref.invalidate(chatInboxProvider);
    context.push(RoutePaths.chat(chatId));
  }

  Future<void> _leaveGroup() async {
    final l10n = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l10n.groupsLeave),
        content: Text(l10n.groupsConfirmLeave),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.groupsAbandon),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(groupsRepositoryProvider).leaveGroup(widget.groupId);
      if (mounted) context.pop();
    }
  }
}

/// A minimal icon-only action (user directive 2026-09-15: no labels, no
/// bordered tiles — just the glyph on the black canvas).
class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: 26, color: AppColors.white),
    );
  }
}
