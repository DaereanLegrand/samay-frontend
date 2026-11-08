import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';

/// Full set of surface/text roles a themed group screen paints.
///
/// The server owns two values per group (`background_color`, `foreground_color`,
/// `accent_color`, `accent_foreground_color`) and guarantees the base pair
/// meets WCAG AA. Everything a screen needs *between* those roles — card fills,
/// hairlines, dividers, secondary text — is derived here mathematically so the
/// whole surface keeps working as one tonal scale instead of black boxes pasted
/// on a coloured page.
class GroupThemePalette {
  const GroupThemePalette({
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.foreground,
    required this.mutedForeground,
    required this.hairline,
    required this.border,
    required this.accent,
    required this.accentForeground,
  });

  /// Page background (server value, clamped dark server-side).
  final Color background;

  /// Card/overlay fill: `background` lifted one step toward the foreground.
  final Color surface;

  /// Raised fill (chat bubbles, composer, sheets): one more step.
  final Color surfaceAlt;

  /// Primary text/icon colour (server value).
  final Color foreground;

  /// Secondary/label text — alpha solved to reach AA against [surface]
  /// (falls back to a blend when the foreground is too dark for alpha alone).
  final Color mutedForeground;

  /// Decorative 1px dividers/card edges.
  final Color hairline;

  /// Interactive outlines (chips, rings, unselected controls).
  final Color border;

  /// Accent fill (badges, selected markers).
  final Color accent;

  /// Text on [accent].
  final Color accentForeground;

  /// The app's own un-themed palette — identical to the design tokens, so every
  /// screen that is *not* inside a themed group renders byte-for-byte as
  /// before.
  static const GroupThemePalette standard = GroupThemePalette(
    background: AppColors.discoBlack,
    surface: AppColors.surface,
    surfaceAlt: AppColors.surfaceAlt,
    foreground: AppColors.white,
    mutedForeground: AppColors.mutedStrong,
    hairline: AppColors.hairline,
    border: AppColors.border,
    accent: AppColors.white,
    accentForeground: AppColors.discoBlack,
  );

  // ---------------------------------------------------------------------
  // Derivation
  // ---------------------------------------------------------------------

  /// Builds the full scale from the four server-owned colours.
  ///
  /// * [surface] / [surfaceAlt] are the background lifted toward the
  ///   foreground by a fixed perceptual step (6% / 13%).
  /// * [mutedForeground] solves the smallest alpha of the foreground that
  ///   still reaches 4.5:1 on [surface]; if even the solid foreground cannot
  ///   reach it (dark-on-dark), it blends toward the *other* end instead so the
  ///   label never becomes invisible.
  /// * [hairline] / [border] are the foreground at 10% / 24%.
  factory GroupThemePalette.derive({
    required Color background,
    required Color foreground,
    required Color accent,
    required Color accentForeground,
  }) {
    // Lift by the preferred step, but never so far that the primary text
    // drops below AA on the raised step (a light background reaches the cap
    // first).
    final surface = _liftWithin(background, foreground, 0.06, foreground, 4.5);
    var surfaceAlt = _liftWithin(background, foreground, 0.13, foreground, 4.5);
    // Guarantee a perceptible second step even when the AA cap ate the whole
    // lift: darken slightly (away from a light foreground) so cards still read
    // as raised/depressed instead of collapsing onto the same tone.
    if (relativeLuminance(surfaceAlt) == relativeLuminance(surface)) {
      final away = relativeLuminance(foreground) > 0.5
          ? Colors.black
          : Colors.white;
      surfaceAlt = _liftWithin(surface, away, 0.06, foreground, 4.5);
      // If darkening also hits the cap, darkening by less still separates them.
      if (relativeLuminance(surfaceAlt) == relativeLuminance(surface)) {
        surfaceAlt = _lift(surface, away, 0.03);
      }
    }
    // Labels and outlines sit on `surfaceAlt` in the densest case (raised
    // cards, bubbles, the composer), so they are solved against the LIGHTEST
    // step — the hardest background — and are therefore safe on every step.
    return GroupThemePalette(
      background: background,
      surface: surface,
      surfaceAlt: surfaceAlt,
      foreground: foreground,
      mutedForeground: _readableTone(foreground, surfaceAlt, 4.5),
      hairline: _readableTone(foreground, surfaceAlt, 1.25),
      border: _readableTone(foreground, surfaceAlt, 3.0),
      accent: accent,
      accentForeground: accentForeground,
    );
  }

