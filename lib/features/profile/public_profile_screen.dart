import 'package:flutter/material.dart';
import 'package:vive_app/core/services/supabase_service.dart';
import 'package:vive_app/shared/widgets/v_button.dart';

class PublicProfileScreen extends StatefulWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  bool _sending = false;

  Future<void> _sendRequest() async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.instance.sendFriendRequest(widget.userId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud de amistad enviada')),
        );
      }
    } catch (e) {
      final msg = e.toString().replaceAll(RegExp(r'(Exception: |PostgrestException\([^)]*\))'), '').trim();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg.isNotEmpty ? msg : 'Error al enviar solicitud')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey[800],
              child: const Icon(Icons.person, size: 48),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Usuario', style: Theme.of(context).textTheme.headlineMedium),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Sin biografía',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: VButton.emphasized(
                  label: _sending ? 'Enviando...' : 'Agregar amigo',
                  onPressed: _sendRequest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Grupos compartidos', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Sin grupos en común',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
