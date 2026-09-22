import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';

/// Samay typography tokens — the single source of truth for the type scale
/// and glow treatment.
///
/// The §3.3 table is the contract: every role's family, size, weight,
/// letter-spacing and height live here as const-constructible [TextStyle]s.
/// The §3.4 glow treatment lives in [fancyTitle]; [textTheme] composes both
/// into the `TextTheme` consumed by `SamayTheme.dark`
/// (`lib/core/theme/app_theme.dart`).
///
/// Contract notes (design doc §3):
/// - Playfair Display appears ONLY
///   in display/fancy roles (§3.1/§3.2); every other role is Inter.
/// - The consts carry the §3.3 metrics **without** glow. Shadows are applied
///   by [fancyTitle] with `em`-relative blur radii (fontSize × factor, like
///   the CSS source `text-shadow: 0 0 0.35em/0.7em/1em var(--pink)`), so they
///   cannot be const — [textTheme] composes glow into the four display/
///   headline roles (glow-strong ≥32px, glow-soft 28px).
/// - Roles absent from the §3.3 table (titleSmall, caption, overline) stay
///   null in [textTheme]; `ThemeData` merges Material defaults for them
///   (zero visual change — M3 metrics with the Inter family).
abstract final class AppTypography {
  /// Display/fancy voice — Playfair Display, display roles ONLY (§3.1).
  static const String playfair = 'Playfair Display';

  /// UI voice — everything else: body, buttons, inputs, labels, nav (§3.1).
  static const String inter = 'Inter';

  /// Minigame play voice — the expressive rounded UI family used for the
  /// question/dare prompt and the submitted answer copy inside minigame
  /// rounds (Quicksand). Never a display role; it reads as friendly body
  /// copy within the play cards.
  static const String quicksand = 'Quicksand';

  //
  // Used for OPTICAL vertical alignment: a text's cap/x-height band (measured
  // from the real baseline) is the visual center, not the line box. Ratios are
  // per-family because Playfair/Inter/Quicksand differ. Keep in sync with the
  // assets under `assets/fonts/` (unitsPerEm-normalized).
  static const double playfairCapHeightRatio = 0.708;
  static const double playfairXHeightRatio = 0.514;
  static const double interCapHeightRatio = 0.728;
  static const double interXHeightRatio = 0.546;
  static const double quicksandCapHeightRatio = 0.700;
  static const double quicksandXHeightRatio = 0.503;

  // Natural vertical metrics (em ratios; OS/2 typo ascender/descender, which
  // these fonts mark with USE_TYPO_METRICS). ascent/descent sum to the natural
  // line height; ascent/(ascent+descent) is the baseline's position in that run.
  static const double playfairAscentRatio = 1.082;
  static const double playfairDescentRatio = 0.251;
  static const double interAscentRatio = 0.9688;
  static const double interDescentRatio = 0.2412;
  static const double quicksandAscentRatio = 1.0;
  static const double quicksandDescentRatio = 0.25;

  /// The legibility drop shadow for text painted over imagery (full-bleed
  /// pictures): a soft black shadow that keeps white glyphs readable. Applied
  /// BY DEFAULT to display/header text ([VDisplayText], the minigame header
  /// title and its rows) and to over-image labels.
  static const List<Shadow> legibilityShadows = [
    Shadow(color: Color(0xFF000000), blurRadius: 10, offset: Offset(0, 2)),
  ];

  /// Cap-height ratio for [family] (falls back to Inter).
  static double capHeightRatioFor(String? family) => switch (family) {
    playfair => playfairCapHeightRatio,
    quicksand => quicksandCapHeightRatio,
    _ => interCapHeightRatio,
  };

  /// x-height ratio for [family] (falls back to Inter).
  static double xHeightRatioFor(String? family) => switch (family) {
    playfair => playfairXHeightRatio,
    quicksand => quicksandXHeightRatio,
    _ => interXHeightRatio,
  };

  /// Typo-ascender em ratio for [family] (falls back to Inter).
  static double ascentRatioFor(String? family) => switch (family) {
    playfair => playfairAscentRatio,
    quicksand => quicksandAscentRatio,
    _ => interAscentRatio,
  };

  /// Typo-descender em ratio for [family] (falls back to Inter).
  static double descentRatioFor(String? family) => switch (family) {
    playfair => playfairDescentRatio,
    quicksand => quicksandDescentRatio,
    _ => interDescentRatio,
  };

  //
  // The display voices (displayLarge/displayMedium/displaySmall and
  // headlineLarge) are Playfair Display **bold** — the ONLY Playfair usage
  // in the app. No italics.
  //
  // Display copy renders VERBATIM — no case transformation (the MAYUS rule
  // was deleted with the monochrome refactor). Callers pass natural-case
  // strings ('samay', 'Crea tu cuenta'). Display roles must NOT be rendered
  // as raw `Text` widgets; always route them through `VDisplayText` so the
  // white glyph color and size-token mapping stay uniform.


