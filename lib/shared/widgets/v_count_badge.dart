import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// Tiny count counter — the "pending" badge voice of the flow alignment
/// (U-16 R12; U-17 R18 reuses it for the shell tab).
///
/// `VBadge.accent`-scale (§7.2 guard rails: tiny, no new glow fills): black
/// fill, **violet-family** 1px border + `labelSmall` count text (the vivid
/// end of [AppGradients.violet] by default — never pink, LUXE directive
/// 2026-08-12; pass `gradient:` for another family). Sharp corners per
/// §4.2 (badges are in the radius-0 list — the U-24 review pass killed the
/// pill's 9px rounding). Renders nothing (zero-width `SizedBox`) when
/// [count] is 0 or negative, so callers can mount it unconditionally.
class VCountBadge extends StatelessWidget {
  final int count;

  /// LUXE accent family — its vivid end drives the border + count text.
  final AppGradient? gradient;

  const VCountBadge({super.key, required this.count, this.gradient});

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final accent = (gradient ?? AppGradients.violet).colors.last;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.discoBlack,
        border: Border.all(color: accent),
        borderRadius: AppRadius.sharp,
      ),
      child: Text(
        '$count',
        style: AppTypography.labelSmall.copyWith(color: accent),
      ),
    );
  }
}
