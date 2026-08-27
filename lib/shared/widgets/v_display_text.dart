import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// The display voice (DESIGN.md §1 rule 4) — the ONLY sanctioned way to
/// render a display role.
///
/// Monochrome contract (2026-08-26 user directive): renders [text] VERBATIM
/// in Playfair Display bold, flat [AppColors.white]. No case transformation,
/// no gradient fills, no shimmer, no glow — static glyphs, zero tickers
/// (reduced-motion safe by construction).
class VDisplayText extends StatelessWidget {
  /// Display copy — rendered exactly as written.
  final String text;

  /// Glyph size in logical px (default 40 — [AppTypography.displayMedium]).
  final double size;

  /// Optional alignment (the parent may already center the text).
  final TextAlign? textAlign;

  /// Optional max line count for long display copy.
  final int? maxLines;

  const VDisplayText({
    super.key,
    required this.text,
    this.size = 40,
    this.textAlign,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: _displayStyle(),
    );
  }

  /// Playfair Display bold at [VDisplayText.size] — the display roles when
  /// the size matches a §3.3 token, otherwise a same-metric custom style
  /// (no italics — user directive 2026-08-14). Neutral tracking — the
  /// display voice breathes; cramped tracking reads "old".
  TextStyle _displayStyle() {
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
    return base.copyWith(color: AppColors.white);
  }
}
