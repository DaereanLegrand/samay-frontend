import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/feature_flags.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/profile/profile_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    final profileFuture = ref.read(myProfileProvider.notifier).refresh();
    final groupsFuture = ref.read(myGroupsProvider.notifier).refresh();
    try {
      await Future.wait([profileFuture, groupsFuture]);
    } catch (_) {
      // Failures surface through each provider's AsyncError state; the
      // RefreshIndicator must still settle.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final profileAsync = ref.watch(myProfileProvider);
    final groupsAsync = ref.watch(myGroupsProvider);
    final l10n = AppLocalizations.of(context);

    final showLoading =
        (profileAsync.isLoading && !profileAsync.hasValue) ||
        (groupsAsync.isLoading && !groupsAsync.hasValue);

    final error = !profileAsync.hasValue && profileAsync.hasError
        ? profileAsync.error!
        : !groupsAsync.hasValue && groupsAsync.hasError
        ? groupsAsync.error!
        : null;

    final profile = profileAsync.valueOrNull;
    final groups = groupsAsync.valueOrNull ?? const <Map<String, dynamic>>[];

    final displayName =
        profile?['username']?.toString() ??
        authState.valueOrNull?.user?['email'] ??
        l10n.commonUser;
    final initials = displayName
        .substring(0, displayName.length < 2 ? displayName.length : 2)
        .toUpperCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push(RoutePaths.settings),
          ),
        ],
      ),
      body: showLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? ErrorView(
              message: error.toAppError().message,
              onRetry: () => _refresh(ref),
            )
          : RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: Colors.grey[800],
                      child: Text(
                        initials,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      profile?['username']?.toString() ??
                          authState.valueOrNull?.user?['email'] ??
                          l10n.commonUser,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _BalanceCard(
                    personalShards: profile?['personal_shards'] as int? ?? 0,
                    preshards: profile?['preshards'] as int? ?? 0,
                  ),
                  if (profile?['bio'] != null &&
                      (profile!['bio'] as String).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      profile['bio'] as String,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    l10n.profileMyGroups,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  groups.isEmpty
                      ? SizedBox(
                          height: 60,
                          child: Center(
                            child: Text(
                              l10n.profileNoGroupsYet,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        )
                      : SizedBox(
                          height: 120,
                          child: ListView.builder(
                            itemCount: groups.length,
                            itemBuilder: (context, index) {
                              final g = groups[index];
                              return ListTile(
                                dense: true,
                                leading: const Icon(Icons.group, size: 20),
                                title: Text(g['name'] as String? ?? ''),
                                trailing: Text(
                                  l10n.groupsShardsCountShort(
                                    (g['group_shards'] as num?)?.toInt() ?? 0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                  // PRFL cosmetics entry point (I-36 foundation → I-62):
                  // flag-gated (I-49 release gating); the row navigates
                  // to the cosmetics shop at `/cosmetics` (COSM spec).
                  if (ref.watch(featureFlagsProvider).cosmeticsSection) ...[
                    const SizedBox(height: 32),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.style, size: 20),
                      title: Text(
                        l10n.profileCosmetics,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      trailing: const Icon(Icons.chevron_right, size: 20),
                      onTap: () => context.push(RoutePaths.cosmetics),
                    ),
                  ],
                ],
              ),
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
    final l10n = AppLocalizations.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(border: Border.all(color: Colors.grey[800]!)),
      child: Row(
        children: [
          const VShardIcon(),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.profileShardsCount(personalShards),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              Text(
                l10n.profilePreshardsCount(preshards),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
