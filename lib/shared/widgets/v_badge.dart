import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// Samay badge — DISCO-DESIGN-SYSTEM.md §5.5 (U-05).
///
/// Default: sharp, `border #333333` fill + white `labelSmall` text (the
/// shape+fill+text identify the badge — the text carries the info). Variants:
///
/// * `VBadge.emphasized` — white fill + black text.
/// * `VBadge.accent(color:)` — status badge: accent border + same-color text,
///   fill stays black. Accent *fills* are reserved for NEW/LIVE urgency with
///   black text (pass `color:` directly for that).
///
/// Labels render uppercase per the §3.3 `labelSmall` role.
class VBadge extends StatelessWidget {
  final String label;

  /// Fill override (emphasized-style colored fill + black text).
  final Color? color;

  /// Status accent: border + label in this color, black fill.
  final Color? accent;

  final bool emphasized;

  const VBadge({super.key, required this.label, this.color})
    : accent = null,
      emphasized = false;

  const VBadge.emphasized({super.key, required this.label})
    : color = null,
      accent = null,
      emphasized = true;

  const VBadge.accent({super.key, required this.label, required Color color})
    : color = null,
      accent = color,
      emphasized = false;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color textColor;
    final Color borderColor;
    final accentColor = accent;
    if (accentColor != null) {
      fill = AppColors.discoBlack;
      textColor = accentColor;
      borderColor = accentColor;
    } else if (emphasized) {
      fill = AppColors.white;
      textColor = AppColors.discoBlack;
      borderColor = AppColors.white;
    } else {
      fill = color ?? AppColors.border;
      textColor = color != null ? AppColors.discoBlack : AppColors.white;
      borderColor = color ?? AppColors.border;
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: borderColor),
        borderRadius: AppRadius.sharp,
      ),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(color: textColor),
      ),
    );
  }
}
