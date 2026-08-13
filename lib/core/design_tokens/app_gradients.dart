import 'package:flutter/material.dart';

import 'app_colors.dart';

/// A named 3-stop pastel gradient family (LUXE v2 design language,
/// ORCHESTRATION-LUXE.md §"Gradient family → screen map").
///
/// Every family runs `pastel → mid → vivid`: the light end is the color
/// "watered down with white" (see [AppGradients.watered]), the vivid end
/// carries the hue at full saturation. Families are never rendered as flat
/// single-color accents — every accent in the app is one of these runs
/// (directive #2, #3).
class AppGradient {
  /// Family slug: `rose`, `violet`, `cyan`, `gold`, `mint`, `peach`.
  final String name;

  /// The 3 gradient stops, pastel → mid → vivid.
  final List<Color> colors;

  /// Stop positions — always `[0.0, 0.5, 1.0]` for the 6 canonical families.
  final List<double> stops;

  const AppGradient({
    required this.name,
    required this.colors,
    required this.stops,
  });

  /// Diagonal fill gradient (text fills, borders, button faces).
  ///
  /// Defaults to `topLeft → bottomRight`; pass rotated [begin]/[end] for
  /// per-component direction.
  LinearGradient linear({
    AlignmentGeometry begin = Alignment.topLeft,
    AlignmentGeometry end = Alignment.bottomRight,
  }) {
    return LinearGradient(begin: begin, end: end, colors: colors, stops: stops);
  }

  /// Radial fill gradient for aurora blobs ([VAurora] anchors) and
  /// spotlight glows. Defaults to [Alignment.center]; pass [center] to
  /// anchor a blob off-center.
  RadialGradient radial({AlignmentGeometry center = Alignment.center}) {
    return RadialGradient(center: center, colors: colors, stops: stops);
  }
}