  /// [t], reduced as needed so [text] keeps [minContrast] on the lifted colour.
  ///
  /// Returns the lifted colour at the largest step <= [t] that preserves the
  /// text contract; when even [t] = 0 cannot (text already too close), it
  /// returns the un-lifted background.
  static Color _liftWithin(
    Color base,
    Color toward,
    double t,
    Color text,
    double minContrast,
  ) {
    var step = t;
    for (var i = 0; i < 16; i++) {
      final candidate = _lift(base, toward, step);
      if (contrastRatio(text, candidate) >= minContrast) return candidate;
      step *= 0.75;
      if (step < 0.005) return base;
    }
    return base;
  }

  /// Linear interpolation of two RGB colours (ignoring alpha).
  static Color _lift(Color base, Color toward, double t) {
    return Color.fromARGB(
      255,
      (base.r * 255 + (toward.r * 255 - base.r * 255) * t).round(),
      (base.g * 255 + (toward.g * 255 - base.g * 255) * t).round(),
      (base.b * 255 + (toward.b * 255 - base.b * 255) * t).round(),
    );
  }

  /// Largest blend of [foreground] toward [bg] that still reaches [target]
  /// contrast, returned as an OPAQUE colour (so no compositing ambiguity).
  ///
  /// Binary search over the blend factor (0 = full foreground, 1 = background).
  /// If even the solid foreground misses the target, it blends from the
  /// maximum-contrast end of the scale (black/white) instead, so a label on a
  /// dark-on-dark theme never disappears.
  static Color _readableTone(Color foreground, Color bg, double target) {
    if (contrastRatio(foreground, bg) < target) {
      final base =
          contrastRatio(Colors.black, bg) >= contrastRatio(Colors.white, bg)
          ? Colors.black
          : Colors.white;
      return _readableTone(base, bg, target);
    }
    // More blend = less contrast. Find the largest blend that still passes.
    var lo = 0.0; // full foreground (max contrast)
    var hi = 1.0; // fully blended into the surface (no contrast)
    for (var i = 0; i < 18; i++) {
      final mid = (lo + hi) / 2;
      if (contrastRatio(_lift(foreground, bg, mid), bg) >= target) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return _lift(foreground, bg, lo);
  }

  // ---------------------------------------------------------------------
  // WCAG helpers (mirror the SQL functions in 240_group_theme)
  // ---------------------------------------------------------------------

  /// Relative luminance per WCAG 2.x.
  static double relativeLuminance(Color c) {
    double channel(double v) => v <= 0.04045
        ? v / 12.92
        : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  /// Contrast ratio between two colours. Translucent inputs are composited
  /// over the page background first, which is what the eye sees.
  static double contrastRatio(Color a, Color b) {
    final la = relativeLuminance(_opaque(a));
    final lb = relativeLuminance(_opaque(b));
    final hi = math.max(la, lb);
    final lo = math.min(la, lb);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Composites a translucent colour over the page background so the ratio
  /// reflects what the eye actually sees.
  static Color _opaque(Color c) {
    if (c.a >= 1.0) return c;
    return Color.fromARGB(
      255,
      (c.r * 255 * c.a + 0x0A * (1 - c.a)).round(),
      (c.g * 255 * c.a + 0x0A * (1 - c.a)).round(),
      (c.b * 255 * c.a + 0x0A * (1 - c.a)).round(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is GroupThemePalette &&
          other.background == background &&
          other.surface == surface &&
          other.surfaceAlt == surfaceAlt &&
          other.foreground == foreground &&
          other.mutedForeground == mutedForeground &&
          other.hairline == hairline &&
          other.border == border &&
          other.accent == accent &&
          other.accentForeground == accentForeground;

  @override
  int get hashCode => Object.hash(
    background,
    surface,
    surfaceAlt,
    foreground,
    mutedForeground,
    hairline,
    border,
    accent,
    accentForeground,
  );
}
