import 'package:flutter/material.dart';

/// Samay elevation tokens — **flat** by design (DESIGN.md §4.3,
/// owned by U-03).
///
/// No drop shadows on boxes: surfaces are flat with hairline borders. The
/// only shadows in the system are the brand **glow** stacks, used strictly
/// for brand moments (featured card behind a CTA, live indicators, QR scanner
/// ring) — never for ordinary cards.
abstract final class AppElevation {
  /// No shadow.
  static const List<BoxShadow> none = [];

  /// Flat card: no shadow — a `#1A1A1A` hairline border carries the geometry.
  static const List<BoxShadow> card = [];

  /// Brand glow — pink stack (design doc §4.3): two layered halos at
  /// `glowPink` α0.45 (blur 24) + α0.2 (blur 48). Brand moments only.
  ///
  /// The alphas are composited into const hexes (`0x73` = 115/255 ≈ 0.45,
  /// `0x33` = 51/255 = 0.2 exactly) rather than
  /// `AppColors.glowPink.withValues(alpha: …)`: `Color.withValues` is a
  /// non-const instance method, so it would drop these lists from
  /// `static const` (U-01's handoff evaluated 2026-08-11 — rendered output
  /// is identical within 8-bit alpha quantization, but const-ness is a
  /// token-contract property; see the U-03 daily log).
  static const List<BoxShadow> glowPink = [
    BoxShadow(
      color: Color(0x73FF2E88), // AppColors.glowPink α0.45
      blurRadius: 24,
    ),
    BoxShadow(
      color: Color(0x33FF2E88), // AppColors.glowPink α0.20
      blurRadius: 48,
    ),
  ];

  /// Brand glow — cyan stack (§4.3): same layering with `discoCyan`.
  /// Live indicators, QR scanner ring. Const composited hexes for the same
  /// reason as [glowPink] (see above).
  static const List<BoxShadow> glowCyan = [
    BoxShadow(
      color: Color(0x7300E5FF), // AppColors.discoCyan α0.45
      blurRadius: 24,
    ),
    BoxShadow(
      color: Color(0x3300E5FF), // AppColors.discoCyan α0.20
      blurRadius: 48,
    ),
  ];
}
