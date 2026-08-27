import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';

/// Hairline divider with a centered white accent segment
/// (DESIGN.md §2.1/§4.2 spirit, owned by U-06; monochrome 2026-08-26 —
/// the accent is [AppColors.white], never a hue).
///
/// The full-width rule is the `hairline #1A1A1A` depth decoration (§2.1); a
/// short [accentWidth] segment in [accentColor] marks the middle. Flat by
/// design: no shadow stacks on boxes (§4.3). Sharp, hairline-only geometry
/// per pillar P2. Const-constructible.
class VDiscoDivider extends StatelessWidget {
  /// Line height in logical pixels.
  final double thickness;

  /// Width of the centered accent segment.
  final double accentWidth;

  /// Hairline color of the full-width rule.
  final Color color;

  /// Accent segment color — [AppColors.white] by default (monochrome).
  final Color accentColor;

  const VDiscoDivider({
    super.key,
    this.thickness = 1,
    this.accentWidth = AppSpacing.xxxl,
    this.color = AppColors.hairline,
    this.accentColor = AppColors.white,
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
