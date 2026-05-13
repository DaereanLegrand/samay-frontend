import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/services/supabase_service.dart';
import 'package:vive_app/shared/widgets/v_button.dart';
import 'package:vive_app/shared/widgets/v_input.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _bioController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = SupabaseService.instance.auth.currentUser;
      if (user == null) return;
      final res = await SupabaseService.instance.client
          .from('users')
          .select('bio')
          .eq('id', user.id)
          .maybeSingle();
      if (res != null) {
        _bioController.text = res['bio'] as String? ?? '';
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final user = SupabaseService.instance.auth.currentUser;
      if (user == null) return;
      await SupabaseService.instance.client.from('users').update({
        'bio': _bioController.text.trim(),
      }).eq('id', user.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil actualizado')),
        );
        context.pop();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.grey[800],
                        child: const Icon(Icons.person, size: 48),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.white,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                            onPressed: () {},
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                VInput(
                  controller: _bioController,
                  label: 'Biograf\u00eda',
                ),
                const SizedBox(height: 32),
                VButton.emphasized(
                  label: 'Guardar cambios',
                  loading: _saving,
                  onPressed: _save,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {},
                  child: const Text('Cambiar contraseña'),
                ),
              ],
            ),
    );
  }
}
