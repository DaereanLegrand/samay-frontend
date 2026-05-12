import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/services/supabase_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.instance.searchUsers(query.trim());
      setState(() => _results = res);
    } catch (_) {
      setState(() => _results = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buscar usuarios')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre de usuario',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _search,
            ),
          ),
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_results.isEmpty && _controller.text.isNotEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Text('No se encontraron usuarios'),
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: _results.length,
                itemBuilder: (_, i) {
                  final u = _results[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey[800],
                      child: Text(
                        (u['display_name'] as String? ?? '?').substring(0, 1).toUpperCase(),
                      ),
                    ),
                    title: Text(u['display_name'] as String? ?? ''),
                    subtitle: Text('@${u['username']}'),
                    trailing: TextButton(
                      onPressed: () async {
                        try {
                          await SupabaseService.instance.sendFriendRequest(u['id'] as String);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Solicitud enviada')),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                      child: const Text('Agregar'),
                    ),
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
