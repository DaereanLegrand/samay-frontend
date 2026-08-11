import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/groups/widgets/member_actions_sheet.dart';
import 'package:samay/features/profile/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/rank_badge.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_network_image.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  /// U-19 (§7.3): the minimum area the TabBarView keeps when the hero header
  /// is taller than the body at large text scales (~two member rows). The
  /// header's scroll view caps itself at `bodyHeight - _minTabArea`, so the
  /// tabs are never squeezed to nothing.
  static const double _minTabArea = 120;

  late TabController _tabController;

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

  void _invalidateData() {
    ref.invalidate(groupDetailProvider(widget.groupId));
    ref.invalidate(groupMembersProvider(widget.groupId));
    ref.invalidate(contributionsProvider(widget.groupId));
  }

  Widget _scaffold(Widget body) {
    return Scaffold(appBar: AppBar(), body: body);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final contributionsAsync = ref.watch(contributionsProvider(widget.groupId));

    return groupAsync.when(
      // U-24 (§5.8): the detail is the heaviest screen in the feature (three
      // stacked fetches — group, members, contributions), so the nothing-on-
      // screen frame shows the cover+lines skeleton (U-22's handoff named
      // group_detail) instead of the bare spinner. `VSkeletonDetail(rows: 1)`
      // is the closest existing skeleton to the hero geometry (cover block +
      // title/meta lines).
      loading: () => _scaffold(const VSkeletonDetail(rows: 1)),
      error: (e, _) => _scaffold(
        ErrorView(
          message: e.toAppError().message,
          onRetry: () => ref.invalidate(groupDetailProvider(widget.groupId)),
        ),
      ),
      data: (group) {
        if (group == null) {
          return _scaffold(
            ErrorView(
              message: l10n.groupsNotFound,
              onRetry: () =>
                  ref.invalidate(groupDetailProvider(widget.groupId)),
            ),
          );
        }
        return membersAsync.when(
          loading: () => _scaffold(const VSkeletonDetail(rows: 1)),
          error: (e, _) => _scaffold(
            ErrorView(
              message: e.toAppError().message,
              onRetry: () =>
                  ref.invalidate(groupMembersProvider(widget.groupId)),
            ),
          ),
          data: (members) => contributionsAsync.when(
            loading: () => _scaffold(const VSkeletonDetail(rows: 1)),
            error: (e, _) => _scaffold(
              ErrorView(
                message: e.toAppError().message,
                onRetry: () =>
                    ref.invalidate(contributionsProvider(widget.groupId)),
              ),
            ),
            data: (contributions) =>
                _buildDetail(group, members, contributions),
          ),
        );
      },
    );
  }

  Widget _buildDetail(
    Map<String, dynamic> g,
    List<Map<String, dynamic>> members,
    GroupContributionsData contributions,
  ) {
    final l10n = AppLocalizations.of(context);
    final memberLimit = int.tryParse(_getMemberLimit(members)) ?? 0;
    final isFrozen = g['frozen_at'] != null;

    return Scaffold(
      appBar: AppBar(
        // §3.2: the group name is the detail-hero fancy title (Playfair
        // Display italic 28 + glow-soft baked into the theme role, U-02).
        title: Text(
          g['name'] as String? ?? l10n.commonGroup,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.groupsTabChat),
            Tab(text: l10n.groupsTabMembers),
            Tab(text: l10n.groupsTabEvents),
          ],
        ),
        actions: [
          // R16: the overflow menu now only exists for the frozen marker —
          // the leave action moved to the inline danger row below (Juega's
          // inline leave with a confirm dialog, Samay-shaped).
          if (isFrozen)
            PopupMenuButton<String>(
              // U-26 (4.1.2): the menu is icon-only — the tooltip is its
              // accessibility name for screen readers.
              tooltip: l10n.commonMoreOptions,
              onSelected: (v) => _handleAction(v),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'frozen',
                  enabled: false,
                  child: Text(l10n.groupsFrozenBadge),
                ),
              ],
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            if (isFrozen)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                // §5.2: never raw red on black — the frozen banner is an
                // error *fill* (glowPinkDeep); white text on it is 5.87:1
                // (AA).
                color: AppColors.errorFill,
                child: Text(
                  l10n.groupsFrozenBanner,
                  style: const TextStyle(fontSize: 12, color: AppColors.white),
                  textAlign: TextAlign.center,
                ),
              ),
            // U-19 (§7.3): the hero header scrolls internally when it would
            // otherwise crush the tabs — it may take at most the body height
            // minus a minimum tab area (`_minTabArea` ≈ two member rows), so
            // the TabBarView is never squeezed to nothing at large text
            // scales. When the header fits (the normal case), this renders
            // exactly like the pre-U-19 layout (natural height, no scroll).
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (constraints.maxHeight - _minTabArea).clamp(
                  0.0,
                  double.infinity,
                ),
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (g['cover_url'] != null)
                        VNetworkImage(
                          imageUrl: g['cover_url'] as String,
                          height: 120,
                          fit: BoxFit.cover,
                        ),
                      if (g['description'] != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          g['description'] as String,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 12),
                      // U-19: `Wrap` instead of a `Row` — the tier badge +
                      // rank badge overflowed 320px-wide screens at 1.5×
                      // (§7.3: the badges flow to a second line instead of
                      // clipping).
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (g['size_tier'] != null)
                            VBadge(label: g['size_tier'] as String),
                          if (g['rank_bracket'] != null)
                            RankBadge(bracket: g['rank_bracket'] as String),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const VShardIcon(),
                          const SizedBox(width: 8),
                          // U-19: `Flexible` — "42 shards de grupo" at 1.5×
                          // wraps instead of overflowing the Row (§7.3).
                          Flexible(
                            child: Text(
                              l10n.groupsShardsCount(
                                (g['group_shards'] as num?)?.toInt() ?? 0,
                              ),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.groupsMemberCount(members.length, memberLimit),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      // R16 (F8 ADAPTED): the leave trigger is an inline
                      // danger row beside the member count (Juega's inline
                      // leave; the confirm dialog stays Samay-shaped). Error
                      // semantic per §5.2 — glowPink 6.00:1 AA, never raw
                      // red.
                      TextButton.icon(
                        onPressed: _leaveGroup,
                        icon: const Icon(Icons.logout, size: 18),
                        label: Text(l10n.groupsLeave),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.error,
                        ),
                      ),
                      if (contributions.myContribution > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          l10n.groupsMyContribution(
                            contributions.myContribution,
                          ),
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          // §5.1: the donate CTA is the detail screen's one
                          // brand moment (glowAccent filled — pink fill,
                          // black text 6.00:1); the secondary actions stay
                          // outlined white.
                          Expanded(
                            child: VButton.glowAccent(
                              filled: true,
                              label: l10n.groupsDonateTitle,
                              onPressed: () async {
                                await context.push(
                                  RoutePaths.donateToGroup(widget.groupId),
                                );
                                _invalidateData();
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: VButton(
                              label: l10n.groupsCreateEvent,
                              onPressed: () => context.push(
                                RoutePaths.createGroupEvent(widget.groupId),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: VButton(
                              label: l10n.commonInvite,
                              onPressed: () => context.push(
                                RoutePaths.inviteToGroup(widget.groupId),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildChatTab(),
                  _buildMembersTab(members, contributions.contributors),
                  _buildEventsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    final l10n = AppLocalizations.of(context);
    return _scrollableTabBody(
      VEmptyView(
        icon: Icons.chat_bubble_outline,
        title: l10n.groupsChatComingSoon,
      ),
    );
  }

  Widget _buildMembersTab(
    List<Map<String, dynamic>> members,
    List<Map<String, dynamic>> contributors,
  ) {
    final l10n = AppLocalizations.of(context);
    if (members.isEmpty) {
      return _scrollableTabBody(
        VEmptyView(icon: Icons.people_outline, title: l10n.groupsNoMembers),
      );
    }
    // R17 (F9 ADAPTED): the members tab rows are admin-gated like the
    // standalone members screen — the current user's role comes from their
    // own membership row.
    final myId = ref.read(authServiceProvider).auth.currentUser?.id;
    final myRole = myId == null
        ? 'member'
        : members.where((m) => m['user_id'] == myId).firstOrNull?['role']
                  as String? ??
              'member';
    final isAdmin = myRole == 'promotor' || myRole == 'co_promotor';
    // Descriptor rows: only row *data* is materialized here; widgets are
    // created lazily per visible row by the builder (PERF-01).
    final rows = <_MembersRow>[
      _RowHeader(l10n.groupsTopContributors),
      const _RowSpacer(8),
      ...contributors
          .take(5)
          .map(
            (c) => _RowContributor(
              username:
                  c['users']?['username'] ?? '${c['user_id']}'.substring(0, 8),
              shards: l10n.groupsShardsCountShort(
                (c['shards_contributed'] as num?)?.toInt() ?? 0,
              ),
            ),
          ),
      const _RowSpacer(24),
      _RowHeader(l10n.groupsMembersCount(members.length)),
      const _RowSpacer(8),
      ...members.map((m) {
        final user = m['users'] as Map<String, dynamic>?;
        final role = m['role'] as String? ?? 'member';
        return _RowMember(
          userId: m['user_id'] as String,
          username:
              user?['username'] as String? ?? '${m['user_id']}'.substring(0, 8),
          role: role,
          canAct: isAdmin && m['user_id'] != myId && role != 'promotor',
        );
      }),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (_, i) => switch (rows[i]) {
        _RowHeader(:final text) => Text(
          text,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        _RowSpacer(:final height) => SizedBox(height: height),
        _RowContributor(:final username, :final shards) => _ContributorTile(
          username: username,
          shards: shards,
        ),
        _RowMember(
          :final userId,
          :final username,
          :final role,
          :final canAct,
        ) =>
          _MemberTile(
            username: username,
            role: role,
            onTap: canAct
                ? () => showMemberActionsSheet(
                    context,
                    ref: ref,
                    groupId: widget.groupId,
                    member: {
                      'user_id': userId,
                      'role': role,
                      'users': {'username': username},
                    },
                    onChanged: _invalidateData,
                  )
                : null,
          ),
      },
    );
  }

  Widget _buildEventsTab() {
    final l10n = AppLocalizations.of(context);
    return _scrollableTabBody(
      VEmptyView(
        icon: Icons.event_outlined,
        title: l10n.groupsEventsComingSoon,
      ),
    );
  }

  /// U-19 (§7.3): the tab area keeps a 120px minimum (`_minTabArea`) when the
  /// hero header is tall at large text scales — wrap the §5.9 empty states so
  /// they scroll instead of overflowing the squeezed viewport.
  Widget _scrollableTabBody(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: child,
        ),
      ),
    );
  }

  String _getMemberLimit(List<Map<String, dynamic>> members) {
    if (members.isEmpty) return '0';
    return '14';
  }

  void _handleAction(String value) {
    // R16: the menu only carries the (disabled) frozen marker; the leave
    // action lives in the inline row — nothing else is dispatched.
    switch (value) {
      case 'frozen':
        break;
    }
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

/// Descriptor for one row of the members tab. Only data is stored here; the
/// [ListView.builder] creates the widget lazily per visible row (PERF-01).
sealed class _MembersRow {
  const _MembersRow();
}

final class _RowHeader extends _MembersRow {
  const _RowHeader(this.text);
  final String text;
}

final class _RowSpacer extends _MembersRow {
  const _RowSpacer(this.height);
  final double height;
}

final class _RowContributor extends _MembersRow {
  const _RowContributor({required this.username, required this.shards});
  final String username;
  final String shards;
}

final class _RowMember extends _MembersRow {
  const _RowMember({
    required this.userId,
    required this.username,
    required this.role,
    required this.canAct,
  });

  final String userId;
  final String username;
  final String role;

  /// R17: the current user is an admin and this row is an actionable target.
  final bool canAct;
}

/// Dense contributor row (PERF-08: the repeated ListTile+avatar shape is a
/// const sub-widget so unchanged rows skip rebuilds; U-11 restyle: shared
/// `ProfileAvatar` + hairline close).
class _ContributorTile extends StatelessWidget {
  final String username;
  final String shards;

  const _ContributorTile({required this.username, required this.shards});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          leading: ProfileAvatar(
            size: AppSpacing.avatar,
            // U-26 (U-24 F3 family): an empty (non-null) username would
            // RangeError on substring — the '?' initial fallback.
            initials: username.isEmpty
                ? '?'
                : username.substring(0, 1).toUpperCase(),
          ),
          title: Text(username),
          trailing: Text(shards),
        ),
        const Divider(height: 1),
      ],
    );
  }
}

/// Dense member row (PERF-08: same shape as [_ContributorTile] but with the
/// role rendered as a §5.5 `VBadge` beside the name; R17: admin rows gain
/// the actions affordance).
class _MemberTile extends StatelessWidget {
  final String username;
  final String role;
  final VoidCallback? onTap;

  const _MemberTile({required this.username, required this.role, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          leading: ProfileAvatar(
            size: AppSpacing.avatar,
            // U-26 (U-24 F3 family): an empty (non-null) username would
            // RangeError on substring — the '?' initial fallback.
            initials: username.isEmpty
                ? '?'
                : username.substring(0, 1).toUpperCase(),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  username,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              VBadge(label: role),
            ],
          ),
          trailing: onTap != null
              ? const Icon(Icons.more_horiz, size: 20)
              : null,
          onTap: onTap,
        ),
        const Divider(height: 1),
      ],
    );
  }
}
