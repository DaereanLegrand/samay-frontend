import 'package:flutter/material.dart';
import 'package:vive_app/core/services/supabase_service.dart';
import 'package:vive_app/shared/widgets/v_button.dart';

class RequestsScreen extends StatefulWidget {
  const RequestsScreen({super.key});

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _requests = [];
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
      setState(() => _requests = res);
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
        return ListTile(
          title: Text('Usuario ${r['user_id']}'),
          subtitle: Text(isReceived ? 'Te envió una solicitud' : 'Solicitud enviada'),
          trailing: isReceived
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VButton(
                      label: 'Aceptar',
                      onPressed: () => _accept(r['friendship_id'] as String),
                    ),
                    const SizedBox(width: 8),
                    VButton(
                      label: 'Rechazar',
                      onPressed: () => _decline(r['friendship_id'] as String),
                    ),
                  ],
                )
              : VButton(
                  label: 'Cancelar',
                  onPressed: () => _decline(r['friendship_id'] as String),
                ),
        );
      },
    );
  }
}
