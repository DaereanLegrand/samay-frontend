import 'package:flutter/material.dart';
import 'package:vive_app/shared/widgets/v_button.dart';

class PublicProfileScreen extends StatelessWidget {
  final String userId;
  const PublicProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey[800],
              child: const Icon(Icons.person, size: 48),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text('Usuario', style: Theme.of(context).textTheme.headlineMedium),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Sin biografía',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 32),
          Row(
            children: [
              Expanded(
                child: VButton.emphasized(
                  label: 'Agregar amigo',
                  onPressed: () {},
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text('Grupos compartidos', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Sin grupos en común',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
