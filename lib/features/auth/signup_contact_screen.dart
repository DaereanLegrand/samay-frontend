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
  final _confirmController = TextEditingController();
  String? _validationError;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool _isPasswordValid(String pwd) {
    if (pwd.length < 6) return false;
    if (!pwd.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    setState(() => _validationError = null);
    if (email.isEmpty || password.isEmpty || confirm.isEmpty) return;
    if (!_isPasswordValid(password)) {
      setState(() => _validationError = 'La contraseña debe tener al menos 6 caracteres y contener un número.');
      return;
    }
    if (password != confirm) {
      setState(() => _validationError = 'Las contraseñas no coinciden.');
      return;
    }
    try {
      final action = await ref.read(authStateProvider.notifier).checkEmail(email);
      if (action == 'exists') {
        if (mounted) {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Text('Correo ya registrado'),
              content: const Text('Este correo ya tiene una cuenta completa. Inicia sesión en su lugar.'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }
        return;
      }
      await ref.read(authStateProvider.notifier).sendOtp(email);
      if (mounted) context.push('/auth/verify', extra: {
        'email': email,
        'password': password,
      });
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
              'Ingresa tu correo y crea una contraseña',
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
              label: 'Contraseña (mín. 6 caracteres, 1 número)',
              obscureText: true,
            ),
            const SizedBox(height: 16),
            VInput(
              controller: _confirmController,
              label: 'Confirmar contraseña',
              obscureText: true,
            ),
            if (_validationError != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_validationError!, style: const TextStyle(color: Colors.red)),
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
              onPressed: _signup,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
