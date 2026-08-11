import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/party_finder/providers/party_finder_providers.dart';
import 'package:samay/features/profile/widgets/interests.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_network_image.dart';

/// Party Finder (PFND spec — I-60): opt-in discovery by interest tags.
///
/// * Opt-in toggle on top (default OFF — off users can browse but are not
///   discoverable; the first-run explainer replaces the list while off).
/// * Match list: avatar, @username, shared-interests count + tag chips,
///   sorted by shared-tag count desc (service-side); no swipe mechanic.
/// * Tap → public profile; "Bloquear" reuses the friendships block path so a
///   blocked user never appears again.
///
/// Disco-minimalist per DISCO-DESIGN-SYSTEM §1/§5: black surface, hairline
/// borders, white core text; the signature glowPink reserved for the opt-in
/// highlight state (chip selection / switch accent).
class PartyFinderScreen extends ConsumerWidget {
  const PartyFinderScreen({super.key});

  Future<void> _setOptIn(WidgetRef ref, bool value) async {
    await ref.read(discoveryOptInProvider.notifier).setOptIn(value);
  }

  Future<void> _blockUser(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> match,
  ) async {
    final l10n = AppLocalizations.of(context);
    try {
      await ref
          .read(friendsRepositoryProvider)
          .blockUser(match['id'] as String);
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileUserBlocked)));
      ref.invalidate(partyMatchesProvider);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final optIn = ref.watch(discoveryOptInProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.partyFinderTitle)),
      body: Column(
        children: [
          SwitchListTile(
            title: Text(l10n.partyFinderOptInLabel),
            value: optIn.valueOrNull ?? false,
            onChanged: (value) => _setOptIn(ref, value),
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.hairline),
          Expanded(child: _body(context, ref, l10n, optIn)),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    AsyncValue<bool> optIn,
  ) {
    final enabled = optIn.valueOrNull ?? false;
    if (optIn.isLoading && !optIn.hasValue) {
      return const VLoadingView();
    }
    if (!enabled) {
      return VEmptyView(
        icon: Icons.travel_explore,
        title: l10n.partyFinderOptInOff,
        description: l10n.partyFinderOptInOffBody,
      );
    }
    return ref
        .watch(partyMatchesProvider)
        .when(
          // U-25 (§5.8): the match rows are the list-y first load with
          // nothing on screen — the avatar+lines skeleton stands in (U-22's
          // handoff named party_finder). The opt-in gate above keeps the
          // standard spinner: it is a quick local pre-check, not a heavy
          // nothing-on-screen frame.
          loading: () => const VSkeletonList(),
          error: (error, _) => ErrorView(
            message: l10n.partyFinderError,
            onRetry: () => ref.read(partyMatchesProvider.notifier).refresh(),
          ),
          data: (matches) => matches.isEmpty
              ? VEmptyView(
                  icon: Icons.people_outline,
                  title: l10n.partyFinderEmpty,
                  description: l10n.partyFinderEmptyBody,
                )
              : RefreshIndicator(
                  onRefresh: () =>
                      ref.read(partyMatchesProvider.notifier).refresh(),
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: matches.length,
                    itemBuilder: (_, i) {
                      final match = matches[i];
                      return _MatchCard(
                        match: match,
                        onTap: () => context.push(
                          RoutePaths.userProfile(match['id'] as String),
                        ),
                        onBlock: () => _blockUser(context, ref, match),
                      );
                    },
                  ),
                ),
        );
  }
}

/// First-run explainer while discovery is OFF (PFND spec: OFF users are
/// invisible but can still browse).

/// One match row: avatar, @username, shared-interests count, tag chips and
/// the block action (PFND spec row contract).
class _MatchCard extends StatelessWidget {
  final Map<String, dynamic> match;
  final VoidCallback onTap;
  final VoidCallback onBlock;

  const _MatchCard({
    required this.match,
    required this.onTap,
    required this.onBlock,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final username = match['username'] as String? ?? l10n.commonUser;
    final avatarUrl = match['avatar_url'] as String?;
    final rawTags = match['shared_tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList()
        : const <String>[];
    final count = match['shared_count'] as int? ?? tags.length;
    // Only catalog tags render (unknown/legacy DB tags are skipped — the
    // label lookup throws for ids outside the catalog by design).
    final knownTags = tags.where(kInterestTagIds.contains).toList();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            _MatchAvatar(avatarUrl: avatarUrl, username: username),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '@$username',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.partyFinderSharedInterests(count),
                    style: const TextStyle(color: AppColors.mutedStrong),
                  ),
                  if (knownTags.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        for (final tag in knownTags)
                          VChip(
                            label: interestTagLabel(l10n, tag),
                            selected: true,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.block, size: AppIconSizes.lg),
              tooltip: l10n.profileBlock,
              color: AppColors.mutedStrong,
              onPressed: onBlock,
            ),
          ],
        ),
      ),
    );
  }
}

class _MatchAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String username;

  const _MatchAvatar({required this.avatarUrl, required this.username});

  @override
  Widget build(BuildContext context) {
    // U-26 (U-25 F5): an empty (non-null) username would RangeError on
    // substring — the '?' initial fallback.
    final initials = username.isEmpty
        ? '?'
        : username.substring(0, 1).toUpperCase();
    if (avatarUrl == null) {
      return CircleAvatar(
        radius: 20,
        backgroundColor: AppColors.surfaceAlt,
        child: Text(initials, style: const TextStyle(color: AppColors.white)),
      );
    }
    return ClipOval(
      child: SizedBox(
        width: 40,
        height: 40,
        child: VNetworkImage(imageUrl: avatarUrl!, fit: BoxFit.cover),
      ),
    );
  }
}
