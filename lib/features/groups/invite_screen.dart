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
  List<Map<String, dynamic>> _friends = [];
  final Set<String> _selectedIds = {};
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final friends = await SupabaseService.instance.getFriends();
      final members = await SupabaseService.instance.getGroupMembers(widget.groupId);
      final memberIds = members.map((m) => m['user_id'] as String).toSet();
      final profiles = <Map<String, dynamic>>[];
      for (final f in friends) {
        if (!memberIds.contains(f['user_id'] as String)) {
          final profile = await SupabaseService.instance.getUserProfile(f['user_id'] as String);
          if (profile != null) {
            profiles.add(profile);
          }
        }
      }
      if (mounted) setState(() => _friends = profiles);
    } catch (e) {
      debugPrint('InviteScreen._load error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
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
        title: const Text('Invitar amigos'),
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
          : _friends.isEmpty
              ? const Center(child: Text('No tienes amigos para invitar'))
              : ListView.builder(
                  itemCount: _friends.length,
                  itemBuilder: (_, i) {
                    final u = _friends[i];
                    final uid = u['id'] as String;
                    final selected = _selectedIds.contains(uid);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.grey[800],
                        child: Text(
                          (u['display_name'] as String? ?? u['username'] as String? ?? '?')
                              .substring(0, 1)
                              .toUpperCase(),
                        ),
                      ),
                      title: Text(u['display_name'] as String? ?? ''),
                      subtitle: Text('@${u['username']}'),
                      trailing: Checkbox(
                        value: selected,
                        onChanged: (_) {
                          setState(() {
                            if (selected) {
                              _selectedIds.remove(uid);
                            } else {
                              _selectedIds.add(uid);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (selected) {
                            _selectedIds.remove(uid);
                          } else {
                            _selectedIds.add(uid);
                          }
                        });
                      },
                    );
                  },
                ),
    );
  }
}
