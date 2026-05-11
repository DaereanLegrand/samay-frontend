import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/providers/auth_provider.dart';
import 'package:vive_app/shared/widgets/v_shard_icon.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authStateProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 48,
              backgroundColor: Colors.grey[800],
              child: Text(
                auth.user?['email']?.toString().substring(0, 2).toUpperCase() ?? '?',
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              auth.user?['email'] ?? 'Usuario',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          const SizedBox(height: 32),
          _BalanceCard(
            personalShards: 0,
            preshards: 0,
          ),
          const SizedBox(height: 32),
          Text('Grupos', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: Center(
              child: Text(
                'No perteneces a ningún grupo aún',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final int personalShards;
  final int preshards;

  const _BalanceCard({required this.personalShards, required this.preshards});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[800]!),
      ),
      child: Row(
        children: [
          const VShardIcon(),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$personalShards shards',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                '$preshards preshards',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
