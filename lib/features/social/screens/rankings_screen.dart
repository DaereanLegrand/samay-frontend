import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/config_provider.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/social/providers/social_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/profile_avatar.dart';
import 'package:samay/shared/widgets/rank_badge.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// One Rankings surface: Users | Groups.
///
/// Replaces the two separate ranking screens so the Social tab has a single,
/// unambiguous ranking entry — the duplicated per-sub-tab "Ranking" tiles are
/// gone. The Users segment keeps the global shard ranking (with the
/// anonymize-names censor rule); the Groups segment keeps the tiered group
/// leaderboard. The page Header ("ranking") is the one verbatim/lowercase
/// surface; segment labels are Title Case.
class RankingsScreen extends ConsumerStatefulWidget {
  const RankingsScreen({super.key});

  @override
  ConsumerState<RankingsScreen> createState() => _RankingsScreenState();
}

enum _RankingKind { users, groups }

class _RankingsScreenState extends ConsumerState<RankingsScreen> {
  _RankingKind _kind = _RankingKind.users;
  String _tier = _tiers.first;
  static const _tiers = ['micro', 'small', 'medium', 'large'];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.palette.background,
      body: VHeaderBar(
        title: l10n.socialRankingTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screenHorizontal,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  VChip(
                    label: l10n.rankingsUsers,
                    selected: _kind == _RankingKind.users,
                    onSelected: () =>
                        setState(() => _kind = _RankingKind.users),
                    compact: true,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  VChip(
                    label: l10n.rankingsGroups,
                    selected: _kind == _RankingKind.groups,
                    onSelected: () =>
                        setState(() => _kind = _RankingKind.groups),
                    compact: true,
                  ),
                ],
              ),
            ),
            if (_kind == _RankingKind.groups)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  0,
                  AppSpacing.screenHorizontal,
                  AppSpacing.sm,
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (var i = 0; i < _tiers.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSpacing.sm),
                        VChip(
                          label: _tierLabel(_tiers[i]),
                          selected: _tier == _tiers[i],
                          onSelected: () => setState(() => _tier = _tiers[i]),
                          compact: true,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _kind == _RankingKind.users
                  ? const _UsersRanking()
                  : _GroupsRanking(tier: _tier),
            ),
          ],
        ),
      ),
    );
  }

  /// Tier wire values render Title Case ("micro" → "Micro").
  static String _tierLabel(String tier) => tier.isEmpty
      ? tier
      : '${tier[0].toUpperCase()}${tier.substring(1)}';
}

/// The global user ranking (non-deleted users by `personal_shards` DESC via
/// the `get_user_ranking` RPC). Censor rule: a name renders only when
/// anonymization is off or the profile is public (`profile_public`).
class _UsersRanking extends ConsumerWidget {
  const _UsersRanking();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final anonymize =
        ref.watch(appConfigProvider).valueOrNull?['ranking.anonymize_names'] ==
        'true';
    final rankingAsync = ref.watch(userRankingProvider);
    final entries = rankingAsync.valueOrNull;
    if (entries == null && rankingAsync.isLoading) {
      return const VLoadingView();
    }
    return VStateView(
      error: rankingAsync.error,
      errorMessage: rankingAsync.hasError
          ? rankingAsync.error!.toAppError().message
          : null,
      onRetry: () => ref.invalidate(userRankingProvider),
      empty: VEmptyView(
        icon: Icons.leaderboard_outlined,
        title: l10n.socialRankingEmpty,
      ),
      child: entries == null || entries.isEmpty
          ? null
          : RefreshIndicator(
              onRefresh: () => ref.read(userRankingProvider.notifier).refresh(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: entries.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: context.palette.hairline),
                itemBuilder: (_, i) {
                  final entry = entries[i];
                  final rank = i + 1;
                  final name = _displayName(entry, anonymize, l10n);
                  return ListTile(
                    leading:                     SizedBox(
                      width: AppSpacing.xxl,
                      child: Text(
                        '#$rank',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _rankColor(context, rank),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(name),
                    subtitle: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const VShardIcon(size: AppIconSizes.xs),
                        const SizedBox(width: AppSpacing.xs),
                        Text('${entry.personalShards}'),
                      ],
                    ),
                    trailing: ProfileAvatar(
                      size: AppSpacing.avatar,
                      initials: name.isEmpty ? null : name.substring(0, 1),
                      imageUrl: entry.avatarUrl,
                    ),
                    onTap: () =>
                        context.push(RoutePaths.userProfile(entry.userId)),
                  );
                },
              ),
            ),
    );
  }

  String _displayName(
    UserRankingEntry entry,
    bool anonymize,
    AppLocalizations l10n,
  ) {
    if (anonymize && !entry.profilePublic) return l10n.socialCensoredName;
    return entry.username.isEmpty ? l10n.socialCensoredName : entry.username;
  }
}

/// The tiered group leaderboard (`group_rank_snapshots` by `size_tier`).
class _GroupsRanking extends ConsumerWidget {
  final String tier;

  const _GroupsRanking({required this.tier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final rankingsAsync = ref.watch(leaderboardProvider(tier));
    final rankings = rankingsAsync.valueOrNull;
    if (rankings == null && rankingsAsync.isLoading) {
      return const VLoadingView();
    }
    return VStateView(
      error: rankingsAsync.error,
      errorMessage: rankingsAsync.hasError
          ? rankingsAsync.error!.toAppError().message
          : null,
      onRetry: () => ref.invalidate(leaderboardProvider(tier)),
      empty: VEmptyView(
        icon: Icons.leaderboard_outlined,
        title: l10n.groupsNoRankingData,
      ),
      child: rankings == null || rankings.isEmpty
          ? null
          : RefreshIndicator(
              onRefresh: () =>
                  ref.read(leaderboardProvider(tier).notifier).refresh(),
              child: ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: rankings.length,
                separatorBuilder: (_, _) =>
                    Divider(height: 1, color: context.palette.hairline),
                itemBuilder: (_, i) {
                  final entry = rankings[i];
                  final group = entry.group;
                  final rank = entry.rankPosition;
                  return ListTile(
                    leading:                     SizedBox(
                      width: AppSpacing.xxl,
                      child: Text(
                        '#$rank',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: _rankColor(context, rank),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      group.name.isEmpty ? l10n.commonGroup : group.name,
                    ),
                    subtitle: Text(
                      l10n.groupsLeaderboardSubtitle(
                        entry.memberCount,
                        entry.score,
                      ),
                    ),
                    trailing: group.rankBracket != null
                        ? RankBadge(
                            bracket: group.rankBracket!,
                            rank: rank >= 1 && rank <= 3 ? rank : null,
                          )
                        : null,
                    onTap: () => context.push(RoutePaths.groupDetail(group.id)),
                  );
                },
              ),
            ),
    );
  }
}

/// Semantic podium numerals (gold/silver/bronze) — everything else themed.
Color? _rankColor(BuildContext context, int rank) {
  return switch (rank) {
    1 => AppColors.discoGold,
    2 => AppColors.discoSilver,
    3 => AppColors.discoBronze,
    _ => context.palette.foreground,
  };
}
