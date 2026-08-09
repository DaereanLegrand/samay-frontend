import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Samay disco color palette — the single source of truth for every color in
/// the app (DISCO-DESIGN-SYSTEM.md §2, owned by U-01 for finalization).
///
/// Rule: screens and widgets must never invent ad-hoc `Color(0x…)` values —
/// they reference [AppColors] (or the [SamayThemeExtension] below). New colors
/// must be added here first, with their verified contrast ratio, before any
/// use (design doc §8 "Extending the system").
///
/// Contrast values are computed against `#000000` with the WCAG 2.2 relative
/// luminance formula (see [contrastRatio]); thresholds per §7.1: text ≥ 4.5:1
/// normal, ≥ 3:1 large; non-text ≥ 3:1.
abstract final class AppColors {
  /// Complete palette as a name → color map (used by tests and tooling).
  static const Map<String, Color> all = {
    'discoBlack': discoBlack,
    'surface': surface,
    'surfaceAlt': surfaceAlt,
    'hairline': hairline,
    'border': border,
    'muted': muted,
    'mutedStrong': mutedStrong,
    'white': white,
    'glowPink': glowPink,
    'glowPinkBright': glowPinkBright,
    'glowPinkDeep': glowPinkDeep,
    'discoViolet': discoViolet,
    'discoCyan': discoCyan,
    'discoGold': discoGold,
    'discoSilver': discoSilver,
    'discoBronze': discoBronze,
  };

  // ── Neutrals (core) — §2.1 ────────────────────────────────────────────────

  /// Page background — **always** black (pillar P1). Contrast vs black: n/a.
  static const Color discoBlack = Color(0xFF000000);

  /// Card/overlay fills, bottom nav background. Depth only (1.06:1).
  static const Color surface = Color(0xFF0A0A0A);

  /// Raised surfaces: sheets, menus, skeleton base. Depth only (1.11:1).
  static const Color surfaceAlt = Color(0xFF111111);

  /// Card borders, dividers (decorative). Decoration only (1.21:1) — see §7.2
  /// for the boundary rule: a hairline is never the *only* indicator of an
  /// interactive region.
  static const Color hairline = Color(0xFF1A1A1A);

  /// Interactive outlines: unselected chips, avatar rings. Non-text 3:1 rule
  /// applies where the outline *is* the control indicator (1.66:1).
  static const Color border = Color(0xFF333333);

  /// Placeholder text, disabled text, unselected nav icons. **3.66:1 — large
  /// text only** (AA-large); never informational normal-size text (§2.4).
  static const Color muted = Color(0xFF666666);

  /// Secondary/label text, hints. 7.37:1 — AA.
  static const Color mutedStrong = Color(0xFF999999);

  /// Primary text, icons, emphasized fills. 21:1 — AA/AAA.
  static const Color white = Color(0xFFFFFFFF);

  // ── Signature glow pink — §2.2 ─────────────────────────────────────────────

  /// **The signature.** Display titles with glow, brand accents,
  /// selected/highlight states, glow buttons. 6.00:1 — AA.
  static const Color glowPink = Color(0xFFFF2E88);

  /// Glow halo layers, pressed/hover accent tint. 7.35:1 — AA.
  static const Color glowPinkBright = Color(0xFFFF5CA8);

  /// Pressed state of pink fills, dark-on-pink text pairing. 3.58:1 —
  /// AA-large only; decorative at opacity < 1 (§2.5 rule 6).
  static const Color glowPinkDeep = Color(0xFFC2185B);

  // ── Soft disco accents (status/icons only) — §2.3 ──────────────────────────

  /// VIP/subscription tier, premium badges, "pro" features. 4.96:1 — AA.
  static const Color discoViolet = Color(0xFF8B5CF6);

  /// Live/online indicators, realtime dots, info links. 13.65:1 — AAA.
  static const Color discoCyan = Color(0xFF00E5FF);

  /// **Shards currency**, rank tier 1, leaderboard top. 13.71:1 — AAA.
  static const Color discoGold = Color(0xFFFFC94D);

  /// Leaderboard tier 2, secondary ranks. 11.54:1 — AAA.
  static const Color discoSilver = Color(0xFFC0C0C0);

  /// Leaderboard tier 3, bronze ranks. 6.68:1 — AA.
  static const Color discoBronze = Color(0xFFCD7F32);

  // ── Contrast helper — §7.1 ─────────────────────────────────────────────────

