import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/profile/providers/profile_providers.dart';
import 'package:samay/features/profile/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';
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
                  // U-15 R8 (F18 ADAPTED): the header is the edit
                  // affordance — tapping the avatar OR the username pushes
                  // the edit screen (Juega edits inline from the profile;
                  // the pushed screen is the Samay-shaped editor, and the
                  // avatar gains the affordance it only had inside edit).
                  Center(
                    child: Tooltip(
                      message: l10n.profileEditTitle,
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.push(RoutePaths.profileEdit),
                        child: ProfileAvatar(initials: initials),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: InkWell(
                      onTap: () => context.push(RoutePaths.profileEdit),
                      child: Text(
                        profile?['username']?.toString() ??
                            authState.valueOrNull?.user?['email'] ??
                            l10n.commonUser,
                        // §3.2 fancy moment (U-09): the username is the brand-
                        // ish element of the header — Playfair italic 28 with
                        // the glow-soft stack baked into the theme role.
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _BalanceCard(
                    personalShards: profile?['personal_shards'] as int? ?? 0,
                    preshards: profile?['preshards'] as int? ?? 0,
                    // SLED (I-64): the balance card opens the shard/preshard
                    // ledger history at `/shards/ledger`.
                    onTap: () => context.push(RoutePaths.shardsLedger),
                  ),
                  if (profile?['bio'] != null &&
                      (profile!['bio'] as String).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      profile['bio'] as String,
                      // §2.4: secondary text at body size must be
                      // mutedStrong (7.37:1 AA) — never muted.
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: AppColors.mutedStrong),
                    ),
                  ],
                  const SizedBox(height: 32),
                  Text(
                    l10n.profileMyGroups,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  groups.isEmpty
                      // U-15 R9 (F2 DIRECT): the 60px bare Text becomes the
                      // icon+title+hint voice — still inside the ListView, so
                      // the empty state stays pull-to-refreshable.
                      ? VEmptyView(
                          icon: Icons.group_outlined,
                          title: l10n.profileNoGroupsYet,
                          description: l10n.profileNoGroupsHint,
                        )
                      : SizedBox(
                          height: 120,
                          child: ListView.separated(
                            itemCount: groups.length,
                            // §5 ListTiles hairline (U-09): tiles are
                            // separated by 1px `hairline #1A1A1A` rules
                            // (the U-04 dividerTheme).
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
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
  final VoidCallback onTap;

  const _BalanceCard({
    required this.personalShards,
    required this.preshards,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return VCard(
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            // §5.6: the balance card uses the lg 24 gold diamond.
            const VShardIcon(size: AppIconSizes.lg),
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
            const Spacer(),
            const Icon(Icons.chevron_right, size: 20),
          ],
        ),
      ),
    );
  }
}
