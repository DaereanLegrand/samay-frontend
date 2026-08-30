import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Samay disco color palette — the single source of truth for every color in
/// the app (DESIGN.md §2, owned by U-01 for finalization).
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
    'softGray': softGray,
    'glowPink': glowPink,
    'glowPinkBright': glowPinkBright,
    'glowPinkDeep': glowPinkDeep,
    'discoViolet': discoViolet,
    'discoCyan': discoCyan,
    'discoGold': discoGold,
    'discoSilver': discoSilver,
    'discoBronze': discoBronze,
    'pastelRose': pastelRose,
    'pastelViolet': pastelViolet,
    'pastelCyan': pastelCyan,
    'pastelGold': pastelGold,
    'pastelMint': pastelMint,
    'pastelPeach': pastelPeach,
    'mint': mint,
    'peach': peach,
    'statusGrey': statusGrey,
    'statusRead': statusRead,
    'badgeRed': badgeRed,
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

  /// Background for tags
  static const Color softGray = Color(0xf2f2f2FF);

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

  // ── LUXE pastel + vivid ends — §2.3 (gradient families) ──────────────────
  //
  // The light ends of the 6 LUXE gradient families (the LUXE restyle pass (historical)
  // §"Gradient family → screen map") plus the two vivid ends that had no
  // canonical token yet. Pastels are near-white by construction ("watered
  // down with white", LUXE directive #3) so they sit at AAA contrast on
  // black. They are meant for gradient layers / glow tints — decorative
  // fills at low alpha — never for body text roles (use `white`/`mutedStrong`).

  /// LUXE rose family light end (#FF8CBE). 9.75:1 — AAA.
  static const Color pastelRose = Color(0xFFFF8CBE);

  /// LUXE violet family light end (#BFA5FA). 9.98:1 — AAA.
  static const Color pastelViolet = Color(0xFFBFA5FA);

  /// LUXE cyan family light end (#73F1FF). 15.75:1 — AAA.
  static const Color pastelCyan = Color(0xFF73F1FF);

  /// LUXE gold family light end (#FFE19D). 16.51:1 — AAA.
  static const Color pastelGold = Color(0xFFFFE19D);

  /// LUXE mint family light end (#91F1CD). 15.66:1 — AAA.
  static const Color pastelMint = Color(0xFF91F1CD);

  /// LUXE peach family light end (#FFCCBB). 14.60:1 — AAA.
  static const Color pastelPeach = Color(0xFFFFCCBB);

  /// LUXE mint family vivid end (#37E6A5). 13.02:1 — AAA.
  static const Color mint = Color(0xFF37E6A5);

  /// LUXE peach family vivid end (#FF8A65). 9.08:1 — AA/AAA.
  static const Color peach = Color(0xFFFF8A65);

  // ── Chat message status (2026-08-15, WhatsApp-style ticks) ────────────────
  //
  // The sent/received/read indicators live INSIDE the own (white) message
  // bubble, so both colors are verified against white (they must also stay
  // legible on the black page for any future dark-bubble variant).

  /// Sent/received tick grey (#757575). 4.61:1 on white — AA; 4.55:1 on
  /// black — AA.
  static const Color statusGrey = Color(0xFF757575);

  /// Read tick blue — WhatsApp's read color adapted for a white bubble
  /// (#007AFF, iOS system blue). 4.02:1 on white — AA; 5.23:1 on black — AA.
  static const Color statusRead = Color(0xFF007AFF);

  /// Red badge fill — the "request/invite pending" voice (user directive
  /// 2026-08-27: red circle badges, overrides the monochrome rule for this
  /// one semantic element). A deeper red (#E53935, Material red 600) so a
  /// white 1px-free solid circle reads cleanly on the black page — white
  /// count text on it is 7.00:1 — AA/AAA.
  static const Color badgeRed = Color(0xFFE53935);

  // ── Semantic aliases — §2 usage roles → canonical tokens ───────────────────
  //
  // Role names for the doc's *usage* column (§2.1–§2.3, §5.x). Every alias
  // resolves to a canonical §2 token — no invented hexes (design doc §8.1:
  // new colors require a doc row + verified ratio; these are not new colors).

  /// VIP/subscription tier, premium badges, "pro" features (§2.3).
  static const Color statusVip = discoViolet;

  /// Live/online indicators (§2.3).
  static const Color statusOnline = discoCyan;

  /// Realtime presence dots / live badges (§2.3).
  static const Color statusLive = discoCyan;

  /// **Shards currency** — replaces the white diamond in `VShardIcon`
  /// (§2.3/§5.6).
  static const Color currencyShards = discoGold;

  /// Positive/success signal. The doc defines no literal "success" row —
  /// this resolves the role to its bright-positive token, discoCyan
  /// (13.65:1 — AAA).
  static const Color success = discoCyan;

  /// Error *text* — legal at normal size on black (glowPink 6.00:1 — AA).
  /// §5.2: never raw `Colors.red` on black alone.
  static const Color error = glowPink;

  /// Error/destructive *fill* — white text on `glowPinkDeep` is 5.87:1
  /// (§5.2 error chip; §5.1 pressed state of glow buttons).
  static const Color errorFill = glowPinkDeep;

  /// Destructive-action accent (delete/ban/danger). §5.1 pressed /
  /// §5.2 error family — never raw red on black (§5.2).
  static const Color danger = glowPinkDeep;

  /// Pending request/invite badge fill — the red circle badge voice
  /// (user directive 2026-08-27; white text on `badgeRed` is 7.00:1).
  static const Color statusPending = badgeRed;

  /// Role → canonical-token map (tests/tooling). Values only ever alias
  /// entries of [all] — the §2 hex table stays the single color source.
  static const Map<String, Color> semantic = {
    'statusVip': statusVip,
    'statusOnline': statusOnline,
    'statusLive': statusLive,
    'currencyShards': currencyShards,
    'success': success,
    'error': error,
    'errorFill': errorFill,
    'danger': danger,
    'statusPending': statusPending,
  };

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
/// system (finding UI-06; DESIGN.md §2 + §8.1).
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
