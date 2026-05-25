import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vive/shared/widgets/v_button.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const Spacer(),
              Text('VIVE', style: Theme.of(context).textTheme.displayLarge),
              const SizedBox(height: 8),
              Text(
                'Tu vida social, en un solo lugar',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const Spacer(),
              VButton.emphasized(
                label: 'Crear cuenta',
                onPressed: () => context.push('/auth/signup'),
              ),
              const SizedBox(height: 12),
              VButton(
                label: 'Iniciar sesión',
                onPressed: () => context.push('/login'),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
