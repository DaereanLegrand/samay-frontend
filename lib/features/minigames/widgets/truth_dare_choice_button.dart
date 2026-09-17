import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/theme/samay_durations.dart';

/// A full-width, chrome-less Verdad / Reto choice CTA (user directive
/// 2026-09-15).
///
/// No background, no border — just the label in bold **Playfair Display** at a
/// display size. The shadow lives on the GLYPHS themselves (a soft light-gray
/// text shadow), never on a box.
///
/// Press feedback: while the finger is down the LABEL shrinks (a slow ease) and
/// its glyph shadow GROWS. The growth is logarithmic over the hold time and
/// saturates at a maximum spread — so a quick tap only breathes a little, while
/// a long hold approaches the full halo ([SamayDurations.choiceHold]). The
/// shadow has NO direction (centered, offset-free). On release the label eases
/// back out with a soft overshoot (`Curves.easeOutBack`).
class TruthDareChoiceButton extends StatefulWidget {
  const TruthDareChoiceButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback? onPressed;

  @override
  State<TruthDareChoiceButton> createState() => _TruthDareChoiceButtonState();
}

class _TruthDareChoiceButtonState extends State<TruthDareChoiceButton>
    with TickerProviderStateMixin {
  /// Label scale: 1 = resting, 1 = fully pressed target. Deliberately slow
  /// (user spec) with an easing return that overshoots slightly.
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: SamayDurations.standard,
    reverseDuration: SamayDurations.standard,
  );

  /// Shadow hold: 0 → 1 over [SamayDurations.choiceHold] while the finger stays
  /// down; saturates at 1 (the maximum spread) for a long hold. Returns quickly
  /// on release.
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: SamayDurations.choiceHold,
    reverseDuration: SamayDurations.standard,
  );

  late final Animation<double> _scale =
      Tween<double>(begin: 1.0, end: 0.92).animate(
        CurvedAnimation(
          parent: _press,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeOutBack,
        ),
      );

  static const TextStyle _base = TextStyle(
    fontFamily: AppTypography.playfair,
    fontSize: 72,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.4,
    height: 1.1,
    color: AppColors.white,
  );

  /// Resting and maximum glyph-shadow geometry (offset-free — no direction).
  /// Four layered halos: a hard bright core, mid, wide, and an ultra-wide
  /// bloom, so the glow reads BIG and strong even on a black page.
  static const double _idleTightBlur = 18;
  static const double _maxTightBlur = 90;
  static const double _idleTightAlpha = 0.75;
  static const double _maxTightAlpha = 1.0;
  static const double _idleMidBlur = 48;
  static const double _maxMidBlur = 200;
  static const double _idleMidAlpha = 0.55;
  static const double _maxMidAlpha = 1.0;
  static const double _idleWideBlur = 100;
  static const double _maxWideBlur = 420;
  static const double _idleWideAlpha = 0.40;
  static const double _maxWideAlpha = 0.95;
  static const double _idleUltraBlur = 180;
  static const double _maxUltraBlur = 720;
  static const double _idleUltraAlpha = 0.28;
  static const double _maxUltraAlpha = 0.85;

  /// Logarithmic 0 → 1 ramp with a hard cap: fast at first, then flattening to
  /// the maximum spread. `k` controls how quickly it saturates.
  static double _logGrowth(double t) {
    const k = 30.0;
    return math.log(1 + k * t) / math.log(1 + k);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void dispose() {
    _press.dispose();
    _hold.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    _press.forward();
    _hold.forward();
  }

  void _handleRelease() {
    if (_press.isForwardOrCompleted) _press.reverse();
    if (_hold.isForwardOrCompleted) _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: InkWell(
        onTap: widget.onPressed,
        onTapDown: enabled ? _handleTapDown : null,
        onTapUp: enabled ? (_) => _handleRelease() : null,
        onTapCancel: enabled ? _handleRelease : null,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: Container(
          // A taller full-width row: the label stays vertically centered
          // against the container's own height (no chrome, tap target only).
          constraints: const BoxConstraints(minHeight: 208),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: AnimatedBuilder(
            animation: Listenable.merge([_press, _hold]),
            builder: (context, _) {
              final g = _logGrowth(_hold.value);
              return Transform.scale(
                scale: _scale.value,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: _base.copyWith(
                    shadows: [
                      Shadow(
                        color: AppColors.white.withValues(
                          alpha: _lerp(_idleUltraAlpha, _maxUltraAlpha, g),
                        ),
                        blurRadius: _lerp(_idleUltraBlur, _maxUltraBlur, g),
                      ),
                      Shadow(
                        color: AppColors.white.withValues(
                          alpha: _lerp(_idleWideAlpha, _maxWideAlpha, g),
                        ),
                        blurRadius: _lerp(_idleWideBlur, _maxWideBlur, g),
                      ),
                      Shadow(
                        color: AppColors.white.withValues(
                          alpha: _lerp(_idleMidAlpha, _maxMidAlpha, g),
                        ),
                        blurRadius: _lerp(_idleMidBlur, _maxMidBlur, g),
                      ),
                      Shadow(
                        color: AppColors.white.withValues(
                          alpha: _lerp(_idleTightAlpha, _maxTightAlpha, g),
                        ),
                        blurRadius: _lerp(_idleTightBlur, _maxTightBlur, g),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
