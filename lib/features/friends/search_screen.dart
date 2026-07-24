import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/services/supabase_service.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;
  Timer? _debounce;
  int _debounceMs = 300;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    try {
      final config = await SupabaseService.instance.fetchAppConfig();
      _debounceMs = int.tryParse(config['app.search_debounce_ms'] ?? '') ?? 300;
    } catch (_) {}
  }

  void _onChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(Duration(milliseconds: _debounceMs), () => _search(query));
  }

  Future<void> _search(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _results = []);
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.instance.searchUsers(query.trim());
      if (mounted) setState(() => _results = res);
    } catch (_) {
      if (mounted) setState(() => _results = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
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
              onChanged: _onChanged,
            ),
          ),
          if (_loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
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
                        (u['username'] as String? ?? '?').substring(0, 1).toUpperCase(),
                      ),
                    ),
                    title: Text('@${u['username']}'),
                    subtitle: null,
                    trailing: _buildButton(u),
                    onTap: () => context.push('/user/${u['id']}'),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildButton(Map<String, dynamic> user) {
    final status = user['friendship_status'] as String?;
    final userId = user['id'] as String;

    if (status == 'accepted') {
      return TextButton(
        onPressed: null,
        child: const Text('Amigos'),
      );
    }
    if (status == 'pending') {
      return TextButton(
        onPressed: null,
        child: const Text('Solicitado'),
      );
    }
    if (status == 'blocked') {
      return TextButton(
        onPressed: null,
        child: const Text('Bloqueado'),
      );
    }
    return TextButton(
      onPressed: () async {
        try {
          await SupabaseService.instance.sendFriendRequest(userId);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Solicitud enviada')),
            );
          }
          _search(_controller.text);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error: $e')),
            );
          }
        }
      },
      child: const Text('Agregar'),
    );
  }
}
