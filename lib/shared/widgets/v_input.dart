import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// Samay borderless input — **NO border, NO background, placeholder-only.**
///
/// User override: the radius-16 liquid-glass slab
/// is gone. The field is bare text on black — the placeholder is the only
/// cue it exists (`mutedStrong` #999, 7.37:1 — AA; turning `glowPink` on
/// error). Typed text uses the `bodyLarge` token voice, cursor white, error
/// text glowPink below (§5.2 — never raw red on black). No floating label
/// (`floatingLabelBehavior: never`): the [label] doubles as the placeholder
/// (`hint`) and disappears when the user types.
class VInput extends StatelessWidget {
  final String label;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final bool obscureText;
  final int maxLines;
  final int minLines;
  final TextAlign? textAlign;
  final TextAlignVertical? textAlignVertical;
  final Widget? suffixIcon;
  final String? fontFamily;

  const VInput({
    super.key,
    required this.label,
    this.hint,
    this.errorText,
    this.onChanged,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.maxLines = 1,
    this.minLines = 1,
    this.textAlign,
    this.textAlignVertical,
    this.suffixIcon,
    this.fontFamily,
  });

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      keyboardType: keyboardType,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: maxLines,
      textAlign: textAlign ?? TextAlign.start,
      textAlignVertical: textAlignVertical,
      cursorColor: AppColors.white,
      // `bodyLarge` input voice — clean, never styled like display copy.
      // [fontFamily] lets a caller opt into a custom family (e.g. the
      // Quicksand minigame answer voice); null keeps the role's Inter.
      style: AppTypography.bodyLarge.copyWith(
        color: AppColors.white,
        fontFamily: fontFamily,
        shadows: AppTypography.legibilityShadows,
      ),
      selectionControls: materialTextSelectionControls,
      decoration: InputDecoration(
        hintText: hint ?? label,
        errorText: errorText,
        suffixIcon: suffixIcon,
        // No border, no background — the field is bare text on black.
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        errorBorder: InputBorder.none,
        focusedErrorBorder: InputBorder.none,
        filled: false,
        floatingLabelBehavior: FloatingLabelBehavior.never,
        hintStyle: AppTypography.bodyLarge.copyWith(
          color: hasError ? AppColors.glowPink : AppColors.mutedStrong,
          fontFamily: fontFamily,
          shadows: AppTypography.legibilityShadows,
        ),
        errorStyle: const TextStyle(color: AppColors.error),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
    );
  }
}
