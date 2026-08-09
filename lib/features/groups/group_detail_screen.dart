import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/supabase_service.dart';
import 'package:samay/features/groups/groups_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/rank_badge.dart';
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
    return Scaffold(
      appBar: AppBar(),
      body: body,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final groupAsync = ref.watch(groupDetailProvider(widget.groupId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final contributionsAsync = ref.watch(contributionsProvider(widget.groupId));

    return groupAsync.when(
      loading: () => _scaffold(const Center(child: CircularProgressIndicator())),
      error: (e, _) => _scaffold(ErrorView(
        message: e.toAppError().message,
        onRetry: () => ref.invalidate(groupDetailProvider(widget.groupId)),
      )),
      data: (group) {
        if (group == null) {
          return _scaffold(ErrorView(
            message: l10n.groupsNotFound,
            onRetry: () => ref.invalidate(groupDetailProvider(widget.groupId)),
          ));
        }
        return membersAsync.when(
          loading: () => _scaffold(const Center(child: CircularProgressIndicator())),
          error: (e, _) => _scaffold(ErrorView(
            message: e.toAppError().message,
            onRetry: () => ref.invalidate(groupMembersProvider(widget.groupId)),
          )),
          data: (members) => contributionsAsync.when(
            loading: () => _scaffold(const Center(child: CircularProgressIndicator())),
            error: (e, _) => _scaffold(ErrorView(
              message: e.toAppError().message,
              onRetry: () => ref.invalidate(contributionsProvider(widget.groupId)),
            )),
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
        title: Text(g['name'] as String? ?? l10n.commonGroup),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: l10n.groupsTabChat),
            Tab(text: l10n.groupsTabMembers),
            Tab(text: l10n.groupsTabEvents),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _handleAction(v),
            itemBuilder: (_) => [
              if (isFrozen)
                PopupMenuItem(
                  value: 'frozen',
                  enabled: false,
                  child: Text(l10n.groupsFrozenBadge),
                ),
              PopupMenuItem(value: 'leave', child: Text(l10n.groupsLeave)),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (isFrozen)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.red[900],
              child: Text(
                l10n.groupsFrozenBanner,
                style: const TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
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
                  Text(g['description'] as String, style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (g['size_tier'] != null)
                      _Badge(g['size_tier'] as String),
                    const SizedBox(width: 8),
                    if (g['rank_bracket'] != null)
                      RankBadge(bracket: g['rank_bracket'] as String),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const VShardIcon(),
                    const SizedBox(width: 8),
                    Text(
                      l10n.groupsShardsCount(
                        (g['group_shards'] as num?)?.toInt() ?? 0,
                      ),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.groupsMemberCount(members.length, memberLimit),
                  style: Theme.of(context).textTheme.bodyMedium,
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
                    Expanded(child: VButton(label: l10n.groupsDonateTitle, onPressed: () async {
                      await context.push(RoutePaths.donateToGroup(widget.groupId));
                      _invalidateData();
                    })),
                    const SizedBox(width: 8),
                    Expanded(child: VButton(label: l10n.groupsCreateEvent, onPressed: () => context.push(RoutePaths.createGroupEvent(widget.groupId)))),
                    const SizedBox(width: 8),
                    Expanded(child: VButton(label: l10n.commonInvite, onPressed: () => context.push(RoutePaths.inviteToGroup(widget.groupId)))),
                  ],
                ),
              ],
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
    );
  }

  Widget _buildChatTab() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Text(l10n.groupsChatComingSoon, style: const TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildMembersTab(
    List<Map<String, dynamic>> members,
    List<Map<String, dynamic>> contributors,
  ) {
    final l10n = AppLocalizations.of(context);
    if (members.isEmpty) {
      return Center(
        child: Text(l10n.groupsNoMembers, style: const TextStyle(color: Colors.grey)),
      );
    }
    // Descriptor rows: only row *data* is materialized here; widgets are
    // created lazily per visible row by the builder (PERF-01).
    final rows = <_MembersRow>[
      _RowHeader(l10n.groupsTopContributors),
      const _RowSpacer(8),
      ...contributors.take(5).map(
        (c) => _RowContributor(
          username: c['users']?['username'] ?? '${c['user_id']}'.substring(0, 8),
          shards: l10n.groupsShardsCountShort(
            (c['shards_contributed'] as num?)?.toInt() ?? 0,
          ),
        ),
      ),
      const _RowSpacer(24),
      _RowHeader(l10n.groupsMembersCount(members.length)),
      const _RowSpacer(8),
      ...members.map(
        (m) {
          final user = m['users'] as Map<String, dynamic>?;
          return _RowMember(
            username: user?['username'] as String? ?? '${m['user_id']}'.substring(0, 8),
            role: m['role'] as String? ?? 'member',
          );
        },
      ),
    ];
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: rows.length,
      itemBuilder: (_, i) => switch (rows[i]) {
        _RowHeader(:final text) =>
          Text(text, style: Theme.of(context).textTheme.labelLarge),
        _RowSpacer(:final height) => SizedBox(height: height),
        _RowContributor(:final username, :final shards) =>
          _ContributorTile(username: username, shards: shards),
        _RowMember(:final username, :final role) =>
          _MemberTile(username: username, role: role),
      },
    );
  }

  Widget _buildEventsTab() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Text(l10n.groupsEventsComingSoon, style: const TextStyle(color: Colors.grey)),
    );
  }

  String _getMemberLimit(List<Map<String, dynamic>> members) {
    if (members.isEmpty) return '0';
    return '14';
  }

  void _handleAction(String value) {
    switch (value) {
      case 'leave':
        _leaveGroup();
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
      await SupabaseService.instance.leaveGroup(widget.groupId);
      if (mounted) context.pop();
    }
  }
}

class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
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
  const _RowMember({required this.username, required this.role});
  final String username;
  final String role;
}

/// Dense contributor row (PERF-08: the repeated ListTile+CircleAvatar shape is
/// a const sub-widget so unchanged rows skip rebuilds).
class _ContributorTile extends StatelessWidget {
  final String username;
  final String shards;

  const _ContributorTile({required this.username, required this.shards});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey[800],
        child: const Icon(Icons.person, size: 16),
      ),
      title: Text(username),
      trailing: Text(shards),
    );
  }
}

/// Dense member row (PERF-08: same shape as [_ContributorTile] but with an
/// initials avatar and a role subtitle).
class _MemberTile extends StatelessWidget {
  final String username;
  final String role;

  const _MemberTile({required this.username, required this.role});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: Colors.grey[800],
        child: Text(
          username.substring(0, 1).toUpperCase(),
          style: const TextStyle(fontSize: 12),
        ),
      ),
      title: Text(username),
      subtitle: Text(role),
    );
  }
}
