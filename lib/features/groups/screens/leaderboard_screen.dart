import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/rank_badge.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_chip.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  String _selectedTier = 'micro';

  final _tiers = ['micro', 'small', 'medium', 'large'];

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
                children: _tiers.map((t) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: VChip(
                    label: t,
                    selected: _selectedTier == t,
                    onSelected: () => setState(() => _selectedTier = t),
                  ),
                )).toList(),
              ),
            ),
          ),
          Expanded(
            child: VStateView(
              loading: rankingsAsync.isLoading,
              error: rankingsAsync.error,
              errorMessage: rankingsAsync.hasError
                  ? rankingsAsync.error!.toAppError().message
                  : null,
              onRetry: () => ref.invalidate(leaderboardProvider(_selectedTier)),
              empty: VEmptyView(
                icon: Icons.leaderboard_outlined,
                title: l10n.groupsNoRankingData,
              ),
              child: rankings == null || rankings.isEmpty
                  ? null
                  : RefreshIndicator(
                      onRefresh: () => ref
                          .read(leaderboardProvider(_selectedTier).notifier)
                          .refresh(),
                      child: ListView.builder(
                        itemCount: rankings.length,
                        itemBuilder: (_, i) {
                          final g = rankings[i];
                          return ListTile(
                            leading: SizedBox(
                              width: 32,
                              child: Text(
                                '#${g['rank_position']}',
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            ),
                            title: Text(g['name'] as String? ?? l10n.commonGroup),
                            subtitle: Text(
                              l10n.groupsLeaderboardSubtitle(
                                (g['member_count'] as num?)?.toInt() ?? 0,
                                (g['score'] as num?)?.toInt() ?? 0,
                              ),
                            ),
                            trailing: g['rank_bracket'] != null
                                ? RankBadge(bracket: g['rank_bracket'] as String)
                                : null,
                            onTap: () => context.push(RoutePaths.groupDetail(g['id'] as String)),
                          );
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
