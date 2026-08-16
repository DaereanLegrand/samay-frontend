import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/chat/widgets/chat_thread_view.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/groups/widgets/group_events_tab.dart';
import 'package:samay/features/groups/widgets/member_actions_sheet.dart';
import 'package:samay/features/profile/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/rank_badge.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_aurora.dart';
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
  /// U-19 (§7.3): the minimum area the tab bodies keep at large text scales.
  /// The hero header is gone (USER FIX 4), so the constant now floors the
  /// scrollable tab bodies directly instead of capping a header.
  static const double _minTabArea = 120;

  late TabController _tabController;

  /// One-shot guard: the screen-open refresh runs once per mount in
  /// [didChangeDependencies] (ref.invalidate is illegal in initState —
  /// the element's inherited-widget access is not ready yet).
  bool _refreshedOnOpen = false;

  @override
  void initState() {
    super.initState();
    // ISSUE 3: Info | Chat | Miembros | Eventos — group info is its own tab.
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_refreshedOnOpen) return;
    _refreshedOnOpen = true;
    // Screen-open freshness (2026-08-17 user report: the iPhone member list
    // was STUCK at 4 members): the detail providers are keep-alive family
    // providers, so a re-opened screen serves the STALE cached state
    // forever — the realtime listener (GroupMembershipsRealtimeListener,
    // shell-mounted) only refreshes while the shell is alive AND the channel
    // delivered the event (missed events never replay; older builds lack
    // the listener entirely). Every mount invalidates, so a member who
    // joined/accepted on another device appears on open — no pull, no
    // restart, no realtime dependency.
    _refreshOnOpen();
  }

  /// Invalidates every detail-scoped provider on mount (see
  /// [didChangeDependencies]).
  void _refreshOnOpen() {
    ref.invalidate(groupDetailProvider(widget.groupId));
    ref.invalidate(groupMembersProvider(widget.groupId));
    ref.invalidate(contributionsProvider(widget.groupId));
    ref.invalidate(myMembershipProvider(widget.groupId));
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

  /// USER FIX 4: the loading/error/invited frames share the same scaffold —
  /// [title] renders the group name next to the back arrow (the only place a
  /// group name may appear).
  Widget _scaffold(Widget body, {String? title}) {
    return Scaffold(
      appBar: AppBar(
        title: title == null
            ? null
            : Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: VAurora(gradients: const [AppGradients.violet], child: body),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final contributionsAsync = ref.watch(contributionsProvider(widget.groupId));
    final membershipAsync = ref.watch(myMembershipProvider(widget.groupId));

    return groupAsync.when(
      // U-24 (§5.8): the detail is the heaviest screen in the feature (three
      // stacked fetches — group, members, contributions), so the nothing-on-
      // screen frame shows the cover+lines skeleton (U-22's handoff named
      // group_detail) instead of the bare spinner. `VSkeletonDetail(rows: 1)`
      // mirrors the cover+title/meta shape of the loaded Info tab.
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
            data: (contributions) => membershipAsync.when(
              loading: () => _scaffold(const VSkeletonDetail(rows: 1)),
              error: (e, _) => _scaffold(
                ErrorView(
                  message: e.toAppError().message,
                  onRetry: () =>
                      ref.invalidate(myMembershipProvider(widget.groupId)),
                ),
              ),
              data: (membership) {
                // ISSUE 2: an invited user has not joined the group — a
                // single Aceptar/Rechazar panel, nothing else. A missing
                // membership row (null) falls through to the active state.
                if (membership?['status'] == 'invited') {
                  return _buildInvitedPanel(group, membership!);
                }
                return _buildDetail(group, members, contributions);
              },
            ),
          ),
        );
      },
    );
  }

  /// ISSUE 2: the invited (pending) state — the group name (AppBar title
  /// only, USER FIX 4), an explanation and a single Aceptar primary button
  /// plus a Rechazar text button. No tabs, no hero CTAs, no leave: the user
  /// has not joined the group yet.
  Widget _buildInvitedPanel(
    Map<String, dynamic> g,
    Map<String, dynamic> membership,
  ) {
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
              VButton.glowAccent(
                filled: true,
                gradient: AppGradients.violet,
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
      title: g['name'] as String? ?? l10n.commonGroup,
    );
  }

  /// ISSUE 2: accepting a pending invitation flips the membership to active —
  /// every detail-scoped provider reloads so the screen re-renders the normal
  /// state (and the lists drop the pending badge).
  Future<void> _acceptInvite(String membershipId) async {
    await ref.read(groupsRepositoryProvider).acceptInvite(membershipId);
    _invalidateData();
    ref.invalidate(groupInvitesProvider);
    ref.invalidate(myGroupsProvider);
    ref.invalidate(myMembershipProvider(widget.groupId));
  }

  /// ISSUE 2: declining a pending invitation deletes the membership and pops
  /// back to the groups list.
  Future<void> _declineInvite(String membershipId) async {
    await ref.read(groupsRepositoryProvider).declineInvite(membershipId);
    if (!mounted) return;
    context.pop();
  }

  Widget _buildDetail(
    Map<String, dynamic> g,
    List<Map<String, dynamic>> members,
    GroupContributionsData contributions,
  ) {
    final l10n = AppLocalizations.of(context);
    final isFrozen = g['frozen_at'] != null;

    return Scaffold(
      // USER FIX 4: the group name lives ONLY in the AppBar title, next to
      // the back arrow (maxLines 1 + ellipsis) — there is no hero banner
      // above the tabs. The AppBar also owns the tabs and the frozen marker.
      appBar: AppBar(
        title: Text(
          g['name'] as String? ?? l10n.commonGroup,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        // ISSUE 3: group info is its own tab — Info | Chat | Miembros |
        // Eventos.
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.groupsTabInfo),
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
      body: VAurora(
        gradients: const [AppGradients.violet],
        child: Column(
          children: [
            // USER FIX 4: the hero banner block is gone — the TabBarView
            // takes the full body. The frozen errorFill strip stays above it.
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildInfoTab(g, members, contributions),
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

  /// ISSUE 3: the group-information tab — the content that used to live in
  /// the detail hero (description, tier/rank badges, shards, member count,
  /// the leave row, my contribution and the Donar/Crear/Invitar/Juegos CTA
  /// row) now lives here.
  Widget _buildInfoTab(
    Map<String, dynamic> g,
    List<Map<String, dynamic>> members,
    GroupContributionsData contributions,
  ) {
    final l10n = AppLocalizations.of(context);
    final memberLimit = int.tryParse(_getMemberLimit(members)) ?? 0;
    return _scrollableTabBody(
      Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // USER FIX 4: the hero banner is gone — the cover moves here as
            // the Info tab's first block (the name lives in the AppBar only).
            if (g['cover_url'] != null) ...[
              VNetworkImage(
                imageUrl: g['cover_url'] as String,
                height: 120,
                fit: BoxFit.cover,
              ),
              const SizedBox(height: 16),
            ],
            if (g['description'] != null) ...[
              Text(
                g['description'] as String,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 12),
            // U-19: `Wrap` instead of a `Row` — the tier badge + rank badge
            // overflowed 320px-wide screens at 1.5× (§7.3: the badges flow to
            // a second line instead of clipping).
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
                // U-19: `Flexible` — "42 shards de grupo" at 1.5× wraps
                // instead of overflowing the Row (§7.3).
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
            // R16 (F8 ADAPTED): the leave trigger is an inline danger row
            // beside the member count (Juega's inline leave; the confirm
            // dialog stays Samay-shaped). Error semantic per §5.2 — glowPink
            // 6.00:1 AA, never raw red.
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
                l10n.groupsMyContribution(contributions.myContribution),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                // §5.1 LUXE: the donate CTA is the detail screen's one brand
                // moment — the violet glow accent (family gradient fill, black
                // text 6.00:1); the secondary actions stay outlined.
                Expanded(
                  child: VButton.glowAccent(
                    filled: true,
                    gradient: AppGradients.violet,
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
                if (ref.isEnabled(AppFeatureFlag.minigames)) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: VButton(
                      label: l10n.minigamesTitle,
                      onPressed: () => context.push(
                        RoutePaths.minigames(widget.groupId),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab() {
    final l10n = AppLocalizations.of(context);
    // ISSUE 4: the tab hosts the SAME E2EE thread as the 1:1 chat screen
    // (ChatThreadView) — the group's chat row is resolved via
    // groupChatIdProvider, and group mode labels senders on peer bubbles.
    final chatIdAsync = ref.watch(groupChatIdProvider(widget.groupId));
    return chatIdAsync.when(
      loading: () => const VLoadingView(),
      error: (_, _) => ErrorView(
        message: l10n.chatLoadError,
        onRetry: () => ref.invalidate(groupChatIdProvider(widget.groupId)),
      ),
      data: (chatId) {
        if (chatId == null) {
          // The group's chat row does not exist yet — keep the honest
          // placeholder instead of a dead thread.
          return _scrollableTabBody(
            VEmptyView(
              icon: Icons.chat_bubble_outline,
              title: l10n.groupsChatOneToOneTitle,
              description: l10n.groupsChatOneToOneBody,
            ),
          );
        }
        return ChatThreadView(chatId: chatId, groupId: widget.groupId);
      },
    );
  }

  Widget _buildMembersTab(
    List<Map<String, dynamic>> members,
    List<Map<String, dynamic>> contributors,
  ) {
    final l10n = AppLocalizations.of(context);
    if (members.isEmpty) {
      // Pull-to-refresh on the empty state too (the scroll physics keep the
      // gesture alive on short content).
      return RefreshIndicator(
        onRefresh: _refreshMembers,
        child: _scrollableTabBody(
          VEmptyView(icon: Icons.people_outline, title: l10n.groupsNoMembers),
        ),
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
    // Pull-to-refresh (2026-08-17): the ONLY non-realtime path to fresh
    // member data — the shell realtime listener misses events when the
    // channel is down/never replayed, so the gesture refetches members +
    // contributors unconditionally (invalidate, not the throttled
    // refresh()).
    return RefreshIndicator(
      onRefresh: _refreshMembers,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
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
      ),
    );
  }

  /// Pull-to-refresh handler for the Miembros tab: refetches the members
  /// AND contributors providers (the tab renders both). Uses invalidate —
  /// not the ThrottledRefresh'ed refresh() — so the explicit gesture always
  /// hits the server (2026-08-17).
  Future<void> _refreshMembers() async {
    ref.invalidate(groupMembersProvider(widget.groupId));
    ref.invalidate(contributionsProvider(widget.groupId));
    await ref.read(groupMembersProvider(widget.groupId).future);
  }

  Widget _buildEventsTab() {
    // R2: the events tab lists the group's real events (loading/error/empty
    // states included) — no more "Eventos próximamente" placeholder.
    return GroupEventsTab(groupId: widget.groupId);
  }

  /// U-19 (§7.3): the tab bodies keep at least `_minTabArea` of height at
  /// large text scales — wrap the §5.9 empty states so they scroll instead of
  /// overflowing the squeezed viewport. With the hero banner gone (USER FIX
  /// 4), the floor applies directly to the scrollable instead of capping a
  /// header.
  Widget _scrollableTabBody(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight > _minTabArea
                ? constraints.maxHeight
                : _minTabArea,
          ),
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
/// `ProfileAvatar` + hairline close; XL-17: the LUXE glass card is gone —
/// one hairline per row, the violet stays on the hero).
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
/// the actions affordance; XL-17: hairline rows — the LUXE glass card is
/// gone).
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
