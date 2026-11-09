import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// One circulating text band for a Games-tab card: a single-line row of
/// `icon + game name` units repeated past the band width, translated one unit
/// per loop so the strip reads as a seamless ring of text.
///
/// Used twice per card — flush to the top edge scrolling one way and flush to
/// the bottom edge scrolling the other ([reverse]) — so the two bands
/// circulate in opposite directions like a ring around the card.
///
/// The name is rendered lowercase by the caller. Scroll speed is constant in
/// px/s across games (the loop duration scales with the measured unit width,
/// so a longer name does not scroll slower).
///
/// Reduced motion (`MediaQuery.disableAnimationsOf`) freezes the band: the
/// first units render statically with no ticker.
class GameNameBand extends StatefulWidget {
  const GameNameBand({
    super.key,
    required this.type,
    required this.name,
    this.reverse = false,
  });

  /// The game whose icon leads every unit.
  final MinigameType type;

  /// Lowercase game name painted after the icon.
  final String name;

  /// When true the band scrolls the opposite way (left→right).
  final bool reverse;

  /// Band strip height (icon box + a hair of vertical padding) — callers (the
  /// deck card) reserve this so the match bubbles never enter the band zones.
  static const double bandHeight = AppIconSizes.sm + AppSpacing.sm;

  @override
  State<GameNameBand> createState() => _GameNameBandState();
}

class _GameNameBandState extends State<GameNameBand>
    with SingleTickerProviderStateMixin {
  /// Glyph size of the band copy — smaller than the old centred title.
  static const double _fontSize = 18;

  /// Trailing gap after each unit (the seam between repetitions).
  static const double _unitGap = AppSpacing.xl;

  /// Band strip height: icon box + a hair of vertical padding.
  static const double _bandHeight = GameNameBand.bandHeight;

  /// Constant scroll speed (logical px/s) shared by every band.
  static const double _speed = 28;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  /// Width of one `icon + name` repetition, cached between builds.
  double _unitWidth = 0;

  /// Memoized repetition width and the text scale it was measured at, so the
  /// per-frame drag rebuilds do not re-run the [TextPainter].
  double? _cachedUnit;
  double? _cachedScale;

  @override
  void didUpdateWidget(GameNameBand oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name) {
      _cachedUnit = null;
      _unitWidth = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = MediaQuery.disableAnimationsOf(context);
    final scaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bandWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        final unit = _unitWidthFor(scaler);
        _syncMotion(reduced, unit);

        final copies = unit <= 0 ? 0 : ((bandWidth + unit) / unit).ceil() + 1;

        final row = OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [for (var i = 0; i < copies; i++) _unitWidget()],
          ),
        );

        return SizedBox(
          height: _bandHeight,
          child: ClipRect(
            child: reduced
                ? row
                : AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final t = widget.reverse
                          ? 1 - _controller.value
                          : _controller.value;
                      return Transform.translate(
                        offset: Offset(-t * unit, 0),
                        child: child,
                      );
                    },
                    child: row,
                  ),
          ),
        );
      },
    );
  }

  /// One `icon + name` repetition, with the trailing seam gap.
  Widget _unitWidget() {
    return Padding(
      padding: const EdgeInsets.only(right: _unitGap),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            minigameIcon(widget.type),
            color: context.palette.foreground,
            size: AppIconSizes.sm,
          ),
          const SizedBox(width: AppSpacing.sm),
          VDisplayText(text: widget.name, size: _fontSize, maxLines: 1),
        ],
      ),
    );
  }

  /// Measured width of one repetition, matching [_unitWidget] exactly (icon
  /// box + gap + glyph advance + seam gap). Shadows do not affect advance, so
  /// the display style can be measured as-is.
  double _unitWidthFor(TextScaler scaler) {
    final scale = scaler.scale(1);
    final cached = _cachedUnit;
    if (cached != null && _cachedScale == scale) return cached;
    final painter = TextPainter(
      text: TextSpan(
        text: widget.name,
        style: VDisplayText.styleFor(_fontSize),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: scaler,
    )..layout();
    final width = AppIconSizes.sm + AppSpacing.sm + painter.width + _unitGap;
    _cachedScale = scale;
    _cachedUnit = width;
    return width;
  }

  /// Keeps the ticker consistent with reduced motion and the measured unit:
  /// duration scales with the unit width so speed stays [_speed] px/s.
  void _syncMotion(bool reduced, double unit) {
    if (unit <= 0 || reduced) {
      if (_controller.isAnimating) _controller.stop();
      return;
    }
    if ((unit - _unitWidth).abs() > 0.5) {
      _unitWidth = unit;
      _controller.duration = Duration(
        microseconds: math.max(1, (unit / _speed * 1000000).round()),
      );
      _controller.repeat();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }
}
