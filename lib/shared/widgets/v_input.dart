import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// Samay underline input — DISCO-DESIGN-SYSTEM.md §5.2 (U-05).
///
/// Underline style: no box, no border radius, 1px white bottom rule; focused =
/// 2px white rule. Labels are `mutedStrong #999999` (AA — the doc's fix from
/// `muted`, §2.4), hints are `muted #666666` (allowed — placeholders are
/// re-declared by the white field text). Text is white `bodyLarge`. Error text
/// is `glowPink` (§5.2 — never raw red on black).
class VInput extends StatelessWidget {
  final String label;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final int maxLines;

  const VInput({
    super.key,
    required this.label,
    this.hint,
    this.errorText,
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
      style: AppTypography.bodyLarge.copyWith(color: AppColors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        errorText: errorText,
        labelStyle: const TextStyle(color: AppColors.mutedStrong),
        hintStyle: const TextStyle(color: AppColors.muted),
        errorStyle: const TextStyle(color: AppColors.error),
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
