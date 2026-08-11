import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/shared/widgets/rank_bracket.dart';

class RankBadge extends StatelessWidget {
  final String bracket;

  const RankBadge({super.key, required this.bracket});

  @override
  Widget build(BuildContext context) {
    final label = rankBracketLabel(bracket);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        // Kept as legacy greys for visual parity; the §5.5 restyle
        // (border #333333 fill + white label, podium accents) belongs to U-05.
        color: Colors.grey[900],
        border: Border.all(color: Colors.grey[700]!),
      ),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppColors.white,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
