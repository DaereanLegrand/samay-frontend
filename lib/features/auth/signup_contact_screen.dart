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

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    try {
      await ref.read(authStateProvider.notifier).sendOtp(email);
      final auth = ref.read(authStateProvider);
      if (auth.error != null) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Error'),
              content: Text(auth.error!),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }
        return;
      }
      if (mounted) context.push('/auth/verify', extra: email);
    } catch (e) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Error'),
            content: Text(e.toString().replaceAll(RegExp(r'\([^)]*\)'), '')),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
          ),
        );
      }
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
              'Ingresa tu correo para recibir un código de verificación',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            VInput(
              controller: _emailController,
              label: 'Correo electrónico',
              keyboardType: TextInputType.emailAddress,
            ),
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(auth.error!, style: const TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            VButton.emphasized(
              label: 'Enviar código',
              loading: auth.loading,
              onPressed: _sendCode,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
