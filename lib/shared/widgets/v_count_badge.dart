import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// Tiny count counter — the "pending" badge voice of the flow alignment
/// (U-16 R12; U-17 R18 reuses it for the shell tab).
///
/// `VBadge.accent`-scale (§7.2 guard rails: tiny, no new glow fills): black
/// fill, `glowPink` 1px border + `labelSmall` count text. Renders nothing
/// (zero-width `SizedBox`) when [count] is 0 or negative, so callers can
/// mount it unconditionally.
class VCountBadge extends StatelessWidget {
  final int count;

  const VCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.discoBlack,
        border: Border.all(color: AppColors.glowPink),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        '$count',
        style: AppTypography.labelSmall.copyWith(color: AppColors.glowPink),
      ),
    );
  }
}
