import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/providers/auth_provider.dart';
import 'package:vive_app/shared/widgets/v_button.dart';
import 'package:vive_app/shared/widgets/v_input.dart';

class SignupContactScreen extends ConsumerStatefulWidget {
  const SignupContactScreen({super.key});

  @override
  ConsumerState<SignupContactScreen> createState() => _SignupContactScreenState();
}

class _SignupContactScreenState extends ConsumerState<SignupContactScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.length < 6) return;
    await ref.read(authStateProvider.notifier).signUp(email, password);
    if (mounted && ref.read(authStateProvider).authenticated) {
      context.push('/auth/age-gate', extra: email);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              'Crea tu cuenta',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Ingresa tu correo y una contraseña',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            VInput(
              controller: _emailController,
              label: 'Correo electrónico',
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            VInput(
              controller: _passwordController,
              label: 'Contraseña (mínimo 6 caracteres)',
              obscureText: true,
            ),
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(auth.error!, style: const TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            VButton.emphasized(
              label: 'Crear cuenta',
              loading: auth.loading,
              onPressed: _continue,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
