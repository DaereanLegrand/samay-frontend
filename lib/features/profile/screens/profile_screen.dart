import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/config/feature_flags.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/profile/providers/profile_providers.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/glass/v_glass.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
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
          // U-26 (4.1.2): the gear is icon-only — the tooltip is its
          // accessibility name for screen readers.
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: l10n.profileSettingsTitle,
            onPressed: () => context.push(RoutePaths.settings),
          ),
        ],
      ),
      // LUXE v2 (XL-08): the profile is informational — the hero username
      // carries the brand moment.
      body: showLoading
            // U-22 handoff (U-23): the profile hero loads with the
            // `VSkeletonProfile` skeleton (avatar circle + name/handle/body
            // lines, §5.8/§6.3) instead of the bare spinner — the screen has
            // real geometry to mirror (the U-21 `VLoadingView` was the only
            // remaining default here).
            ? const VSkeletonProfile()
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
                        child: ProfileAvatar(
                          initials: initials,
                          imageUrl: profile?['avatar_url'] as String?,
                        ),
                      ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: InkWell(
                        onTap: () => context.push(RoutePaths.profileEdit),
                        // LUXE v2 (XL-08): the username is the hero — gold
                        // VDisplayText (uppercase Playfair, gradient fill,
                        // slow halo pulse + one-time shimmer sweep). No other
                        // title on the screen — one hero per screen (§8).
                        child: VDisplayText(
                          text: displayName,
                          size: 28,
                          gradient: AppGradients.gold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
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
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.mutedStrong,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    // LUXE v2 (XL-08): the groups header is the §3.3
                    // sectionLabel overline voice (uppercase Inter,
                    // letter-spaced) — not a title.
                    Text(
                      l10n.profileMyGroups.toUpperCase(),
                      style: AppTypography.sectionLabel,
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
                        : Column(
                            children: [
                              // U-19: the fixed-height 120px nested box
                              // (U-09 flag) is gone — §7.3 forbids hard
                              // heights on text containers. The tiles now
                              // render inline so every row grows with the
                              // text scale and the outer ListView scrolls
                              // naturally (no inner viewport, no clipping).
                              for (var i = 0; i < groups.length; i++)
                                _GroupTile(
                                  name: groups[i]['name'] as String? ?? '',
                                  shards: l10n.groupsShardsCountShort(
                                    (groups[i]['group_shards'] as num?)
                                            ?.toInt() ??
                                        0,
                                  ),
                                  showDivider: i > 0,
                                ),
                            ],
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

/// One profile-groups row (PERF-08: const sub-widget — the U-19 inline
/// replacement of the fixed-height nested list; the hairline divider sits
/// above every row except the first, matching the old `ListView.separated`).
class _GroupTile extends StatelessWidget {
  final String name;
  final String shards;
  final bool showDivider;

  const _GroupTile({
    required this.name,
    required this.shards,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showDivider) const Divider(height: 1),
        ListTile(
          dense: true,
          leading: const Icon(Icons.group, size: 20),
          title: Text(name),
          trailing: Text(shards),
        ),
      ],
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
    // XL-17 (Gemma round 2, 12_profile: "cluttered", "information density"):
    // the balance card's gold ring/glow ride the watered run (mix 0.4) and
    // the halo drops to a whisper (≤0.15) — the vivid gold survives only in
    // the username hero shader and the shard diamond.
    final watered = AppGradients.wateredFamily(AppGradients.gold, mix: 0.4);
    // LUXE v2 (XL-08): the balance card is liquid glass — gold gradient
    // hairline ring + soft gold glow (`AppGradients.glowShadows`), white
    // numbers, gold diamond (the currency token, §5.6). The transparent
    // Material lets the InkWell paint its ink above the glass face.
    return VGlassCard(
      gradient: watered,
      glowAlpha: 0.12,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Row(
            children: [
              // §5.6: the balance card uses the lg 24 gold diamond.
              const VShardIcon(size: AppIconSizes.lg),
              const SizedBox(width: 12),
              // U-19: the shards column is `Expanded` (§7.3 — the fixed
              // `Spacer` let the natural-width column overflow the Row at
              // ≥1.5× text scale; the expanded text wraps instead).
              Expanded(
                child: Column(
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
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
