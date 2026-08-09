import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/l10n/app_localizations.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileSettingsTitle)),
      body: ListView(
        children: [
          _SettingsTile(
            icon: Icons.subscriptions,
            label: l10n.profileSubscription,
            onTap: () => context.push(RoutePaths.subscriptions),
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.notifications,
            label: l10n.profileNotifications,
            onTap: () {},
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.person,
            label: l10n.profileEditTitle,
            onTap: () => context.push(RoutePaths.profileEdit),
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.shield,
            label: l10n.profilePrivacy,
            onTap: () {},
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.block,
            label: l10n.profileBlockedUsers,
            onTap: () => context.push(RoutePaths.blockedUsers),
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.delete_forever,
            label: l10n.profileDeleteMyAccount,
            destructive: true,
            onTap: () => context.push(RoutePaths.deleteAccount),
          ),
          const Divider(),
          _SettingsTile(
            icon: Icons.logout,
            label: l10n.profileSignOut,
            onTap: () async {
              await ref.read(authStateProvider.notifier).signOut();
              if (context.mounted) context.go(RoutePaths.login);
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              l10n.profileVersion,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings menu row (PERF-08/CQ-05: the seven repeated ListTile shapes are
/// one const sub-widget; only the data that changes is passed in).
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: destructive ? Colors.red : null),
      title: Text(
        label,
        style: destructive ? const TextStyle(color: Colors.red) : null,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
