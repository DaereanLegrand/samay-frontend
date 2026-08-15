import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// Samay liquid-glass input — LUXE v2 (XL-03).
///
/// Replaces the old underline field (underline inputs are "outdated" — LUXE
/// directive #7): the field is a radius-16 glass slab —
///
/// * outer `AnimatedContainer` (200ms): 1px gradient border ring via the
///   double-container trick (outer gradient + inner fill), a soft white
///   glow shadow on focus (α0.12, blur 24), and a subtle neumorphic top
///   highlight on the inner fill (white α0.04);
/// * fill: `surfaceAlt` α0.5;
/// * the label is ALWAYS visible above the field
///   (`floatingLabelBehavior: always`, `labelSmall` voice — mutedStrong,
///   white on focus, glowPink on error); hint `muted`, text white, cursor
///   white, error text glowPink (§5.2 — never raw red on black).
///
/// Border states: default white α0.25; focused → neutral white gradient
/// (α0.8 top-left → α0.25); error → glowPink α0.8. Feature agents theme the
/// border per-screen gradient later — this stays neutral white.
class VInput extends StatefulWidget {
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

  /// Glass shell geometry.
  static const BorderRadius radius = BorderRadius.all(Radius.circular(16));

  /// Border + fill animation duration (LUXE input transition).
  static const Duration shellDuration = Duration(milliseconds: 200);

  /// Key of the outer gradient-border shell (tests pin the glass visuals).
  static const Key glassShellKey = ValueKey('vInputGlassShell');

  /// Key of the inner fill slab.
  static const Key glassFillKey = ValueKey('vInputGlassFill');

  @override
  State<VInput> createState() => _VInputState();
}

class _VInputState extends State<VInput> {
  final FocusNode _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    if (_focused != hasFocus) {
      setState(() => _focused = hasFocus);
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasError = widget.errorText != null;
    // ANIM-OFF (2026-08-14): zero-duration under reduced motion — the glass
    // ring swaps instantly instead of animating.
    final shellDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : VInput.shellDuration;
    return AnimatedContainer(
      key: VInput.glassShellKey,
      duration: shellDuration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _borderColors(),
        ),
        borderRadius: VInput.radius,
        boxShadow: _focused && !hasError
            ? [
                BoxShadow(
                  color: AppColors.white.withValues(alpha: 0.12),
                  blurRadius: 24,
                ),
              ]
            : const [],
      ),
      padding: const EdgeInsets.all(1),
      child: AnimatedContainer(
        key: VInput.glassFillKey,
        duration: shellDuration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(15),
        ),
        // Neumorphic top highlight: a hairline of light falling on the rim.
        foregroundDecoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.white.withValues(alpha: 0.04),
              AppColors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.4],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: TextField(
          controller: widget.controller,
          onChanged: widget.onChanged,
          keyboardType: widget.keyboardType,
          obscureText: widget.obscureText,
          maxLines: widget.maxLines,
          focusNode: _focusNode,
          cursorColor: AppColors.white,
          // LUXE input voice: iOS-native 17px, normal weight, airy line
          // height — no letter-spacing tricks (input text must read clean,
          // never styled like display copy).
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 17,
            fontWeight: FontWeight.w400,
            height: 1.35,
            letterSpacing: 0.0,
          ),
          selectionControls: materialTextSelectionControls,
          decoration: InputDecoration(
            labelText: widget.label,
            hintText: widget.hint,
            errorText: widget.errorText,
            // The glass shell draws the border — no decoration border.
            border: InputBorder.none,
            filled: false,
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: AppTypography.labelMedium.copyWith(
              color: _labelColor(),
              fontWeight: FontWeight.w500,
            ),
            hintStyle: const TextStyle(
              color: AppColors.mutedStrong,
              fontSize: 17,
              fontWeight: FontWeight.w400,
              height: 1.35,
            ),
            errorStyle: const TextStyle(color: AppColors.error),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: 18,
            ),
          ),
        ),
      ),
    );
  }

  /// Label state color: error wins, then focus, else the rest `mutedStrong`.
  Color _labelColor() {
    if (widget.errorText != null) return AppColors.glowPink;
    if (_focused) return AppColors.white;
    return AppColors.mutedStrong;
  }

  /// The 1px ring gradient: default white α0.25; focused → the neutral
  /// white diagonal (α0.8 → α0.25); error → glowPink α0.8.
  List<Color> _borderColors() {
    if (widget.errorText != null) {
      return [
        AppColors.glowPink.withValues(alpha: 0.8),
        AppColors.glowPink.withValues(alpha: 0.8),
      ];
    }
    if (_focused) {
      return [
        AppColors.white.withValues(alpha: 0.8),
        AppColors.white.withValues(alpha: 0.25),
      ];
    }
    return [
      AppColors.white.withValues(alpha: 0.25),
      AppColors.white.withValues(alpha: 0.25),
    ];
  }
}