/// The LUXE gradient token layer — the single source of truth for every
/// gradient family in the app (ORCHESTRATION-LUXE.md §"Gradient family →
/// screen map" + §"Foundation API contract (XL-01 implements EXACTLY this)").
///
/// Rules for consumers:
/// - Screens resolve their family via [familyOf] with their doc screen key —
///   never pick a family ad-hoc.
/// - Text gradients go through [textShader] + `ShaderMask`; box glows go
///   through [glowShadows]. No inline `LinearGradient` color lists outside
///   this file and the component primitives (XL-02..XL-04).
/// - Stops are always the doc's `[0.0, 0.5, 1.0]`.
abstract final class AppGradients {
  /// Rose: the signature family (welcome, signup, banned, party_finder).
  /// Vivid end aliases [AppColors.glowPink]; pastel end is
  /// [AppColors.pastelRose].
  static const AppGradient rose = AppGradient(
    name: 'rose',
    colors: [
      AppColors.pastelRose,
      Color(0xFFFF8AC2),
      AppColors.glowPink,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Violet: age_gate, groups, cosmetics, minigames. Vivid end aliases
  /// [AppColors.discoViolet]; pastel end is [AppColors.pastelViolet].
  static const AppGradient violet = AppGradient(
    name: 'violet',
    colors: [
      AppColors.pastelViolet,
      Color(0xFFB79CFF),
      AppColors.discoViolet,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Cyan: login, profile_setup, feed, qr. Vivid end aliases
  /// [AppColors.discoCyan]; pastel end is [AppColors.pastelCyan].
  static const AppGradient cyan = AppGradient(
    name: 'cyan',
    colors: [
      AppColors.pastelCyan,
      Color(0xFF7FE9FF),
      AppColors.discoCyan,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Gold: otp, notifications, profile, shards, paywall. Vivid end aliases
  /// [AppColors.discoGold]; pastel end is [AppColors.pastelGold].
  static const AppGradient gold = AppGradient(
    name: 'gold',
    colors: [
      AppColors.pastelGold,
      Color(0xFFFFDF99),
      AppColors.discoGold,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Mint: privacy_terms, friends, photos. Vivid end is [AppColors.mint];
  /// pastel end is [AppColors.pastelMint].
  static const AppGradient mint = AppGradient(
    name: 'mint',
    colors: [
      AppColors.pastelMint,
      Color(0xFF8BFFD9),
      AppColors.mint,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// Peach: forgot_password, chat, events. Vivid end is [AppColors.peach];
  /// pastel end is [AppColors.pastelPeach].
  static const AppGradient peach = AppGradient(
    name: 'peach',
    colors: [
      AppColors.pastelPeach,
      Color(0xFFFFC09E),
      AppColors.peach,
    ],
    stops: [0.0, 0.5, 1.0],
  );

  /// All 6 families, keyed by [AppGradient.name]. Used by tests and tooling;
  /// screens resolve via [familyOf] instead.
  static const Map<String, AppGradient> all = {
    'rose': rose,
    'violet': violet,
    'cyan': cyan,
    'gold': gold,
    'mint': mint,
    'peach': peach,
  };

  /// Resolves a screen key to its owning gradient family (ORCHESTRATION-LUXE
  /// §"Gradient family → screen map", verbatim).
  ///
  /// **NO PINK MAINS (2026-08-12 user directive):** rose is NOT assigned to
  /// any screen — it exists in the palette only as a possible micro-accent
  /// inside ambient multi-color auroras, never as a screen's hero/display/
  /// CTA gradient. Unknown keys fall back to [violet], the LUXE default.
  static AppGradient familyOf(String screenKey) {
    return switch (screenKey) {
      'welcome' || 'signup' || 'profile_setup' || 'qr' => violet,
      'login' || 'feed' || 'party_finder' => cyan,
      'age_gate' || 'groups' || 'cosmetics' => violet,
      'otp' || 'notifications' || 'profile' || 'shards' || 'paywall' => gold,
      'privacy_terms' || 'friends' || 'photos' || 'banned' => mint,
      'forgot_password' || 'chat' || 'events' || 'minigames' => peach,
      _ => violet,
    };
  }

  /// The 3-layer halo stack behind glass, buttons and hero text
  /// (LUXE directive #5: "slow pulsating glows"; the pulse wrapper in
  /// XL-04 animates the overall alpha).
  ///
  /// Layers, innermost → outermost:
  /// 1. mid stop at full [alpha], blur [blur] — the tight halo
  /// 2. vivid stop at `alpha × 0.6`, blur `blur × 2`
  /// 3. vivid stop at `alpha × 0.3`, blur `blur × 3.5` — the wide aura
  ///
  /// All layers are zero-offset: the glow is a halo, not a drop shadow.
  static List<BoxShadow> glowShadows(
    AppGradient g, {
    double alpha = 0.35,
    double blur = 48,
  }) {
    return [
      BoxShadow(
        color: g.colors[1].withValues(alpha: alpha),
        blurRadius: blur,
      ),
      BoxShadow(
        color: g.colors[2].withValues(alpha: alpha * 0.6),
        blurRadius: blur * 2,
      ),
      BoxShadow(
        color: g.colors[2].withValues(alpha: alpha * 0.3),
        blurRadius: blur * 3.5,
      ),
    ];
  }

  /// Gradient fill shader for [TextSpan]s rendered through `ShaderMask`
  /// (gradient display text — LUXE directive #2: never flat accent text).
  ///
  /// [bounds] is the text's paint rect (e.g. `span.computeMetrics()` /
  /// `TextPainter` bounds). The caller keeps ownership of the rect —
  /// see `VGradientText` (XL-03) for the ready-made widget.
  static Shader textShader(AppGradient g, Rect bounds) {
    return g.linear().createShader(bounds);
  }

  /// "Waters down" colors toward white (LUXE directive #3: pastel, watered
  /// down with white). Each color is `Color.lerp(c, white, mix)` — the
  /// recipe behind the light ends of the 6 canonical families.
  static List<Color> watered(List<Color> base, {double mix = 0.6}) {
    return base
        .map((c) => Color.lerp(c, AppColors.white, mix)!)
        .toList(growable: false);
  }

  /// A full [AppGradient] re-stopped from [watered] colors — the fill/border
  /// variant of a family (XL-17 Gemma round 2: "cheap saturated color").
  ///
  /// Fills and borders ride the watered run (mix 0.35–0.5) so the vivid end
  /// only survives where the design language wants it: the display-text
  /// shader ([VDisplayText]) and micro accents (dots, 1px underlines). The
  /// returned gradient keeps the family [AppGradient.name] and stops so the
  /// chrome primitives (glass ring, glow halo, button face) resolve it
  /// unchanged — just paler.
  static AppGradient wateredFamily(AppGradient g, {double mix = 0.4}) {
    return AppGradient(
      name: g.name,
      colors: watered(g.colors, mix: mix),
      stops: g.stops,
    );
  }
}
