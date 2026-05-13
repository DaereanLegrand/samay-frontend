import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/services/supabase_service.dart';
import 'package:vive_app/shared/widgets/rank_badge.dart';
import 'package:vive_app/shared/widgets/v_button.dart';
import 'package:vive_app/shared/widgets/v_shard_icon.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  const GroupDetailScreen({super.key, required this.groupId});

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _group;
  List<Map<String, dynamic>> _members = [];
  List<Map<String, dynamic>> _contributions = [];
  int _myContribution = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final group = await SupabaseService.instance.getGroup(widget.groupId);
      debugPrint('getGroup result: $group');
      final members = await SupabaseService.instance.getGroupMembers(widget.groupId);
      debugPrint('getGroupMembers count: ${members.length}');
      final contributions = await SupabaseService.instance.getGroupContributions(widget.groupId);
      final myContrib = await SupabaseService.instance.getUserContributionToGroup(widget.groupId);
      setState(() {
        _group = group;
        _members = members;
        _contributions = contributions;
        _myContribution = myContrib;
      });
    } catch (e, st) {
      debugPrint('GroupDetailScreen._load error: $e\n$st');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _group == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final g = _group!;
    final memberLimit = _getMemberLimit();
    final isFrozen = g['frozen_at'] != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(g['name'] as String? ?? 'Grupo'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Chat'),
            Tab(text: 'Miembros'),
            Tab(text: 'Eventos'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) => _handleAction(v),
            itemBuilder: (_) => [
              if (isFrozen)
                const PopupMenuItem(
                  value: 'frozen',
                  enabled: false,
                  child: Text('Grupo congelado'),
                ),
              const PopupMenuItem(value: 'leave', child: Text('Abandonar grupo')),
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
              child: const Text(
                'Grupo congelado — actualiza tu suscripci\u00f3n o transfiere el rol de promotor',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (g['cover_url'] != null)
                  Image.network(g['cover_url'] as String, height: 120, fit: BoxFit.cover),
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
                    Text('${g['group_shards'] ?? 0} shards de grupo',
                        style: Theme.of(context).textTheme.bodyLarge),
                  ],
                ),
                const SizedBox(height: 4),
                Text('${_members.length} / $memberLimit miembros',
                    style: Theme.of(context).textTheme.bodyMedium),
                if (_myContribution > 0) ...[
                  const SizedBox(height: 4),
                  Text('Mi contribuci\u00f3n: $_myContribution shards activos',
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: VButton(label: 'Donar shards', onPressed: () => context.push('/group/${widget.groupId}/donate'))),
                    const SizedBox(width: 8),
                    Expanded(child: VButton(label: 'Crear evento', onPressed: () => context.push('/group/${widget.groupId}/create-event'))),
                    const SizedBox(width: 8),
                    Expanded(child: VButton(label: 'Invitar', onPressed: () => context.push('/group/${widget.groupId}/invite'))),
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
                _buildMembersTab(),
                _buildEventsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    return const Center(
      child: Text('Chat pr\u00f3ximamente', style: TextStyle(color: Colors.grey)),
    );
  }

  Widget _buildMembersTab() {
    if (_members.isEmpty) {
      return const Center(
        child: Text('No hay miembros', style: TextStyle(color: Colors.grey)),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Top contribuidores', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ...(_contributions.take(5).map((c) {
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[800],
              child: const Icon(Icons.person, size: 16),
            ),
            title: Text(c['users']?['display_name'] ?? c['users']?['username'] ?? '${c['user_id']}'.substring(0, 8)),
            trailing: Text('${c['shards_contributed']} shards'),
          );
        })),
        const SizedBox(height: 24),
        Text('Miembros (${_members.length})', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        ...(_members.map((m) {
          final user = m['users'] as Map<String, dynamic>?;
          final displayName = user?['display_name'] as String? ?? user?['username'] as String? ?? '${m['user_id']}'.substring(0, 8);
          final initials = displayName.substring(0, 1).toUpperCase();
          return ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[800],
              child: Text(initials, style: const TextStyle(fontSize: 12)),
            ),
            title: Text(displayName),
            subtitle: Text(m['role'] as String? ?? 'member'),
          );
        })),
      ],
    );
  }

  Widget _buildEventsTab() {
    return const Center(
      child: Text('Eventos pr\u00f3ximamente', style: TextStyle(color: Colors.grey)),
    );
  }

  String _getMemberLimit() {
    if (_members.isEmpty) return '0';
    return '14';
  }

  void _handleAction(String value) {
    switch (value) {
      case 'leave':
        _leaveGroup();
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Abandonar grupo'),
        content: const Text('\u00bfEst\u00e1s seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abandonar')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await SupabaseService.instance.leaveGroup(widget.groupId);
      if (context.mounted) context.pop();
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
