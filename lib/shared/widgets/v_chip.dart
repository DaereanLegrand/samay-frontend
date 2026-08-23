import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_radius.dart';

/// Samay chip — DESIGN.md §5.4 (U-05), LUXE v2 gradient-capable
/// (the LUXE restyle pass (historical) "NO PINK MAINS", 2026-08-12).
///
/// Default: transparent fill, 1px white border, white `labelMedium` label;
/// selected = white fill + black label. `VChip.accent`: 1px **violet**-family
/// border + violet label (the vivid end of [AppGradients.violet] by default,
/// or the passed `gradient:` family); selected = vivid fill + black label.
/// Sharp corners.
class VChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final bool accent;

  /// LUXE accent family — its vivid end drives the accent border/label/fill.
  /// Null (accent variant) → [AppGradients.violet], never pink.
  final AppGradient? gradient;

  const VChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.accent = false,
    this.gradient,
  });

  /// §5.4 accent chip — violet-family border + label, vivid fill when
  /// selected (pass `gradient:` to adopt another family).
  const VChip.accent({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.gradient,
  }) : accent = true;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent
        ? (gradient ?? AppGradients.violet).colors.last
        : null;
    final borderColor = accentColor ?? AppColors.white;
    final labelColor = selected ? AppColors.discoBlack : borderColor;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) => onSelected?.call(),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: labelColor),
      selectedColor: accentColor ?? AppColors.white,
      backgroundColor: Colors.transparent,
      side: BorderSide(color: borderColor),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sharp),
      showCheckmark: false,
    );
  }
}
