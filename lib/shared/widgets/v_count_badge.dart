import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// Tiny count counter — the "pending" badge voice of the flow alignment
/// (U-16 R12; U-17 R18 reuses it for the shell tab; the switch-groups icon
/// and the shell badge reuse it for minigame invites).
///
/// RED CIRCLE (user directive 2026-08-27 — overrides the monochrome rule
/// for this one semantic element): a solid `badgeRed` circle with white
/// `labelSmall` count text, NO border ring. The previous violet sharp-square
/// (and its white-bordered red variant) are gone. Renders nothing
/// (zero-width `SizedBox`) when [count] is 0 or negative, so callers can
/// mount it unconditionally.
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
        style: AppTypography.labelSmall.copyWith(color: AppColors.white),
      ),
    );
  }
}
