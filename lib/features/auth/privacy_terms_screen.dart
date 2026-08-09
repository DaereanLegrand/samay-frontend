import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/shared/widgets/v_button.dart';

class PrivacyTermsScreen extends StatefulWidget {
  final String email;
  final String dateOfBirth;
  const PrivacyTermsScreen({super.key, required this.email, required this.dateOfBirth});

  @override
  State<PrivacyTermsScreen> createState() => _PrivacyTermsScreenState();
}

class _PrivacyTermsScreenState extends State<PrivacyTermsScreen> {
  bool _privacyAccepted = false;
  bool _termsAccepted = false;

  bool get _allAccepted => _privacyAccepted && _termsAccepted;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Términos y condiciones')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              'Acepta los términos para continuar',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text('Acepto la Política de Privacidad'),
              subtitle: const Text('Conoce cómo manejamos tus datos personales'),
              value: _privacyAccepted,
              onChanged: (v) => setState(() => _privacyAccepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            CheckboxListTile(
              title: const Text('Acepto los Términos de Servicio'),
              subtitle: const Text('Condiciones de uso de la aplicación'),
              value: _termsAccepted,
              onChanged: (v) => setState(() => _termsAccepted = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
            ),
            const Spacer(),
            VButton.emphasized(
              label: 'Crear cuenta',
              onPressed: _allAccepted
                  ? () => context.push(RoutePaths.profileSetup, extra: {
                        'email': widget.email,
                        'dateOfBirth': widget.dateOfBirth,
                      })
                  : null,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
