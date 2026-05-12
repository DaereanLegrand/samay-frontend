import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vive_app/core/providers/auth_provider.dart';
import 'package:vive_app/core/services/supabase_service.dart';
import 'package:vive_app/shared/widgets/v_shard_icon.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final user = SupabaseService.instance.auth.currentUser;
      if (user == null) return;
      final res = await SupabaseService.instance.client
          .from('users')
          .select('display_name, personal_shards, preshards')
          .eq('id', user.id)
          .maybeSingle();
      if (res != null) setState(() => _profile = Map<String, dynamic>.from(res));
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final initials = _profile?['display_name']?.toString().substring(0, 2).toUpperCase()
        ?? auth.user?['email']?.toString().substring(0, 2).toUpperCase()
        ?? '?';

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
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.grey[800],
                    child: Text(initials, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    _profile?['display_name']?.toString() ?? auth.user?['email'] ?? 'Usuario',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                ),
                const SizedBox(height: 32),
                _BalanceCard(
                  personalShards: _profile?['personal_shards'] as int? ?? 0,
                  preshards: _profile?['preshards'] as int? ?? 0,
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
