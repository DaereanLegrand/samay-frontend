import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/services/supabase_service.dart';
import 'package:vive_app/shared/widgets/rank_badge.dart';
import 'package:vive_app/shared/widgets/v_chip.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  String _selectedTier = 'micro';
  List<Map<String, dynamic>> _rankings = [];
  bool _loading = true;

  final _tiers = ['micro', 'small', 'medium', 'large'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.instance.getLeaderboard(_selectedTier);
      final groups = <Map<String, dynamic>>[];
      for (final r in res) {
        final g = await SupabaseService.instance.getGroup(r['group_id'] as String);
        if (g != null) {
          g['rank_position'] = r['rank_position'];
          g['score'] = r['score'];
          g['member_count'] = r['member_count'];
          groups.add(g);
        }
      }
      setState(() => _rankings = groups);
    } catch (_) {
      setState(() => _rankings = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ranking de grupos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tiers.map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: VChip(
                    label: t,
                    selected: _selectedTier == t,
                    onSelected: () {
                      setState(() => _selectedTier = t);
                      _load();
                    },
                  ),
                )).toList(),
              ),
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else if (_rankings.isEmpty)
            const Expanded(child: Center(child: Text('Sin datos de ranking')))
          else
            Expanded(
              child: RefreshIndicator(
                onRefresh: _load,
                child: ListView.builder(
                  itemCount: _rankings.length,
                  itemBuilder: (_, i) {
                    final g = _rankings[i];
                    return ListTile(
                      leading: SizedBox(
                        width: 32,
                        child: Text(
                          '#${g['rank_position']}',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      title: Text(g['name'] as String? ?? 'Grupo'),
                      subtitle: Text('${g['member_count']} miembros · ${g['score']} shards'),
                      trailing: g['rank_bracket'] != null
                          ? RankBadge(bracket: g['rank_bracket'] as String)
                          : null,
                      onTap: () => context.push('/group/${g['id']}'),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}
