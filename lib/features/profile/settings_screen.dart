import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.subscriptions),
            title: const Text('Suscripción'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RoutePaths.subscriptions),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.notifications),
            title: const Text('Notificaciones'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Editar perfil'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RoutePaths.profileEdit),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.shield),
            title: const Text('Privacidad'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {},
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.block),
            title: const Text('Usuarios bloqueados'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(RoutePaths.blockedUsers),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Eliminar mi cuenta', style: TextStyle(color: Colors.red)),
            onTap: () => context.push(RoutePaths.deleteAccount),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () async {
              await ref.read(authStateProvider.notifier).signOut();
              if (context.mounted) context.go(RoutePaths.login);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Samay v1.0.0',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
