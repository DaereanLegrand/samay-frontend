import 'package:flutter/material.dart';
import 'package:vive_app/core/services/supabase_service.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blocked = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.instance.getBlockedUsers();
      final profiles = <Map<String, dynamic>>[];
      for (final b in res) {
        final uid = b['blocked_user_id'] as String;
        final profile = await SupabaseService.instance.getUserProfile(uid);
        if (profile != null) {
          profiles.add(profile);
        } else {
          profiles.add({
            'id': uid,
            'display_name': 'Usuario eliminado',
            'username': uid.substring(0, uid.length < 8 ? uid.length : 8),
            'avatar_url': null,
          });
        }
      }
      setState(() => _blocked = profiles);
    } catch (_) {
      setState(() => _blocked = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Usuarios bloqueados')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocked.isEmpty
              ? Center(
                  child: Text('No has bloqueado a nadie',
                      style: Theme.of(context).textTheme.bodyMedium),
                )
              : ListView.builder(
                  itemCount: _blocked.length,
                  itemBuilder: (_, i) {
                    final u = _blocked[i];
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
                          await SupabaseService.instance.unblockUser(u['id'] as String);
                          _load();
                        },
                        child: const Text('Desbloquear'),
                      ),
                    );
                  },
                ),
    );
  }
}