  /// WCAG 2.2 contrast ratio between [foreground] and [background]:
  /// `(L1 + 0.05) / (L2 + 0.05)` over linearized sRGB relative luminance
  /// (`L = 0.2126R + 0.7152G + 0.0722B`). Pure function — safe to call from
  /// tests and the U-26 accessibility audit.
  static double contrastRatio(Color foreground, Color background) {
    final l1 = _relativeLuminance(foreground);
    final l2 = _relativeLuminance(background);
    final lighter = l1 > l2 ? l1 : l2;
    final darker = l1 > l2 ? l2 : l1;
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _relativeLuminance(Color color) {
    final r = _linearize(color.r);
    final g = _linearize(color.g);
    final b = _linearize(color.b);
    return 0.2126 * r + 0.7152 * g + 0.0722 * b;
  }

  /// sRGB channel (0..1) → linearized value per WCAG 2.2 §1.4.3.
  static double _linearize(double channel) {
    if (channel <= 0.03928) return channel / 12.92;
    return math.pow((channel + 0.055) / 1.055, 2.4).toDouble();
  }
}

/// Theme extension exposing the Samay palette through the Flutter theme
/// system (finding UI-06; DISCO-DESIGN-SYSTEM.md §2 + §8.1).
///
/// Registered on `ThemeData.extensions` (I-17) so widgets resolve it via
/// `Theme.of(context).extension<SamayThemeExtension>()` or the
/// `context.samayColors` convenience (`lib/core/extensions/context_extensions.dart`).
@immutable
class SamayThemeExtension extends ThemeExtension<SamayThemeExtension> {
  /// The canonical dark/disco palette — the app's only theme.
  static const dark = SamayThemeExtension(
    discoBlack: AppColors.discoBlack,
    surface: AppColors.surface,
    surfaceAlt: AppColors.surfaceAlt,
    hairline: AppColors.hairline,
    border: AppColors.border,
    muted: AppColors.muted,
    mutedStrong: AppColors.mutedStrong,
    white: AppColors.white,
    glowPink: AppColors.glowPink,
    glowPinkBright: AppColors.glowPinkBright,
    glowPinkDeep: AppColors.glowPinkDeep,
    discoViolet: AppColors.discoViolet,
    discoCyan: AppColors.discoCyan,
    discoGold: AppColors.discoGold,
    discoSilver: AppColors.discoSilver,
    discoBronze: AppColors.discoBronze,
  );

  final Color discoBlack;
  final Color surface;
  final Color surfaceAlt;
  final Color hairline;
  final Color border;
  final Color muted;
  final Color mutedStrong;
  final Color white;
  final Color glowPink;
  final Color glowPinkBright;
  final Color glowPinkDeep;
  final Color discoViolet;
  final Color discoCyan;
  final Color discoGold;
  final Color discoSilver;
  final Color discoBronze;

  const SamayThemeExtension({
    required this.discoBlack,
    required this.surface,
    required this.surfaceAlt,
    required this.hairline,
    required this.border,
    required this.muted,
    required this.mutedStrong,
    required this.white,
    required this.glowPink,
    required this.glowPinkBright,
    required this.glowPinkDeep,
    required this.discoViolet,
    required this.discoCyan,
    required this.discoGold,
    required this.discoSilver,
    required this.discoBronze,
  });

  @override
  SamayThemeExtension copyWith({
    Color? discoBlack,
    Color? surface,
    Color? surfaceAlt,
    Color? hairline,
    Color? border,
    Color? muted,
    Color? mutedStrong,
    Color? white,
    Color? glowPink,
    Color? glowPinkBright,
    Color? glowPinkDeep,
    Color? discoViolet,
    Color? discoCyan,
    Color? discoGold,
    Color? discoSilver,
    Color? discoBronze,
  }) {
    return SamayThemeExtension(
      discoBlack: discoBlack ?? this.discoBlack,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      hairline: hairline ?? this.hairline,
      border: border ?? this.border,
      muted: muted ?? this.muted,
      mutedStrong: mutedStrong ?? this.mutedStrong,
      white: white ?? this.white,
      glowPink: glowPink ?? this.glowPink,
      glowPinkBright: glowPinkBright ?? this.glowPinkBright,
      glowPinkDeep: glowPinkDeep ?? this.glowPinkDeep,
      discoViolet: discoViolet ?? this.discoViolet,
      discoCyan: discoCyan ?? this.discoCyan,
      discoGold: discoGold ?? this.discoGold,
      discoSilver: discoSilver ?? this.discoSilver,
      discoBronze: discoBronze ?? this.discoBronze,
    );
  }

  @override
  SamayThemeExtension lerp(SamayThemeExtension? other, double t) {
    if (other == null) return this;
    return SamayThemeExtension(
      discoBlack: Color.lerp(discoBlack, other.discoBlack, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      border: Color.lerp(border, other.border, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedStrong: Color.lerp(mutedStrong, other.mutedStrong, t)!,
      white: Color.lerp(white, other.white, t)!,
      glowPink: Color.lerp(glowPink, other.glowPink, t)!,
      glowPinkBright: Color.lerp(glowPinkBright, other.glowPinkBright, t)!,
      glowPinkDeep: Color.lerp(glowPinkDeep, other.glowPinkDeep, t)!,
      discoViolet: Color.lerp(discoViolet, other.discoViolet, t)!,
      discoCyan: Color.lerp(discoCyan, other.discoCyan, t)!,
      discoGold: Color.lerp(discoGold, other.discoGold, t)!,
      discoSilver: Color.lerp(discoSilver, other.discoSilver, t)!,
      discoBronze: Color.lerp(discoBronze, other.discoBronze, t)!,
    );
  }
}
