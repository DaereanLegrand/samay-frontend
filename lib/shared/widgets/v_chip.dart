import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';

/// Samay chip — DESIGN.md §5.4, monochrome
///
/// Transparent fill, 1px white border, white `labelMedium` label;
/// selected = white fill + black label. Sharp corners.
/// [compact]: reduced height/width/padding with a
/// `labelSmall` label — for the Directa/Grupo toggle so it stays slim.
class VChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  /// Compact mode: tighter tap target + smaller padding + `labelSmall` text.
  final bool compact;

  const VChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = compact
        ? Theme.of(context).textTheme.labelSmall
        : Theme.of(context).textTheme.labelMedium;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) => onSelected?.call(),
      labelStyle: textStyle?.copyWith(color: labelColor),
      labelPadding: compact
          ? const EdgeInsets.symmetric(horizontal: 2)
          : null,
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 6, vertical: 0)
          : null,
      materialTapTargetSize: compact
          ? MaterialTapTargetSize.shrinkWrap
          : MaterialTapTargetSize.padded,
      visualDensity: compact ? VisualDensity.compact : VisualDensity.standard,
      selectedColor: AppColors.white,
      backgroundColor: AppColors.transparent,
      side: const BorderSide(color: AppColors.white),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sharp),
      showCheckmark: false,
    );
  }

  Color get labelColor => selected ? AppColors.discoBlack : AppColors.white;
}
