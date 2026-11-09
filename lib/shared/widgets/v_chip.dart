import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/theme/app_theme_scope.dart';

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
    final palette = AppThemeScope.paletteOf(context);
    final themed = AppThemeScope.isThemed(context);
    // Inside a themed group surface the chip's "ink" is the group foreground,
    // so unselected chips stay legible and selected chips invert correctly.
    final ink = themed ? palette.foreground : AppColors.white;
    final selectedInk = themed ? palette.background : AppColors.discoBlack;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) => onSelected?.call(),
      // Material 3 would paint a `surfaceContainerLow` fill + elevation tint;
      // both read as a BLACK box on a coloured group page.
      elevation: 0,
      surfaceTintColor: AppColors.transparent,
      shadowColor: AppColors.transparent,
      labelStyle: textStyle?.copyWith(
        color: selected ? selectedInk : ink,
      ),
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
      // `color` is the HIGHEST-precedence fill in Material 3 (`widget.color ??
      // chipTheme.color` beats `backgroundColor`), so an unselected chip that
      // only sets `backgroundColor: transparent` still falls back to the M3
      // `surfaceContainerLow` default and paints a black box on a coloured page.
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? ink
            : AppColors.transparent,
      ),
      selectedColor: ink,
      backgroundColor: AppColors.transparent,
      side: BorderSide(color: ink),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.sharp),
      showCheckmark: false,
    );
  }

  /// Bare (non-theme) label colour — kept for callers/tests; the widget itself
  /// resolves the themed pair in [build].
  Color get labelColor => selected ? AppColors.discoBlack : AppColors.white;
}
