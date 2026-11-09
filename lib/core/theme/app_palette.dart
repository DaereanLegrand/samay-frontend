import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';

/// Full set of surface/text roles a themed surface paints.
///
/// The same tonal scale drives both the app-wide theme (chosen in Settings,
/// paywalled) and a group's own theme. The server (or the preset) owns four
/// values — background, foreground, accent, accent foreground — and guarantees
/// the base pair meets WCAG AA. Everything a screen needs *between* those roles
/// — card fills, hairlines, dividers, secondary text — is derived here
/// mathematically so the whole surface keeps working as one tonal scale instead
/// of black boxes pasted on a coloured page.
class AppPalette {
  const AppPalette({
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
  static const AppPalette standard = AppPalette(
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

  /// How much darker every themed colour is painted: 0.75 = 75% darker
  /// (each channel × 0.25).
  static const double darkenAmount = 0.75;

  /// Builds the full scale from the four server-owned colours.
  ///
  /// The group surface is a **dark** rendition of the host's pick:
  ///
  /// * [background] / [accent] are the server colours darkened by
  ///   [darkenAmount] (75%).
  /// * The light (white-ish) foreground becomes the **complement** of the
  ///   host's background — a dark blue page gets warm sand text — then brightened
  ///   only as far as AA requires.
  /// * [surface] / [surfaceAlt] are the darkened background lifted toward the
  ///   final foreground by a fixed step (6% / 13%).
  /// * [mutedForeground], [hairline] and [border] are solved against
  ///   [surfaceAlt] (the lightest step) so they stay safe on every step.
  factory AppPalette.derive({
    required Color background,
    required Color foreground,
    required Color accent,
    required Color accentForeground,
  }) {
    final darkBackground = darken(background, darkenAmount);
    final darkAccent = darken(accent, darkenAmount);

    // White ink becomes the opposite hue of the host's background. A black /
    // dark ink (a light host pick) cannot survive the dark rendition at all, so
    // it also resolves to the complement, then to whichever end reads best.
    final isLightInk = relativeLuminance(foreground) > 0.5;
    final inkSource = isLightInk ? background : foreground;
    final themedForeground = _ensureContrast(
      complement(inkSource),
      darkBackground,
      4.5,
    );
    // "White becomes its colour opposite" — the ink is the complement of the
    // surface it actually sits on, so use the darkened accent, not the raw
    // server hex.
    final themedAccentForeground = _ensureContrast(
      complement(darkAccent),
      darkAccent,
      4.5,
    );

    // Lift by the preferred step, but never so far that the primary text
    // drops below AA on the raised step (a light-ish page reaches the cap
    // first).
    final surface = _liftWithin(
      darkBackground,
      themedForeground,
      0.06,
      themedForeground,
      4.5,
    );
    var surfaceAlt = _liftWithin(
      darkBackground,
      themedForeground,
      0.13,
      themedForeground,
      4.5,
    );
    // Guarantee a perceptible second step even when the AA cap ate the whole
    // lift: move away from the foreground so cards still read as raised
    // instead of collapsing onto the same tone.
    if (relativeLuminance(surfaceAlt) == relativeLuminance(surface)) {
      final away = relativeLuminance(themedForeground) > 0.5
          ? Colors.black
          : Colors.white;
      surfaceAlt = _liftWithin(surface, away, 0.06, themedForeground, 4.5);
      // If moving away also hits the cap, move by less — still separates them.
      if (relativeLuminance(surfaceAlt) == relativeLuminance(surface)) {
        surfaceAlt = _lift(surface, away, 0.03);
      }
    }
    // Labels and outlines sit on `surfaceAlt` in the densest case (raised
    // cards, bubbles, the composer), so they are solved against the LIGHTEST
    // step — the hardest background — and are therefore safe on every step.
    return AppPalette(
      background: darkBackground,
      surface: surface,
      surfaceAlt: surfaceAlt,
      foreground: themedForeground,
      mutedForeground: _readableTone(themedForeground, surfaceAlt, 5.0),
      hairline: _readableTone(themedForeground, surfaceAlt, 1.25),
      border: _readableTone(themedForeground, surfaceAlt, 3.0),
      accent: darkAccent,
      accentForeground: themedAccentForeground,
    );
  }

  /// Scales every channel toward black by [amount] (0 = unchanged, 1 = black).
  static Color darken(Color c, double amount) {
    final k = (1 - amount).clamp(0.0, 1.0);
    return Color.fromARGB(
      255,
      (c.r * 255 * k).round(),
      (c.g * 255 * k).round(),
      (c.b * 255 * k).round(),
    );
  }

  /// The hue-opposite of [c] (each channel inverted), keeping it opaque.
  static Color complement(Color c) => Color.fromARGB(
    255,
    255 - (c.r * 255).round(),
    255 - (c.g * 255).round(),
    255 - (c.b * 255).round(),
  );

  /// [c], nudged toward the higher-contrast end of the scale until it reaches
  /// [target] against [bg]. Keeps the hue as long as possible (smallest blend
  /// that passes), so the complement survives whenever it is legible at all.
  static Color _ensureContrast(Color c, Color bg, double target) {
    if (contrastRatio(c, bg) >= target) return c;
    final toward =
        contrastRatio(Colors.white, bg) >= contrastRatio(Colors.black, bg)
        ? Colors.white
        : Colors.black;
    var lo = 0.0; // unchanged colour
    var hi = 1.0; // fully the higher-contrast end
    for (var i = 0; i < 18; i++) {
      final mid = (lo + hi) / 2;
      if (contrastRatio(_lift(c, toward, mid), bg) >= target) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return _lift(c, toward, hi);
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
      other is AppPalette &&
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
