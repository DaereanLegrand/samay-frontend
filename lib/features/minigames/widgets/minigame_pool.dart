import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_shard_icon.dart';

/// The TOTAL prize pool of a partida — [wager] shards per player times the
/// live [players] count — rendered as a bare shard diamond + number.
///
/// The pool must never be labelled with the literals
/// "apuesta" / "shards"; the icon carries the currency. The amount is always
/// derived from the caller's LIVE session row, so it recomputes the moment a
/// participant joins (the `minigame_sessions` realtime UPDATE).
///
/// Tapping opens [showMinigamePoolBreakdown] — the rank → payout explanation.
class MinigamePoolAmount extends StatelessWidget {
  const MinigamePoolAmount({
    super.key,
    required this.wager,
    required this.players,
    required this.positions,
    this.onTap,
    this.iconSize = AppIconSizes.sm,
    this.style,
    this.color = AppColors.white,
    this.fontWeight = FontWeight.w700,
  });

  /// Shards each player put in (0 = free partida).
  final int wager;

  /// Live participant count.
  final int players;

  /// Paid prize positions frozen at creation (session `n`).
  final int positions;

  /// When non-null the row becomes tappable (opens the breakdown).
  final VoidCallback? onTap;

  final double iconSize;
  final TextStyle? style;
  final Color color;
  final FontWeight fontWeight;

  /// The pool: wager × players (0 for a free partida).
  int get pot => wager <= 0 ? 0 : wager * players;

  @override
  Widget build(BuildContext context) {
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        VShardIcon(size: iconSize),
        const SizedBox(width: AppSpacing.xs),
        Text(
          '$pot',
          style: (style ?? AppTypography.titleMedium).copyWith(
            color: color,
            fontWeight: fontWeight,
          ),
        ),
      ],
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }
}

/// Opens the pool explanation: the HARMONIC rank → payout split (the same
/// integer math the server settles with), or a single "no prize" line for a
/// free partida. Uses the session's frozen prize positions [positions] capped
/// at [players].
Future<void> showMinigamePoolBreakdown(
  BuildContext context, {
  required int wager,
  required int players,
  required int positions,
}) {
  final l10n = AppLocalizations.of(context);
  final pot = wager <= 0 ? 0 : wager * players;
  final prizes = pot <= 0
      ? const <int>[]
      : harmonicPrizes(pot, positions: positions, playerCount: players);
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.minigamesPoolBreakdownTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: MinigamePoolAmount(
              wager: wager,
              players: players,
              positions: positions,
              iconSize: AppIconSizes.md,
              style: AppTypography.headlineSmall,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (prizes.isEmpty)
            Text(
              l10n.minigamesPoolNoPrize,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.mutedStrong),
            )
          else
            for (var i = 0; i < prizes.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    Text(
                      l10n.minigamesPoolRank(i + 1),
                      style: const TextStyle(
                        color: AppColors.mutedStrong,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    const VShardIcon(size: AppIconSizes.sm),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${prizes[i]}',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.commonClose),
        ),
      ],
    ),
  );
}
