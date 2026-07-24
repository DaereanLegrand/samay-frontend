import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/services/supabase_service.dart';
import 'package:samay/shared/widgets/rank_badge.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

class MyGroupsScreen extends StatefulWidget {
  const MyGroupsScreen({super.key});

  @override
  State<MyGroupsScreen> createState() => _MyGroupsScreenState();
}

class _MyGroupsScreenState extends State<MyGroupsScreen> {
  List<Map<String, dynamic>> _groups = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final groups = await SupabaseService.instance.getMyGroups();
      setState(() => _groups = groups);
    } catch (_) {
      setState(() => _groups = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grupos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.people_outline),
            tooltip: 'Buscar amigos',
            onPressed: () => context.push('/user/search'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: VButton(
                          label: 'Crear grupo',
                          onPressed: () async {
                            await context.push('/group/create');
                            _load();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: VButton(
                          label: 'Ranking',
                          onPressed: () => context.push('/groups/leaderboard'),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => context.push('/friends/list'),
                        icon: const Icon(Icons.people, size: 16),
                        label: const Text('Amigos'),
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: () => context.push('/friends/requests'),
                        icon: const Icon(Icons.person_add_outlined, size: 16),
                        label: const Text('Solicitudes'),
                      ),
                    ],
                  ),
                ),
                const Divider(),
                if (_groups.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('No perteneces a ningún grupo',
                              style: Theme.of(context).textTheme.bodyLarge),
                          const SizedBox(height: 8),
                          Text('Crea un grupo o únete a uno existente',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: ListView.builder(
                      itemCount: _groups.length,
                      itemBuilder: (_, i) {
                        final g = _groups[i];
                        return ListTile(
                          leading: g['cover_url'] != null
                              ? CircleAvatar(
                                  backgroundImage: NetworkImage(g['cover_url'] as String),
                                )
                              : CircleAvatar(
                                  backgroundColor: Colors.grey[800],
                                  child: const Icon(Icons.group),
                                ),
                          title: Text(g['name'] as String? ?? ''),
                          subtitle: Row(
                            children: [
                              if (g['my_role'] != 'member')
                                Text(
                                  '${(g['my_role'] as String).toUpperCase()} · ',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              const VShardIcon(size: 12),
                              const SizedBox(width: 4),
                              Text('${g['group_shards'] ?? 0}',
                                  style: const TextStyle(fontSize: 12)),
                              if (g['rank_bracket'] != null) ...[
                                const SizedBox(width: 8),
                                RankBadge(bracket: g['rank_bracket'] as String),
                              ],
                            ],
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/group/${g['id']}'),
                        );
                      },
                    ),
                  ),
              ],
            ),
    );
  }
}
