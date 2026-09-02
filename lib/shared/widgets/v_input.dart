import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';

/// Samay borderless input — **NO border, NO background, placeholder-only.**
///
/// User override (2026-08-18): the radius-16 liquid-glass slab (LUXE §4.3)
/// is gone. The field is bare text on black — the placeholder is the only
/// cue it exists (`mutedStrong` #999, 7.37:1 — AA; turning `glowPink` on
/// error). Typed text stays white 17px iOS-native, cursor white, error text
/// glowPink below (§5.2 — never raw red on black). No floating label
/// (`floatingLabelBehavior: never`): the [label] doubles as the placeholder
/// (`hint`) and disappears when the user types.
class VInput extends StatelessWidget {
  final String label;
  final String? hint;
  final String? errorText;
  final ValueChanged<String>? onChanged;
  final TextEditingController? controller;
  final TextInputType keyboardType;
  final bool obscureText;
  final int maxLines;
  final int minLines;
  final TextAlignVertical? textAlignVertical;
  final Widget? suffixIcon;

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
    this.minLines = 1,
    this.textAlignVertical,
    this.suffixIcon,
  });

  /// Vestigial liquid-glass geometry (LUXE §4.3). Retained so the
  /// still-to-be-updated widget tests keep compiling; nothing renders these.
  static const BorderRadius radius = BorderRadius.all(Radius.circular(16));

  /// Vestigial — see [radius].
  static const Duration shellDuration = Duration(milliseconds: 200);

  /// Vestigial — see [radius].
  static const Key glassShellKey = ValueKey('vInputGlassShell');

  /// Vestigial — see [radius].
  static const Key glassFillKey = ValueKey('vInputGlassFill');

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      keyboardType: keyboardType,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: maxLines,
      textAlignVertical: textAlignVertical,
      cursorColor: AppColors.white,
      // iOS-native 17px input voice — clean, never styled like display copy.
      style: const TextStyle(
        color: AppColors.white,
        fontSize: 17,
        fontWeight: FontWeight.w400,
        height: 1.35,
        letterSpacing: 0.0,
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
        hintStyle: TextStyle(
          color: hasError ? AppColors.glowPink : AppColors.mutedStrong,
          fontSize: 17,
          fontWeight: FontWeight.w400,
          height: 1.35,
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
