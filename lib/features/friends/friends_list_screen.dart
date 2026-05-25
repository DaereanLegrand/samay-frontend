import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vive/core/services/supabase_service.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _friends = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.instance.getFriends();
      final profiles = <Map<String, dynamic>>[];
      for (final f in res) {
        final profile = await SupabaseService.instance.getUserProfile(f['user_id'] as String);
        if (profile != null) profiles.add(profile);
      }
      setState(() => _friends = profiles);
    } catch (_) {
      setState(() => _friends = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _friends.where((f) {
      final q = _searchController.text.toLowerCase();
      return q.isEmpty ||
          (f['username'] as String? ?? '').toLowerCase().contains(q) ||
          (f['username'] as String? ?? '').toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Amigos')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                hintText: 'Buscar entre amigos',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (filtered.isEmpty && _friends.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Sin amigos aún', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    Text('Busca usuarios para agregar amigos',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            )
          else if (filtered.isEmpty)
            const Expanded(
              child: Center(child: Text('No hay resultados')),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final u = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      child: Text(
                        (u['username'] as String? ?? '?').substring(0, 1).toUpperCase(),
                      ),
                    ),
                    title: Text('@${u['username']}'),
                    subtitle: Text('@${u['username']}'),
                    trailing: const Icon(Icons.circle, size: 8, color: Colors.green),
                    onTap: () => context.push('/user/${u['id']}'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
