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
      final members = await SupabaseService.instance.getGroupMembers(widget.groupId);
      final contributions = await SupabaseService.instance.getGroupContributions(widget.groupId);
      final myContrib = await SupabaseService.instance.getUserContributionToGroup(widget.groupId);
      setState(() {
        _group = group;
        _members = members;
        _contributions = contributions;
        _myContribution = myContrib;
      });
    } catch (_) {
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
              const PopupMenuItem(value: 'members', child: Text('Ver miembros')),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (isFrozen)
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.red[900],
              child: const Text(
                'Grupo congelado — actualiza tu suscripción o transfiere el rol de promotor',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          if (g['cover_url'] != null)
            Image.network(g['cover_url'] as String, height: 160, fit: BoxFit.cover),
          const SizedBox(height: 16),
          Text(g['name'] as String? ?? '', style: Theme.of(context).textTheme.headlineMedium),
          if (g['description'] != null) ...[
            const SizedBox(height: 8),
            Text(g['description'] as String, style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              if (g['size_tier'] != null)
                _Badge(g['size_tier'] as String),
              const SizedBox(width: 8),
              if (g['rank_bracket'] != null)
                RankBadge(bracket: g['rank_bracket'] as String),
            ],
          ),
          const SizedBox(height: 12),
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
            Text('Mi contribución: $_myContribution shards activos',
                style: Theme.of(context).textTheme.bodyMedium),
          ],
          const SizedBox(height: 24),
          Row(
            children: [
              VButton(label: 'Donar shards', onPressed: () => context.push('/group/${widget.groupId}/donate')),
              const SizedBox(width: 8),
              VButton(label: 'Crear evento', onPressed: () => context.push('/group/${widget.groupId}/create-event')),
              const SizedBox(width: 8),
              VButton(label: 'Invitar', onPressed: () => context.push('/group/${widget.groupId}/invite')),
            ],
          ),
          const SizedBox(height: 24),
          Text('Top contribuidores', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ...(_contributions.take(5).map((c) {
            return ListTile(
              dense: true,
              title: Text('Usuario ${c['user_id']}'),
              trailing: Text('${c['shards_contributed']} shards'),
            );
          })),
        ],
      ),
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
      case 'members':
        context.push('/group/${widget.groupId}/members');
    }
  }

  Future<void> _leaveGroup() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Abandonar grupo'),
        content: const Text('¿Estás seguro?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Abandonar')),
        ],
      ),
    );
    if (confirm == true) {
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
