import 'package:flutter/material.dart';
import 'package:vive_app/core/services/supabase_service.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _requests = [];
  List<Map<String, dynamic>> _invites = [];
  Map<String, String> _names = {};
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
      final requests = await SupabaseService.instance.getFriendRequests();
      final invites = await SupabaseService.instance.getGroupInvites();
      final names = <String, String>{};
      for (final r in requests) {
        if (!names.containsKey(r['user_id'] as String)) {
          final profile = await SupabaseService.instance.getUserProfile(r['user_id'] as String);
          names[r['user_id'] as String] = profile?['username'] as String? ?? 'Usuario';
        }
      }
      setState(() {
        _requests = requests;
        _invites = invites;
        _names = names;
      });
    } catch (_) {
      setState(() {
        _requests = [];
        _invites = [];
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _acceptFriend(String id) async {
    await SupabaseService.instance.acceptFriendRequest(id);
    _load();
  }

  Future<void> _declineFriend(String id) async {
    await SupabaseService.instance.declineFriendRequest(id);
    _load();
  }

  Future<void> _acceptInvite(String membershipId) async {
    await SupabaseService.instance.acceptGroupInvite(membershipId);
    _load();
  }

  Future<void> _declineInvite(String membershipId) async {
    await SupabaseService.instance.declineGroupInvite(membershipId);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final received = _requests.where((r) => r['type'] == 'received').toList();
    final sent = _requests.where((r) => r['type'] == 'sent').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solicitudes'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Recibidas'),
            Tab(text: 'Enviadas'),
            Tab(text: 'Invitaciones'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRequests(received, isReceived: true),
                _buildRequests(sent, isReceived: false),
                _buildInvites(),
              ],
            ),
    );
  }

  Widget _buildRequests(List<Map<String, dynamic>> items, {required bool isReceived}) {
    if (items.isEmpty) {
      return Center(
        child: Text(isReceived ? 'Sin solicitudes recibidas' : 'Sin solicitudes enviadas'),
      );
    }
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (_, i) {
        final r = items[i];
        final name = _names[r['user_id'] as String] ?? 'Usuario';
        return ListTile(
          title: Text(name),
          subtitle: Text(isReceived ? 'Te envi\u00f3 una solicitud' : 'Solicitud enviada'),
          trailing: isReceived
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _acceptFriend(r['friendship_id'] as String),
                      child: const Text('Aceptar'),
                    ),
                    TextButton(
                      onPressed: () => _declineFriend(r['friendship_id'] as String),
                      child: const Text('Rechazar'),
                    ),
                  ],
                )
              : TextButton(
                  onPressed: () => _declineFriend(r['friendship_id'] as String),
                  child: const Text('Cancelar'),
                ),
        );
      },
    );
  }

  Widget _buildInvites() {
    if (_invites.isEmpty) {
      return const Center(child: Text('Sin invitaciones'));
    }
    return ListView.builder(
      itemCount: _invites.length,
      itemBuilder: (_, i) {
        final invite = _invites[i];
        final groupName = (invite['groups'] as Map<String, dynamic>?)?['name'] as String? ?? 'Grupo';
        return ListTile(
          title: Text(groupName),
          subtitle: Text(invite['role'] as String? ?? 'member'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(
                onPressed: () => _acceptInvite(invite['id'] as String),
                child: const Text('Aceptar'),
              ),
              TextButton(
                onPressed: () => _declineInvite(invite['id'] as String),
                child: const Text('Rechazar'),
              ),
            ],
          ),
        );
      },
    );
  }
}
