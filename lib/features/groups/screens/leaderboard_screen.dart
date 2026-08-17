import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/glass/v_glass.dart';
import 'package:samay/shared/widgets/rank_badge.dart';
import 'package:samay/shared/widgets/skeletons.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _selectedTier = 'micro';

  final _tiers = ['micro', 'small', 'medium', 'large'];

  /// XL-17 (09_groups: violet at one accent per screen): the podium hero
  /// glow + the display voice carry the violet; the tier chips drop to the
  /// neutral white treatment and non-podium rows to plain hairlines.
  late final AppGradient _watered = AppGradients.wateredFamily(
    AppGradients.violet,
    mix: 0.4,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rankingsAsync = ref.watch(leaderboardProvider(_selectedTier));
    final rankings = rankingsAsync.valueOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.groupsLeaderboardTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _tiers
                    .map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: VChip(
                          label: t,
                          selected: _selectedTier == t,
                          onSelected: () => setState(() => _selectedTier = t),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          Expanded(
            // U-22 (§5.8): the first load shows the avatar+lines skeleton
            // instead of the bare spinner. `valueOrNull == null` keeps the
            // ranking list visible during pull-to-refresh and tier switches
            // that rebuild an already-loaded provider — the skeleton only
            // stands in when there is nothing on screen.
            child: rankings == null && rankingsAsync.isLoading
                ? const VSkeletonList(rows: 8)
                : VStateView(
                    error: rankingsAsync.error,
                    errorMessage: rankingsAsync.hasError
                        ? rankingsAsync.error!.toAppError().message
                        : null,
                    onRetry: () =>
                        ref.invalidate(leaderboardProvider(_selectedTier)),
                    empty: VEmptyView(
                      icon: Icons.leaderboard_outlined,
                      title: l10n.groupsNoRankingData,
                    ),
                    child: rankings == null || rankings.isEmpty
                        ? null
                        : RefreshIndicator(
                            onRefresh: () => ref
                                .read(
                                  leaderboardProvider(_selectedTier).notifier,
                                )
                                .refresh(),
                            child: ListView.builder(
                              itemCount: rankings.length,
                              itemBuilder: (_, i) {
                                final entry = rankings[i];
                                final g = entry.group;
                                final rank = entry.rankPosition;
                                // LUXE: the podium (top-3) rows get the
                                // violet VDisplayText name inside a glass
                                // card; the RankBadge keeps its gold/silver/
                                // bronze semantic accent (U-05 handoff).
                                final podium = rank >= 1 && rank <= 3;
                                final tile = ListTile(
                                  leading: SizedBox(
                                    width: 32,
                                    child: Text(
                                      '#$rank',
                                      style: Theme.of(
                                        context,
                                      ).textTheme.bodyLarge,
                                    ),
                                  ),
                                  title: podium
                                      ? VDisplayText(
                                          text: g.name.isEmpty
                                              ? l10n.commonGroup
                                              : g.name,
                                          size: 28,
                                          gradient: AppGradients.violet,
                                        )
                                      : Text(
                                          g.name.isEmpty
                                              ? l10n.commonGroup
                                              : g.name,
                                        ),
                                  subtitle: Text(
                                    l10n.groupsLeaderboardSubtitle(
                                      entry.memberCount,
                                      entry.score,
                                    ),
                                  ),
                                  trailing: g.rankBracket != null
                                      ? RankBadge(
                                          bracket: g.rankBracket!,
                                          rank: podium ? rank : null,
                                        )
                                      : null,
                                  onTap: () => context.push(
                                    RoutePaths.groupDetail(g.id),
                                  ),
                                );
                                // Podium rows keep the glass hero moment
                                // (watered violet ring, whisper glow);
                                // every other row is a plain hairline row.
                                return podium
                                    ? VGlassCard(
                                        gradient: _watered,
                                        glowAlpha: 0.12,
                                        child: tile,
                                      )
                                    : tile;
                              },
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
