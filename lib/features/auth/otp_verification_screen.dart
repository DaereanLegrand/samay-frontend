import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/shared/widgets/v_button.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String password;
  const OtpVerificationScreen({super.key, required this.email, required this.password});

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    await ref.read(authStateProvider.notifier).verifyOtp(
          widget.email,
          _codeController.text.trim(),
          widget.password,
        );
    if (mounted && !ref.read(authStateProvider).authenticated) return;
    final authState = ref.read(authStateProvider);
    if (authState.hasProfile) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Correo ya registrado'),
            content: const Text('Este correo ya tiene una cuenta completa. Inicia sesión en su lugar.'),
            actions: [TextButton(
              onPressed: () {
                ref.read(authStateProvider.notifier).signOut();
                Navigator.pop(context);
              },
              child: const Text('OK'),
            )],
          ),
        );
      }
      return;
    }
    if (mounted) context.push('/auth/age-gate', extra: widget.email);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verificar código')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Text(
              'Ingresa el código de verificación',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Enviamos un código de 6 dígitos a ${widget.email}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _codeController,
              maxLength: 6,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 32, letterSpacing: 12),
              decoration: const InputDecoration(counterText: ''),
            ),
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(auth.error!, style: const TextStyle(color: Colors.red)),
              ),
            const Spacer(),
            VButton.emphasized(
              label: 'Verificar',
              loading: auth.loading,
              onPressed: _verify,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
