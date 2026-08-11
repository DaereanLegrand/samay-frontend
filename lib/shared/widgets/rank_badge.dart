import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/shared/widgets/rank_bracket.dart';

/// Rank-bracket badge — DISCO-DESIGN-SYSTEM.md §5.5 (U-05).
///
/// `border #333333` fill + white bold 11px uppercase label, sharp. Podium
/// enhancement: pass `rank` 1–3 (leaderboard top-3 rows) to accent the border
/// and label with `discoGold`/`discoSilver`/`discoBronze` (all AA on black);
/// non-top rows stay white.
class RankBadge extends StatelessWidget {
  final String bracket;
  final int? rank;

  const RankBadge({super.key, required this.bracket, this.rank});

  @override
  Widget build(BuildContext context) {
    final label = rankBracketLabel(bracket);
    final Color? accent = switch (rank) {
      1 => AppColors.discoGold,
      2 => AppColors.discoSilver,
      3 => AppColors.discoBronze,
      _ => null,
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.border,
        border: Border.all(color: accent ?? AppColors.border),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: accent ?? AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
