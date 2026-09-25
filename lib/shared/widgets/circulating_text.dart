import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';

/// A single-line text that stays put when it fits and circulates (a seamless
/// horizontal marquee) when it is wider than the space it is given.
///
/// This is the generic sibling of the Games-tab [GameNameBand]: the feed uses
/// it for card titles so a long name never wraps to a second row — it either
/// renders whole or scrolls as a ring of repeated units.
///
/// Reduced motion (`MediaQuery.disableAnimationsOf`) freezes the strip on its
/// first unit with no ticker.
class CirculatingText extends StatefulWidget {
  const CirculatingText({
    super.key,
    required this.text,
    required this.style,
    this.gap = AppSpacing.xl,
    this.speed = 28,
  });

  final String text;
  final TextStyle style;

  /// Trailing gap between repetitions (the seam).
  final double gap;

  /// Constant scroll speed in logical px/s.
  final double speed;

  @override
  State<CirculatingText> createState() => _CirculatingTextState();
}

class _CirculatingTextState extends State<CirculatingText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  double _unitWidth = 0;
  double? _cachedWidth;
  double? _cachedScale;

  @override
  void didUpdateWidget(CirculatingText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.style != widget.style ||
        oldWidget.gap != widget.gap) {
      _cachedWidth = null;
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
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final textWidth = _textWidthFor(scaler);
        final fits = textWidth <= width;

        if (fits) {
          _stop();
          return _line();
        }

        final unit = textWidth + widget.gap;
        _syncMotion(reduced, unit);
        final copies = unit <= 0 ? 1 : ((width + unit) / unit).ceil() + 1;

        final row = OverflowBox(
          alignment: Alignment.centerLeft,
          maxWidth: double.infinity,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < copies; i++)
                Padding(
                  padding: EdgeInsets.only(right: widget.gap),
                  child: _line(),
                ),
            ],
          ),
        );

        return ClipRect(
          child: reduced
              ? row
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(-_controller.value * unit, 0),
                    child: child,
                  ),
                  child: row,
                ),
        );
      },
    );
  }

  Widget _line() => Text(
    widget.text,
    style: widget.style,
    maxLines: 1,
    softWrap: false,
    overflow: TextOverflow.visible,
  );

  double _textWidthFor(TextScaler scaler) {
    final scale = scaler.scale(1);
    final cached = _cachedWidth;
    if (cached != null && _cachedScale == scale) return cached;
    final painter = TextPainter(
      text: TextSpan(text: widget.text, style: widget.style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: scaler,
    )..layout();
    _cachedScale = scale;
    _cachedWidth = painter.width;
    return painter.width;
  }

  void _syncMotion(bool reduced, double unit) {
    if (unit <= 0 || reduced) {
      _stop();
      return;
    }
    if ((unit - _unitWidth).abs() > 0.5) {
      _unitWidth = unit;
      _controller.duration = Duration(
        microseconds: math.max(1, (unit / widget.speed * 1000000).round()),
      );
      _controller.repeat();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  void _stop() {
    if (_controller.isAnimating) _controller.stop();
  }
}
