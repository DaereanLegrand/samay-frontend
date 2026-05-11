import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/providers/auth_provider.dart';
import 'package:vive_app/shared/widgets/v_button.dart';
import 'package:vive_app/shared/widgets/v_input.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final String email;
  const ProfileSetupScreen({super.key, required this.email});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    final displayName = _displayNameController.text.trim();
    if (username.isEmpty || displayName.isEmpty) return;

    setState(() => _saving = true);
    await ref.read(authStateProvider.notifier).createProfile(username, displayName);
    if (mounted) context.go('/main/feed');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Completa tu perfil')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey[800],
              child: IconButton(
                icon: const Icon(Icons.camera_alt, size: 32),
                onPressed: () {},
              ),
            ),
            const SizedBox(height: 32),
            VInput(
              controller: _usernameController,
              label: 'Nombre de usuario',
              hint: '@usuario',
            ),
            const SizedBox(height: 16),
            VInput(
              controller: _displayNameController,
              label: 'Nombre visible',
              hint: 'Tu nombre',
            ),
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(auth.error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 8),
            Text(
              'Puedes completar tu perfil después',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const Spacer(),
            VButton.emphasized(
              label: 'Completar después',
              onPressed: () => context.go('/main/feed'),
            ),
            const SizedBox(height: 12),
            VButton(
              label: 'Guardar',
              loading: _saving || auth.loading,
              onPressed: _save,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
