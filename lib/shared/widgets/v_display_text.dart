import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/theme/app_theme_scope.dart';

/// The display voice (DESIGN.md §1 rule 4) — the ONLY sanctioned way to
/// render a display role.
///
/// Monochrome contract: renders [text] VERBATIM
/// in Playfair Display bold, flat [AppColors.white]. No case transformation,
/// no gradient fills, no shimmer, no glow — static glyphs, zero tickers
/// (reduced-motion safe by construction).
class VDisplayText extends StatelessWidget {
  /// Display copy — rendered exactly as written.
  final String text;

  /// Glyph size in logical px (default 40 — [AppTypography.displayMedium]).
  final double size;

  /// Default glyph size in logical px ([AppTypography.displayMedium]).
  static const double defaultSize = 40;

  /// Optional alignment (the parent may already center the text).
  final TextAlign? textAlign;

  /// Optional max line count for long display copy.
  final int? maxLines;

  const VDisplayText({
    super.key,
    required this.text,
    this.size = defaultSize,
    this.textAlign,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    // On a themed group surface the display voice uses the derived foreground
    // (the background's complement), never the fixed white token.
    final palette = AppThemeScope.paletteOf(context);
    final themed = AppThemeScope.isThemed(context);
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: _displayStyle().copyWith(
        color: themed ? palette.foreground : AppColors.white,
      ),
    );
  }

  /// The display style for [size] — the exact mapping [VDisplayText] paints, so
  /// callers (e.g. the header's optical alignment) can measure the same glyph
  /// metrics. Returns the glow-free white Playfair base.
  static TextStyle styleFor(double size) {
    final base = switch (size) {
      64 => AppTypography.displayLarge,
      40 => AppTypography.displayMedium,
      32 => AppTypography.displaySmall,
      28 => AppTypography.headlineLarge,
      _ => TextStyle(
        fontFamily: AppTypography.playfair,
        fontSize: size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.0,
        height: 1.0,
      ),
    };
    return base.copyWith(
      color: AppColors.white,
      shadows: AppTypography.legibilityShadows,
    );
  }

  /// Playfair Display bold at [VDisplayText.size] — the display roles when
  /// the size matches a §3.3 token, otherwise a same-metric custom style
  ///. Neutral tracking — the
  /// display voice breathes; cramped tracking reads "old".
  TextStyle _displayStyle() => styleFor(size);
}
