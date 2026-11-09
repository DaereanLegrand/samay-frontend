import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/features/groups/theme/group_theme_scope.dart';
import 'package:samay/shared/widgets/rank_bracket.dart';

/// Rank-bracket badge — DESIGN.md §5.5.
///
/// `border #333333` fill + white bold 11px uppercase label, sharp. Podium
/// enhancement: pass `rank` 1–3 (leaderboard top-3 rows) to accent the border
/// and label with `discoGold`/`discoSilver`/`discoBronze` (all AA on black);
/// non-top rows stay white.
///
/// Inside a [GroupThemeScope] the fill/border/label switch to the group's
/// derived scale so the badge is a shade of the themed page instead of a black
/// box (podium colours are semantic and unchanged).
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
    final palette = GroupThemeScope.paletteOf(context);
    final themed = !identical(palette, GroupThemeScope.standardPalette);
    final fill = themed ? palette.surfaceAlt : AppColors.border;
    final edge = accent ?? (themed ? palette.border : AppColors.border);
    final ink = accent ?? (themed ? palette.foreground : AppColors.white);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: edge),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.headlineSmall.copyWith(
          color: ink,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
