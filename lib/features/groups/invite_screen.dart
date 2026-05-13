import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/services/supabase_service.dart';

class InviteScreen extends StatefulWidget {
  final String groupId;
  const InviteScreen({super.key, required this.groupId});

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  Set<String> _memberIds = {};
  final Set<String> _selectedIds = {};
  bool _loading = true;
  bool _searching = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim();
    if (q.length < 2) {
      setState(() => _results = []);
      return;
    }
    _search(q);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final members = await SupabaseService.instance.getGroupMembers(widget.groupId);
      _memberIds = members.map((m) => m['user_id'] as String).toSet();
    } catch (_) {}
    setState(() => _loading = false);
  }

  Future<void> _search(String query) async {
    setState(() => _searching = true);
    try {
      final users = await SupabaseService.instance.searchUsers(query);
      final filtered = users.where((u) => !_memberIds.contains(u['id'] as String)).toList();
      setState(() => _results = filtered);
    } catch (_) {
      setState(() => _results = []);
    } finally {
      setState(() => _searching = false);
    }
  }

  Future<void> _invite() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _sending = true);
    try {
      for (final id in _selectedIds) {
        await SupabaseService.instance.client.from('group_members').insert({
          'group_id': widget.groupId,
          'user_id': id,
          'role': 'member',
          'status': 'invited',
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_selectedIds.length} invitado(s)')),
        );
        context.pop();
      }
    } catch (e) {
      debugPrint('InviteScreen._invite error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al invitar')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invitar'),
        actions: [
          if (_selectedIds.isNotEmpty)
            TextButton(
              onPressed: _sending ? null : _invite,
              child: _sending
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Invitar (${_selectedIds.length})'),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Buscar usuarios por username...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                if (_searching)
                  const LinearProgressIndicator(),
                Expanded(
                  child: _results.isEmpty
                      ? Center(
                          child: Text(
                            _searchController.text.trim().length < 2
                                ? 'Escribe al menos 2 caracteres para buscar'
                                : 'Sin resultados',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        )
                      : ListView.builder(
                          itemCount: _results.length,
                          itemBuilder: (_, i) {
                            final u = _results[i];
                            final uid = u['id'] as String;
                            final selected = _selectedIds.contains(uid);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.grey[800],
                                child: Text(
                                  (u['username'] as String? ?? '?').substring(0, 1).toUpperCase(),
                                ),
                              ),
                              title: Text('@${u['username']}'),
                              trailing: Checkbox(
                                value: selected,
                                onChanged: (_) => _toggle(uid),
                              ),
                              onTap: () => _toggle(uid),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _toggle(String uid) {
    setState(() {
      if (_selectedIds.contains(uid)) {
        _selectedIds.remove(uid);
      } else {
        _selectedIds.add(uid);
      }
    });
  }
}
