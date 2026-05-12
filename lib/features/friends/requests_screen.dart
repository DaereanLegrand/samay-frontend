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
  Map<String, String> _names = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() => _loading = true);
    try {
      final res = await SupabaseService.instance.getFriendRequests();
      final names = <String, String>{};
      for (final r in res) {
        if (!names.containsKey(r['user_id'] as String)) {
          final profile = await SupabaseService.instance.getUserProfile(r['user_id'] as String);
          names[r['user_id'] as String] = profile?['display_name'] as String? ?? profile?['username'] as String? ?? 'Usuario';
        }
      }
      setState(() {
        _requests = res;
        _names = names;
      });
    } catch (_) {
      setState(() => _requests = []);
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _accept(String id) async {
    await SupabaseService.instance.acceptFriendRequest(id);
    _loadRequests();
  }

  Future<void> _decline(String id) async {
    await SupabaseService.instance.declineFriendRequest(id);
    _loadRequests();
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
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildList(received, isReceived: true),
                _buildList(sent, isReceived: false),
              ],
            ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items, {required bool isReceived}) {
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
          subtitle: Text(isReceived ? 'Te envió una solicitud' : 'Solicitud enviada'),
          trailing: isReceived
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _accept(r['friendship_id'] as String),
                      child: const Text('Aceptar'),
                    ),
                    TextButton(
                      onPressed: () => _decline(r['friendship_id'] as String),
                      child: const Text('Rechazar'),
                    ),
                  ],
                )
              : TextButton(
                  onPressed: () => _decline(r['friendship_id'] as String),
                  child: const Text('Cancelar'),
                ),
        );
      },
    );
  }
}
