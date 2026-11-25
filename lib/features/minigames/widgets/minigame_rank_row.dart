import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/features/minigames/widgets/minigame_session_surface.dart';

/// One row of a ranking in the leaderboard cards' voice: a fixed-width,
/// right-aligned Playfair rank numeral (podium gold/silver/bronze, the page's
/// foreground otherwise) beside the player's name over their meta line.
///
/// This is the list-sized rendition of the finished-leaderboard card footer
/// (`_CardFooter` in `finished_leaderboard.dart`): the same numeral metrics,
/// the same name/meta rhythm, so a local history and a match leaderboard read as
/// one family.
class MinigameRankRow extends StatelessWidget {
  const MinigameRankRow({
    super.key,
    required this.rank,
    required this.name,
    this.meta,
    this.divider = true,
  });

  /// 1-based position in the ranking.
  final int rank;

  final String name;

  /// Secondary line (score, wins, category…). Null renders a single line.
  final String? meta;

  /// Paints a trailing hairline under the row (list separator).
  final bool divider;

  Color _rankColor(BuildContext context) => switch (rank) {
    1 => AppColors.discoGold,
    2 => AppColors.discoSilver,
    3 => AppColors.discoBronze,
    _ => MinigameInks.of(context).primary,
  };

  @override
  Widget build(BuildContext context) {
    final metaStyle = Theme.of(
      context,
    ).textTheme.bodySmall?.copyWith(color: MinigameInks.of(context).muted);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            child: Align(
              alignment: Alignment.centerRight,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '$rank',
                  style: AppTypography.displayLarge.copyWith(
                    // Playfair's ascender/descender padding makes the glyph read
                    // smaller; a tight line height lets the numeral's cap
                    // dominate.
                    fontSize: 58,
                    height: 0.9,
                    color: _rankColor(context),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (meta != null && meta!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    meta!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: metaStyle,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
    if (!divider) return row;
    return Column(
      children: [
        row,
        Container(height: 1, color: MinigameInks.of(context).hairline),
      ],
    );
  }
}
