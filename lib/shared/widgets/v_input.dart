import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';

class VInput extends StatelessWidget {
  final String label;
  final String? hint;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final int maxLines;

  const VInput({
    super.key,
    required this.label,
    this.hint,
    this.onChanged,
    this.controller,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      obscureText: obscureText,
      maxLines: maxLines,
      style: const TextStyle(color: AppColors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        // Label keeps the legacy muted #666666 for visual parity; the design
        // doc §5.2 wants mutedStrong #999999 (fails 1.4.3 at normal size) —
        // that restyle belongs to U-05.
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: Color(0xFF444444)),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.white),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.white, width: 2),
        ),
      ),
    );
  }
}
