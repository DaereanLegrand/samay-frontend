import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/services/storage_service.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/features/minigames/local/local_match_store.dart';
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The pass-the-phone history as a leaderboard.
///
/// Every finished local match already persists a [LocalMatchSummary] to the
/// encrypted `minigame_summary_cache` box; this screen only aggregates it:
/// total wins per player across every game, with the games-played count and the
/// last results underneath. No backend, so it works offline like the games.
class LocalHistory {
  const LocalHistory({
    required this.rows,
    required this.matches,
    required this.recent,
  });

  /// `(name, wins, games)` best first.
  final List<({String name, int wins, int games})> rows;
  final int matches;
  final List<LocalMatchSummary> recent;

  static const empty = LocalHistory(rows: [], matches: 0, recent: []);
}

/// Reads every saved summary and aggregates the standings.
final localHistoryProvider = FutureProvider<LocalHistory>((ref) async {
  try {
    final store = HiveLocalMatchStore(
      openBox: () async =>
          Hive.box<String>(HiveService.minigameSummaryBoxName),
    );
    final summaries = await store.recent();
    if (summaries.isEmpty) return LocalHistory.empty;

    final wins = <String, int>{};
    final games = <String, int>{};
    for (final summary in summaries) {
      // A summary with no scores (or every score tied) has no winner.
      final entries = summary.scores.entries.toList();
      if (entries.isEmpty) continue;
      entries.sort((a, b) => b.value.compareTo(a.value));
      final top = entries.first.value;
      final unique = entries.length == 1 || entries[1].value < top;
      for (final entry in entries) {
        games[entry.key] = (games[entry.key] ?? 0) + 1;
      }
      if (unique && top > 0) {
        wins[entries.first.key] = (wins[entries.first.key] ?? 0) + 1;
      }
    }
    final rows = [
      for (final name in games.keys)
        (name: name, wins: wins[name] ?? 0, games: games[name] ?? 0),
    ]..sort((a, b) {
        final byWins = b.wins.compareTo(a.wins);
        if (byWins != 0) return byWins;
        return b.games.compareTo(a.games);
      });
    return LocalHistory(
      rows: rows,
      matches: summaries.length,
      recent: summaries.take(10).toList(),
    );
  } catch (_) {
    return LocalHistory.empty;
  }
});

class LocalLeaderboardScreen extends ConsumerWidget {
  const LocalLeaderboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(localHistoryProvider);
    final history = async.valueOrNull ?? LocalHistory.empty;

    return Scaffold(
      backgroundColor: context.palette.background,
      body: VHeaderBar(
        titleWidget: MinigameHeaderTitle(word: l10n.minigamesLeaderboardTitle),
        child: async.isLoading
            ? const Center(child: CircularProgressIndicator())
            : history.rows.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Text(
                    l10n.minigamesLeaderboardEmpty,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: context.palette.mutedForeground,
                    ),
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenHorizontal,
                ),
                children: [
                  const SizedBox(height: AppSpacing.lg),
                  Text(
                    l10n.minigamesLeaderboardGames(history.matches).toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (var i = 0; i < history.rows.length; i++)
                    _RankRow(
                      rank: i + 1,
                      name: history.rows[i].name,
                      wins: history.rows[i].wins,
                      games: history.rows[i].games,
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    l10n.minigamesLocalPlayAgain.toUpperCase(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final summary in history.recent) _RecentRow(summary: summary),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.name,
    required this.wins,
    required this.games,
  });

  final int rank;
  final String name;
  final int wins;
  final int games;

  Color? get _podium => switch (rank) {
    1 => AppColors.discoGold,
    2 => AppColors.discoSilver,
    3 => AppColors.discoBronze,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final accent = _podium;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        border: Border.all(
          color: accent ?? context.palette.hairline,
          width: accent == null ? 1 : 2,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 26,
            child: Text(
              '$rank',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: accent ?? context.palette.mutedForeground,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
          Text(
            '$wins',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            '/ $games',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.palette.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.summary});

  final LocalMatchSummary summary;

  @override
  Widget build(BuildContext context) {
    final top = summary.scores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              summary.playerNames.join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: context.palette.mutedForeground,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            summary.gameType.value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.palette.mutedForeground,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            top.isEmpty ? '—' : '${top.first.key} ${top.first.value}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
