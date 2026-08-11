import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';

/// Samay chip — DISCO-DESIGN-SYSTEM.md §5.4 (U-05).
///
/// Default: transparent fill, 1px white border, white `labelMedium` label;
/// selected = white fill + black label. `VChip.accent`: 1px `glowPink` border
/// + pink label; selected = `glowPink` fill + black label. Sharp corners.
class VChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onSelected;
  final bool accent;

  const VChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.accent = false,
  });

  /// §5.4 accent chip — pink border + pink label, pink fill when selected.
  const VChip.accent({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
  }) : accent = true;

  @override
  Widget build(BuildContext context) {
    final borderColor = accent ? AppColors.glowPink : AppColors.white;
    final labelColor = selected ? AppColors.discoBlack : borderColor;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) => onSelected?.call(),
      labelStyle: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: labelColor),
      selectedColor: accent ? AppColors.glowPink : AppColors.white,
      backgroundColor: Colors.transparent,
      side: BorderSide(color: borderColor),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sharp),
      showCheckmark: false,
    );
  }
}