  /// Welcome wordmark (glow-strong). Playfair Display bold 700 at 64.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: playfair,
    fontSize: 64,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.9,
    height: 1.0,
  );

  /// Auth flow big headers (glow-strong). Playfair Display bold 700 at 40.
  static const TextStyle displayMedium = TextStyle(
    fontFamily: playfair,
    fontSize: 40,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.2,
    height: 1.0,
  );

  /// Feed hero, coming-soon, section heroes (glow-strong). Playfair Display
  /// bold 700 at 32.
  static const TextStyle displaySmall = TextStyle(
    fontFamily: playfair,
    fontSize: 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    height: 1.05,
  );

  /// Event titles, podium names, group hero (glow-soft). Playfair Display
  /// bold 600 at 28.
  static const TextStyle headlineLarge = TextStyle(
    fontFamily: playfair,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    height: 1.1,
  );

  /// Screen headers. Inter bold at 24.
  static const TextStyle headlineMedium = TextStyle(
    fontFamily: inter,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    height: 1.2,
  );

  /// Card titles. Inter semi-bold at 20.
  static const TextStyle headlineSmall = TextStyle(
    fontFamily: inter,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    height: 1.3,
  );

  /// List item titles. Inter semi-bold at 18.
  static const TextStyle titleLarge = TextStyle(
    fontFamily: inter,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  /// List subtitles. Inter medium at 16.
  static const TextStyle titleMedium = TextStyle(
    fontFamily: inter,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0,
    height: 1.4,
  );

  /// Body copy (light per the MVP spec). Inter light at 16.
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: inter,
    fontSize: 16,
    fontWeight: FontWeight.w300,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Secondary body. Inter light at 14.
  static const TextStyle bodyMedium = TextStyle(
    fontFamily: inter,
    fontSize: 14,
    fontWeight: FontWeight.w300,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Captions, timestamps. Inter regular at 12.
  static const TextStyle bodySmall = TextStyle(
    fontFamily: inter,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0,
    height: 1.5,
  );

  /// Button labels (uppercase). Inter bold at 14.
  static const TextStyle labelLarge = TextStyle(
    fontFamily: inter,
    fontSize: 14,
    fontWeight: FontWeight.w700,
    letterSpacing: 1.2,
    height: 1.2,
  );

  /// Chips, small buttons, tab labels (uppercase). Inter semi-bold at 12.
  static const TextStyle labelMedium = TextStyle(
    fontFamily: inter,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.8,
    height: 1.3,
  );

  /// Badges, rank labels, overlines (uppercase). Inter medium at 10.
  static const TextStyle labelSmall = TextStyle(
    fontFamily: inter,
    fontSize: 10,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.2,
    height: 1.3,
  );

  /// OTP code input (§3.3). Inter bold at 30, letter-spacing 8.
  static const TextStyle otpInputText = TextStyle(
    fontFamily: inter,
    fontSize: 30,
    fontWeight: FontWeight.w800,
    letterSpacing: 8,
    height: 1.5,
  );

  /// Section labels: Inter w600 at 12 with 2.0 tracking,
  /// `mutedStrong` (7.37:1 — AA). Rendered ABOVE content as an all-caps
  /// eyebrow; the label text itself is uppercase at call sites (`.toUpperCase()`
  /// or an already-caps l10n string) — this role is NOT a display voice and
  /// does NOT go through `VDisplayText`.
  static const TextStyle sectionLabel = TextStyle(
    fontFamily: inter,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
    color: AppColors.mutedStrong,
  );

  /// [sectionLabel] one step tighter for dense cards (feed match cards):
  /// same role/voice — Inter w600, `mutedStrong`, 2.0 tracking —
  /// at 11.
  static const TextStyle sectionLabelSmall = TextStyle(
    fontFamily: inter,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 2.0,
    color: AppColors.mutedStrong,
  );


  /// Applies the canonical glow shadow stack to [base] (design doc §3.4).
  ///
  /// Blur radii are `em`-relative — computed from the style's fontSize like
  /// the CSS source (`text-shadow: 0 0 0.35em/0.7em/1em var(--pink)`).
  /// [soft] selects the 2-layer glow-soft stack (headlines ≥28px) instead of
  /// the 3-layer glow-strong stack (display titles ≥32px). The glyph fill is
  /// left untouched (full opacity) — the halo is strictly behind the text
  /// (§7.4 legibility contract).
  static TextStyle fancyTitle(TextStyle base, {bool soft = false}) {
    final size = base.fontSize ?? 32;
    final glowPink = AppColors.glowPink;
    if (soft) {
      return base.copyWith(
        shadows: [
          Shadow(
            color: glowPink.withValues(alpha: 0.6),
            blurRadius: size * 0.3,
          ),
          Shadow(
            color: glowPink.withValues(alpha: 0.25),
            blurRadius: size * 0.6,
          ),
        ],
      );
    }
    return base.copyWith(
      shadows: [
        Shadow(
          color: glowPink.withValues(alpha: 0.9),
          blurRadius: size * 0.35,
        ),
        Shadow(
          color: glowPink.withValues(alpha: 0.5),
          blurRadius: size * 0.7,
        ),
        Shadow(
          color: glowPink.withValues(alpha: 0.25),
          blurRadius: size * 1.0,
        ),
      ],
    );
  }


  /// The full text-role table with glow baked into the four display roles.
  ///
  /// Roles outside the §3.3 table stay null so `ThemeData` fills Material
  /// defaults (titleSmall, caption, overline); consuming this theme leaves
  /// those defaults untouched.
  static final TextTheme textTheme = TextTheme(
    displayLarge: fancyTitle(displayLarge),
    displayMedium: fancyTitle(displayMedium),
    displaySmall: fancyTitle(displaySmall),
    headlineLarge: fancyTitle(headlineLarge, soft: true),
    headlineMedium: headlineMedium,
    headlineSmall: headlineSmall,
    titleLarge: titleLarge,
    titleMedium: titleMedium,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );
}
