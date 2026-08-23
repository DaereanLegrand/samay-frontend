import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';

/// Hairline divider with a centered violet accent segment
/// (DESIGN.md §2.1/§4.2 spirit, owned by U-06; LUXE v2
/// "NO PINK MAINS" — the accent is [AppColors.statusVip], never pink).
///
/// The full-width rule is the `hairline #1A1A1A` depth decoration (§2.1); a
/// short [accentWidth] segment in [accentColor] marks the middle — the
/// violet family accent ([AppColors.statusVip], the semantic alias of the
/// violet vivid end). A 1px segment cannot carry a gradient (a gradient on a
/// hairline is invisible), so the accent stays a flat token color. Flat by
/// design: no shadow stacks on boxes (§4.3 — glow is reserved for brand
/// moments, a divider is chrome). Sharp, hairline-only geometry per pillar
/// P2. Const-constructible.
class VDiscoDivider extends StatelessWidget {
  /// Line height in logical pixels.
  final double thickness;

  /// Width of the centered accent segment.
  final double accentWidth;

  /// Hairline color of the full-width rule.
  final Color color;

  /// Accent segment color — the violet family's [AppColors.statusVip] by
  /// default (LUXE directive 2026-08-12: never pink).
  final Color accentColor;

  const VDiscoDivider({
    super.key,
    this.thickness = 1,
    this.accentWidth = AppSpacing.xxxl,
    this.color = AppColors.hairline,
    this.accentColor = AppColors.statusVip,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: thickness,
      child: Row(
        children: [
          Expanded(
            child: Container(height: thickness, color: color),
          ),
          Container(width: accentWidth, height: thickness, color: accentColor),
          Expanded(
            child: Container(height: thickness, color: color),
          ),
        ],
      ),
    );
  }
}
