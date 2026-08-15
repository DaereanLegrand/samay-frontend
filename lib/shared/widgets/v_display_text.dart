import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// LUXE v2 display voice (XL-03) — the ONLY sanctioned way to render a
/// display role (ORCHESTRATION-LUXE directive #6).
///
/// Renders [text] in Playfair Display bold, ALWAYS UPPERCASE — the MAYUS
/// rule is enforced here via `text.toUpperCase()`, never at call sites. No
/// italics (user directive 2026-08-14).
///
/// Two layers, back to front:
///
/// 1. The glyph fill: a `ShaderMask` over [AppGradients.textShader]
///    (gradient fill — LUXE directive #2: never flat accents); pure white
///    when [gradient] is null.
/// 2. A once-only shimmer sweep (900ms): a soft white band gliding across
///    the GLYPHS on first build (inside the letters — the glow never
///    bleeds outside them). Completes and stops — no pending timers.
///
/// NO EXTERNAL GLOW (user directive 2026-08-12: "glowing pulsation outside
/// letters must be deleted") — there is deliberately no halo/boxShadow
/// behind the text; the ambient glow lives in the screen's [VAurora] and
/// the glass/button halos, never around the glyphs.
///
/// Reduced motion (`MediaQuery.disableAnimationsOf(context)`) → static
/// glyphs, no shimmer sweep, no tickers (§6.2/§7.5).
class VDisplayText extends StatefulWidget {
  /// Display copy — rendered UPPERCASE (the MAYUS rule).
  final String text;

  /// Glyph size in logical px (default 40 — [AppTypography.displayMedium]).
  final double size;

  /// The screen's gradient family (violet/cyan/gold/mint/peach/...). Null →
  /// the glyphs render white.
  final AppGradient? gradient;

  /// Optional alignment (the parent may already center the text).
  final TextAlign? textAlign;

  /// Optional max line count for long display copy.
  final int? maxLines;

  /// The once-only glyph shimmer sweep.
  static const Duration shimmerDuration = Duration(milliseconds: 900);

  /// Whether [gradient] is banned on glyphs — null and the cyan (skyblue)
  /// family render WHITE (user directive 2026-08-14); every other family
  /// keeps its gradient fill.
  static bool rendersWhite(AppGradient? gradient) =>
      gradient == null || gradient.name == 'cyan';

  const VDisplayText({
    super.key,
    required this.text,
    this.size = 40,
    this.gradient,
    this.textAlign,
    this.maxLines,
  });

  @override
  State<VDisplayText> createState() => _VDisplayTextState();
}

class _VDisplayTextState extends State<VDisplayText>
    with SingleTickerProviderStateMixin {
  /// The once-only shimmer sweep — completes at 1.0 and never restarts.
  late final AnimationController _shimmer = AnimationController(
    vsync: this,
    duration: VDisplayText.shimmerDuration,
  );

  /// The sweep runs exactly once, on the first non-reduced build.
  bool _shimmerStarted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _shimmer.stop();
      _shimmer.value = 0;
    } else if (!_shimmerStarted) {
      _shimmerStarted = true;
      _shimmer.forward();
    }
  }

  @override
  void dispose() {
    _shimmer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: _textShader,
          child: Text(
            widget.text.toUpperCase(),
            textAlign: widget.textAlign,
            maxLines: widget.maxLines,
            overflow: widget.maxLines == null ? null : TextOverflow.ellipsis,
            style: _displayStyle(),
          ),
        ),
        if (!reduced) Positioned.fill(child: _shimmerOverlay()),
      ],
    );
  }

  /// Gradient glyph fill — [AppGradients.textShader] over the text bounds;
  /// a white→white shader when [rendersWhite] (no family, or the banned
  /// skyblue/cyan family — user directive 2026-08-14).
  Shader _textShader(Rect bounds) {
    if (VDisplayText.rendersWhite(widget.gradient)) {
      return const LinearGradient(
        colors: [AppColors.white, AppColors.white],
      ).createShader(bounds);
    }
    return AppGradients.textShader(widget.gradient!, bounds);
  }

  /// Once-only sweep: a soft white band gliding diagonally across the glyphs
  /// (alignment-driven — no pixel math). Off-screen at t=1 → invisible.
  Widget _shimmerOverlay() {
    return IgnorePointer(
      child: ClipRect(
        child: AnimatedBuilder(
          animation: _shimmer,
          builder: (context, _) {
            final t = _shimmer.value;
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1.0 + 2.0 * t, -1.0 + 1.5 * t),
                  end: Alignment(0.0 + 2.0 * t, 1.0 + 1.5 * t),
                  colors: [
                    AppColors.white.withValues(alpha: 0.0),
                    AppColors.white.withValues(alpha: 0.45),
                    AppColors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Playfair Display bold at [VDisplayText.size] — the display roles when
  /// the size matches a §3.3 token, otherwise a same-metric custom style
  /// (no italics — user directive 2026-08-14). The glyph color is white so
  /// the ShaderMask owns the fill.
  /// Uppercase Playfair keeps neutral tracking — no negative letter-spacing
  /// (the LUXE display voice breathes; cramped tracking reads "old").
  TextStyle _displayStyle() {
    final base = switch (widget.size) {
      64 => AppTypography.displayLarge,
      40 => AppTypography.displayMedium,
      32 => AppTypography.displaySmall,
      28 => AppTypography.headlineLarge,
      _ => TextStyle(
        fontFamily: AppTypography.playfair,
        fontSize: widget.size,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.0,
        height: 1.0,
      ),
    };
    return base.copyWith(color: AppColors.white);
  }
}
