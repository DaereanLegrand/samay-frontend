import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// Tiny count badge for the "pending" voice — the shell tab, the
/// switch-groups icon and minigame invites.
///
/// A solid `badgeRed` circle with white `labelSmall` count text, NO border
/// ring — this one semantic element overrides the monochrome rule. Renders
/// nothing (zero-width `SizedBox`) when [count] is 0 or negative, so callers
/// can mount it unconditionally.
class VCountBadge extends StatelessWidget {
  final int count;

  const VCountBadge({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final text = '$count';
    // True circle at any digit count: the diameter grows one step per digit
    // (20px single digit, 26px two digits, 32px three…).
    final diameter = 20.0 + (text.length - 1) * 6;
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: AppColors.badgeRed,
        shape: BoxShape.circle,
      ),
      child: Text(
        text,
        style: AppTypography.labelSmall.copyWith(color: context.palette.foreground),
      ),
    );
  }
}
