import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vive/core/providers/auth_provider.dart';
import 'package:vive/core/services/supabase_service.dart';
import 'package:vive/shared/widgets/v_button.dart';
import 'package:vive/shared/widgets/v_input.dart';

class DeleteAccountScreen extends ConsumerStatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  ConsumerState<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends ConsumerState<DeleteAccountScreen> {
  final _emailController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _emailMatches {
    try {
      final currentEmail = SupabaseService.instance.auth.currentUser?.email ?? '';
      return _emailController.text.trim().toLowerCase() == currentEmail.toLowerCase();
    } catch (_) {
      return false;
    }
  }

  Future<void> _delete() async {
    if (!_emailMatches) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El correo no coincide con tu cuenta')),
        );
      }
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar cuenta?'),
        content: const Text(
          'Esta acción no se puede deshacer. Tus datos serán anonimizados '
          'y tu cuenta será eliminada permanentemente después de 30 días.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authStateProvider.notifier).deleteAccount();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final emailFilled = _emailController.text.trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Eliminar cuenta')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(
              'Al eliminar tu cuenta, tus datos serán anonimizados. '
              'Tus mensajes y contribuciones al ranking de grupos se mantendrán '
              'pero no serán vinculados a ti. Podrás recuperar tu cuenta dentro de 30 días.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Confirma tu correo electrónico para continuar:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            VInput(
              controller: _emailController,
              label: 'Correo electrónico',
              keyboardType: TextInputType.emailAddress,
            ),
            const Spacer(),
            VButton.emphasized(
              label: 'Eliminar cuenta',
              onPressed: emailFilled ? _delete : null,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
