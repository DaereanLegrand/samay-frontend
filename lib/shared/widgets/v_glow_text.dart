import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';

/// Fancy glow text — the signature treatment as a widget
/// (DISCO-DESIGN-SYSTEM.md §3.4, owned by U-06; LUXE v2 gradient-capable).
///
/// Wraps [text] in the canonical glow shadow stack (glow-strong 3 layers or
/// glow-soft 2 layers, selected by [soft]) applied to [style]. The blur
/// radii are `em`-relative — `fontSize × factor` — exactly like the CSS
/// source `text-shadow: 0 0 0.35em/0.7em/1em var(--pink)`.
///
/// Halo color resolution: [gradient] (its vivid end) → legacy [color] →
/// the LUXE default family [AppGradients.violet]. **The default is violet,
/// never pink** (user directive 2026-08-12: pink is not the main color —
/// screens pass their own family via `AppGradients.familyOf`).
///
/// The glyph fill is left untouched (full opacity) — the halo sits strictly
/// behind the text (§7.4 legibility contract). Const-constructible: the glow
/// is computed at build time because `Color.withValues` is non-const and the
/// blur radii depend on the resolved [style] fontSize.
///
/// Not animated: glow *breathing* is [VBreathingGlow]'s scope
/// (`MediaQuery.disableAnimationsOf` gates that animation, not this widget).
class VGlowText extends StatelessWidget {
  /// The text to render with the glow treatment.
  final String text;

  /// Base style — typically a `§3.3` token (e.g. [AppTypography.displaySmall]).
  final TextStyle style;

  /// `true` → the 2-layer glow-soft stack (headlines ≥28px);
  /// `false` → the 3-layer glow-strong stack (display titles ≥32px).
  final bool soft;

  /// Halo family — its vivid end drives the shadow stack. Null → the
  /// default family [AppGradients.violet].
  final AppGradient? gradient;

  /// Legacy flat halo color override (pre-LUXE API). Used only when
  /// [gradient] is null.
  final Color? color;

  /// Optional alignment (the parent may already center the text).
  final TextAlign? textAlign;

  const VGlowText({
    super.key,
    required this.text,
    required this.style,
    this.soft = false,
    this.gradient,
    this.color,
    this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    final size = style.fontSize ?? 32;
    return Text(
      text,
      textAlign: textAlign,
      style: style.copyWith(shadows: _glowShadows(size)),
    );
  }

  /// The halo color: [gradient]'s vivid end > legacy [color] > violet.
  Color get _haloColor =>
      gradient?.colors.last ?? color ?? AppGradients.violet.colors.last;

  /// The §3.4 canonical stacks (mirror of `AppTypography.fancyTitle`):
  /// glow-strong α0.9 @ fontSize×0.35 · α0.5 @ ×0.7 · α0.25 @ ×1.0;
  /// glow-soft α0.6 @ ×0.3 · α0.25 @ ×0.6.
  List<Shadow> _glowShadows(double size) {
    final halo = _haloColor;
    if (soft) {
      return [
        Shadow(color: halo.withValues(alpha: 0.6), blurRadius: size * 0.3),
        Shadow(color: halo.withValues(alpha: 0.25), blurRadius: size * 0.6),
      ];
    }
    return [
      Shadow(color: halo.withValues(alpha: 0.9), blurRadius: size * 0.35),
      Shadow(color: halo.withValues(alpha: 0.5), blurRadius: size * 0.7),
      Shadow(color: halo.withValues(alpha: 0.25), blurRadius: size * 1.0),
    ];
  }
}
