import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_input.dart';

class ProfileSetupScreen extends ConsumerStatefulWidget {
  final String email;
  final String dateOfBirth;
  const ProfileSetupScreen({super.key, required this.email, required this.dateOfBirth});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() => _saving = true);
    await ref.read(authStateProvider.notifier).createProfile(username, dateOfBirth: widget.dateOfBirth);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ref.read(authStateProvider).error == null) {
      context.go('/main/feed');
    }
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
            const SizedBox(height: 4),
            Text(
              'No podrás cambiar tu nombre de usuario después del registro.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
              ),
            ),
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(auth.error!, style: const TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            VButton.emphasized(
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
