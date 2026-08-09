import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';

class VChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  const VChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (value) => onSelected?.call(),
      labelStyle: TextStyle(
        color: selected ? AppColors.discoBlack : AppColors.white,
      ),
      selectedColor: AppColors.white,
      backgroundColor: Colors.transparent,
      side: const BorderSide(color: AppColors.white),
      shape: const RoundedRectangleBorder(),
      showCheckmark: false,
    );
  }
}
