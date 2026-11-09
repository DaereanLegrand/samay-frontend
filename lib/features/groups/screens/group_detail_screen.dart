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
import 'package:samay/core/theme/app_palette.dart';
import 'package:samay/core/theme/app_theme_provider.dart';
import 'package:samay/features/groups/theme/group_theme_theme.dart';
import 'package:samay/features/groups/widgets/donate_shards_dialog.dart';
import 'package:samay/features/groups/widgets/group_events_section.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/full_screen_image.dart';
import 'package:samay/shared/widgets/rank_badge.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/report_sheet.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_network_image.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Group detail: a full-bleed cover banner with the group name and menu in a
/// transparent header, a flat identity strip (shards / members / rank), the
/// group description and an action row (Chat · Donar · Miembros · Crear
/// partida), then the inline events section. Invite/create-event/leave live in
/// the header menu. Chat opens the shared [ChatScreen].
///
/// The whole screen is part of the group surface: it paints the host's derived
/// theme (page, banner strip, inks) exactly like chat, the member list and the
/// group minigames do.
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
    // The detail IS a group surface: loading/error/invited/detail all paint the
    // host's derived theme (a null palette while the theme loads renders the
    // standard tokens unchanged).
    final theme = ref.watch(groupThemeProvider(widget.groupId)).valueOrNull;
    final palette = theme == null
        ? null
        : groupSurfacePalette(theme, appPalette: ref.watch(appPaletteProvider));

    final body = detailAsync.when(
      loading: () => _scaffold(const VLoadingView()),
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
        // An invited user has not joined — a single Aceptar/Rechazar
        // panel, nothing else. A missing membership row (null) is active.
        if (data.membership?['status'] == 'invited') {
          return _buildInvitedPanel(data.group!, data.membership!, palette);
        }
        return _buildDetail(
          data.group!,
          data.members,
          data.contributions,
          palette,
        );
      },
    );
    return GroupThemeSurface(palette: palette, child: body);
  }

  /// The invited (pending) state — explanation + Aceptar/Rechazar.
  Widget _buildInvitedPanel(
    Group g,
    Map<String, dynamic> membership,
    AppPalette? palette,
  ) {
    final l10n = AppLocalizations.of(context);
    final membershipId = membership['id'] as String;
    return _scaffold(
      Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.groupsInvitePendingBody,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: palette?.foreground ?? context.palette.foreground,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              VButton.dark(
                label: l10n.commonAccept,
                onPressed: () => _acceptInvite(membershipId),
              ),
              const SizedBox(height: AppSpacing.sm),
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
    AppPalette? palette,
  ) {
    final l10n = AppLocalizations.of(context);
    final isFrozen = g.frozenAt != null;

    // The cover is full-bleed from the very top of the viewport (under the
    // status bar) with a transparent header overlay. The banner is a NORMAL
    // sliver (not the app bar's flexibleSpace) so it stays reliably tappable.
    final statusBar = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: palette?.background,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: statusBar + _kBannerHeight,
                  child: _banner(l10n, g, members, palette),
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
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.palette.foreground),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (g.description != null &&
                          g.description!.isNotEmpty) ...[
                        Text(
                          g.description!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color:
                                    palette?.foreground ?? context.palette.foreground,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      if (contributions.myContribution > 0) ...[
                        Text(
                          l10n.groupsMyContribution(
                            contributions.myContribution,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: palette?.mutedForeground ??
                                    context.palette.mutedForeground,
                              ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                      _actionRow(l10n, g, palette),
                      const SizedBox(height: AppSpacing.lg),
                      GroupEventsSection(groupId: widget.groupId),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Transparent header overlay (back + title + menu) over the banner.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                // SafeArea contributes nothing where the platform reports no
                // status inset (the web build, and Android in some
                // full-screen modes), so this overlay sat flush against the
                // top edge and the group name's ascenders were sliced off.
                // The same gap every other header reserves keeps the title
                // whole.
                padding: EdgeInsets.fromLTRB(
                  VHeaderMetrics.titleInset.left,
                  VHeaderMetrics.heroTopPad(MediaQuery.paddingOf(context).top),
                  VHeaderMetrics.titleInset.right,
                  0,
                ),
                child: VHeaderTitleRow(
                  title: g.name,
                  actions: [_menu(l10n, g)],
                  pillProgress: 1,
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
  Widget _banner(
    AppLocalizations l10n,
    Group g,
    List<GroupMember> members,
    AppPalette? palette,
  ) {
    final hasCover = g.coverUrl != null && g.coverUrl!.isNotEmpty;
    final strip = palette?.surface ?? context.palette.background;
    final primaryInk = palette?.foreground ?? context.palette.foreground;
    final secondaryInk = palette?.mutedForeground ?? context.palette.mutedForeground;
    final content = Stack(
      fit: StackFit.expand,
      children: [
        if (hasCover)
          VNetworkImage(imageUrl: g.coverUrl!, fit: BoxFit.cover)
        else
          ColoredBox(color: palette?.background ?? context.palette.background),
        // Flat identity strip at the banner floor (no gradient): it keeps the
        // shards/members/rank legible over any cover and now carries the
        // group's themed surface instead of a black box.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            color: strip,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          VShardIcon(color: primaryInk),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              l10n.groupsShardsCountShort(g.groupShards),
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(color: primaryInk),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.groupsMembersCountShort(members.length),
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: secondaryInk),
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
  Widget _menu(AppLocalizations l10n, Group g) {
    return PopupMenuButton<String>(
      tooltip: l10n.commonMoreOptions,
      onSelected: _onMenu,
      itemBuilder: (_) => [
        PopupMenuItem(value: 'invite', child: Text(l10n.commonInvite)),
        PopupMenuItem(
          value: 'theme',
          child: Text(l10n.groupThemeTitle),
        ),
        PopupMenuItem(
          value: 'create_event',
          child: Text(l10n.groupsCreateEvent),
        ),
        if (g.coverUrl != null && g.coverUrl!.isNotEmpty)
          PopupMenuItem(
            value: 'report_cover',
            child: Text(l10n.reportGroupCover),
          ),
        PopupMenuItem(value: 'leave', child: Text(l10n.groupsAbandon)),
      ],
    );
  }

  void _onMenu(String value) {
    switch (value) {
      case 'invite':
        context.push(RoutePaths.inviteToGroup(widget.groupId));
      case 'theme':
        context.push(RoutePaths.groupTheme(widget.groupId));
      case 'create_event':
        context.push(RoutePaths.createGroupEvent(widget.groupId));
      case 'report_cover':
        showReportSheet(
          context,
          ref,
          targetType: 'group_cover',
          targetId: widget.groupId,
          title: AppLocalizations.of(context).reportGroupCover,
        );
      case 'leave':
        _leaveGroup();
    }
  }

  /// The group action row: Chat · Donar · Miembros · Crear partida, each an
  /// icon over its label. The top pad keeps it clear of the description.
  Widget _actionRow(
    AppLocalizations l10n,
    Group g,
    AppPalette? palette,
  ) {
    final showGames = ref.isEnabled(AppFeatureFlag.minigames);
    final iconInk = palette?.foreground ?? context.palette.foreground;
    final labelInk = palette?.mutedForeground ?? context.palette.mutedForeground;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ActionIcon(
            icon: Icons.chat_bubble_outline,
            label: l10n.chatTitle,
            ink: iconInk,
            labelInk: labelInk,
            onTap: _openChat,
          ),
          _ActionIcon(
            icon: Icons.volunteer_activism_outlined,
            label: l10n.groupsDonateTitle,
            ink: iconInk,
            labelInk: labelInk,
            onTap: () async {
              await showDonateToGroupDialog(
                context,
                groupId: widget.groupId,
                groupName: g.name,
                palette: palette,
              );
              _invalidateData();
            },
          ),
          _ActionIcon(
            icon: Icons.people_outline,
            label: l10n.groupsTabMembers,
            ink: iconInk,
            labelInk: labelInk,
            onTap: () => context.push(RoutePaths.groupMembers(widget.groupId)),
          ),
          if (showGames)
            _ActionIcon(
              icon: Icons.sports_esports_outlined,
              label: l10n.minigamesNewPartida,
              ink: iconInk,
              labelInk: labelInk,
              onTap: () => context.push(RoutePaths.minigames(widget.groupId)),
            ),
        ],
      ),
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

/// One action: the glyph over its label, inside a 44pt-minimum tap target.
class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.ink,
    required this.labelInk,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color ink;
  final Color labelInk;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: ink),
            const SizedBox(height: AppSpacing.xs),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: labelInk),
            ),
          ],
        ),
      ),
    );
  }
}
