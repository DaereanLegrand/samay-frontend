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
  Map<String, dynamic>? _profile;
  String? _friendshipStatus;
  String? _friendshipId;
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await SupabaseService.instance.getUserProfile(widget.userId);
      if (mounted) setState(() => _profile = profile);
    } catch (_) {}

    try {
      final status = await SupabaseService.instance.getFriendshipStatus(widget.userId);
      if (mounted) setState(() => _friendshipStatus = status);
    } catch (_) {}

    try {
      final fid = await SupabaseService.instance.getFriendshipIdForUser(widget.userId);
      if (mounted) setState(() => _friendshipId = fid);
    } catch (_) {}

    if (mounted) setState(() => _loading = false);
  }

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
      _load();
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

  Future<void> _acceptRequest() async {
    if (_friendshipId == null || _sending) return;
    setState(() => _sending = true);
    try {
      await SupabaseService.instance.acceptFriendRequest(_friendshipId!);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitud aceptada')),
        );
      }
      _load();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al aceptar solicitud')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Perfil')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final p = _profile;
    final displayName = p?['display_name'] as String? ?? 'Usuario';
    final username = p?['username'] as String?;
    final bio = p?['bio'] as String?;
    final initials = displayName.substring(0, 1).toUpperCase();

    return Scaffold(
      appBar: AppBar(title: Text(username != null ? '@$username' : 'Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey[800],
              child: Text(initials, style: const TextStyle(fontSize: 24)),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(displayName, style: Theme.of(context).textTheme.headlineMedium),
          ),
          if (username != null) ...[
            const SizedBox(height: 4),
            Center(
              child: Text('@$username', style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
          const SizedBox(height: 8),
          Center(
            child: Text(
              bio != null && bio.isNotEmpty ? bio! : 'Sin biografía',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(child: _buildActionButton()),
              if (_friendshipStatus == 'pending' && _friendshipId != null)
                const SizedBox(width: 8),
              if (_friendshipStatus == 'pending' && _friendshipId != null)
                Expanded(
                  child: VButton(
                    label: 'Rechazar',
                    onPressed: () async {
                      await SupabaseService.instance.declineFriendRequest(_friendshipId!);
                      _load();
                    },
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

  Widget _buildActionButton() {
    if (_friendshipStatus == 'accepted') {
      return VButton.emphasized(label: 'Amigos', onPressed: () {});
    }
    if (_friendshipStatus == 'pending' && _friendshipId != null) {
      return VButton.emphasized(
        label: _sending ? 'Aceptando...' : 'Aceptar solicitud',
        onPressed: _acceptRequest,
      );
    }
    return VButton.emphasized(
      label: _sending ? 'Enviando...' : 'Agregar amigo',
      onPressed: _sendRequest,
    );
  }
}
