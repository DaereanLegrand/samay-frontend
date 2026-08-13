import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// Samay badge — DISCO-DESIGN-SYSTEM.md §5.5 (U-05), LUXE v2 gradient-
/// capable (ORCHESTRATION-LUXE.md "NO PINK MAINS", 2026-08-12).
///
/// Default: sharp, `border #333333` fill + white `labelSmall` text (the
/// shape+fill+text identify the badge — the text carries the info). Variants:
///
/// * `VBadge.emphasized` — white fill + black text.
/// * `VBadge.accent` — LUXE status badge. Pass `gradient:` (default
///   [AppGradients.violet]) for the family accent: pale watered fill
///   (`AppGradients.watered`), mid-stop border, black label. The legacy
///   flat `color:` accent (accent border + same-color text on black fill)
///   stays supported. Accent *fills* are reserved for NEW/LIVE urgency.
///
/// The accent family default is **violet — never pink** (user directive
/// 2026-08-12: pink is not the main color).
///
/// Labels render uppercase per the §3.3 `labelSmall` role.
class VBadge extends StatelessWidget {
  final String label;

  /// Fill override (emphasized-style colored fill + black text).
  final Color? color;

  /// Status accent: border + label in this color, black fill (legacy flat
  /// accent — set by [VBadge.accent]'s `color:` parameter).
  final Color? accent;

  /// LUXE accent family ([VBadge.accent]'s `gradient:` parameter): pale
  /// watered fill, mid-stop border, black label. Defaults to
  /// [AppGradients.violet] for the accent variant.
  final AppGradient? gradient;

  final bool emphasized;

  /// True when constructed via [VBadge.accent] — the only variant that
  /// resolves a default family.
  final bool _accentVariant;

  const VBadge({super.key, required this.label, this.color})
    : accent = null,
      gradient = null,
      emphasized = false,
      _accentVariant = false;

  const VBadge.emphasized({super.key, required this.label})
    : color = null,
      accent = null,
      gradient = null,
      emphasized = true,
      _accentVariant = false;

  const VBadge.accent({
    super.key,
    required this.label,
    this.color,
    this.gradient,
  }) : accent = color,
       emphasized = false,
       _accentVariant = true;

  @override
  Widget build(BuildContext context) {
    // LUXE accent: an explicit gradient wins; a legacy flat `color:` accent
    // keeps its old behavior; only a bare accent (no color, no gradient)
    // defaults to the violet family — never pink (2026-08-12 directive).
    final family = gradient ?? (accent == null && _accentVariant ? AppGradients.violet : null);
    final Color fill;
    final Color textColor;
    final Color borderColor;
    if (family != null) {
      fill = AppGradients.watered(family.colors).first;
      textColor = AppColors.discoBlack;
      borderColor = family.colors[1];
    } else if (accent != null) {
      fill = AppColors.discoBlack;
      textColor = accent!;
      borderColor = accent!;
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
