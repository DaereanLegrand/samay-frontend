import 'package:flutter/material.dart';

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
        color: selected ? Colors.black : Colors.white,
      ),
      selectedColor: Colors.white,
      backgroundColor: Colors.transparent,
      side: const BorderSide(color: Colors.white),
      shape: const RoundedRectangleBorder(),
      showCheckmark: false,
    );
  }
}
