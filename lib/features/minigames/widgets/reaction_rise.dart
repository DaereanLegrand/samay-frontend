import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';

/// The emoji glyph for one [ReactionKind] (201). Inter's monochrome heart
/// inherits [AppColors.badgeRed]; the color-emoji faces ignore the color.
///
/// Shared by the in-match reaction deck, the rising reaction particles and the
/// finished leaderboard's per-answer tallies.
class ReactionEmoji extends StatelessWidget {
  final ReactionKind kind;
  final double fontSize;

  const ReactionEmoji({
    super.key,
    required this.kind,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      reactionEmoji[kind]!,
      style: TextStyle(
        fontSize: fontSize,
        // Inter's monochrome heart glyph inherits this color; the color-emoji
        // faces of the non-heart reactions are unaffected by it.
        color: kind == ReactionKind.heart ? AppColors.badgeRed : null,
      ),
    );
  }
}

/// The geometry + identity of ONE rising particle (a single reaction event).
class RiseSpec {
  const RiseSpec({required this.id, required this.kind});

  final int id;
  final ReactionKind kind;
}

/// One rising reaction emoji (realtime echo): spawns slightly below the
/// card's bottom edge, floats straight up the full card height and exits
/// slightly above the top edge. The glyph's top-left is fully off-canvas at
/// both extremes so it is fully hidden exactly at start/end; a brief
/// fade-in/fade-out envelope blurs the enter/exit.
///
/// The emoji renders LARGE and, per user spec, sways while it rises: each
/// particle gets a RANDOM horizontal wobble (frequency + amplitude drawn once
/// per particle — e.g. ~2.5 ± 1 sinusoidal cycles over the rise with a
/// ~12 ± 6 px swing) and a random horizontal lane + a small random stagger so
/// a burst of reactions looks lively rather than a rigid column. One-shot,
/// [SamayDurations.reactionFloat]. Reduced motion never creates a particle
/// (the owning canvas gate skips spawns entirely).
class RisingReactionParticle extends StatefulWidget {
  const RisingReactionParticle({
    super.key,
    required this.spec,
    required this.width,
    required this.height,
    required this.onDone,
  });

  final RiseSpec spec;
  final double width;
  final double height;
  final VoidCallback onDone;

  @override
  State<RisingReactionParticle> createState() =>
      _RisingReactionParticleState();
}

class _RisingReactionParticleState extends State<RisingReactionParticle>
    with SingleTickerProviderStateMixin {
  /// The large render size of a rising reaction emoji (user spec — the rise
  /// must be clearly bigger than the deck's ~24 px tiles).
  static const double _fontSize = 44;

  /// How far the glyph must clear the card edge to be FULLY hidden (fully
  /// on-canvas starts being visible the instant any pixel crosses the edge).
  static const double _edgeClear = 4;

  /// The horizontal fraction of the card width the glyph's lane sits at — the
  /// rise starts from a random lane so reactions don't stack in one column.
  late final double _dx;

  /// Sinusoidal sway frequency: how many full back-and-forth cycles the emoji
  /// completes over one rise (randomized per particle — "random frequency").
  late final double _wobbleCycles;

  /// Sinusoidal sway amplitude in logical px (randomized per particle —
  /// "random amplitude").
  late final double _wobbleAmplitude;

  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SamayDurations.reactionFloat,
  );

  /// Rise path: fully below the bottom edge → fully above the top edge.
  late final Animation<double> _top =
      Tween<double>(
        begin: widget.height + _edgeClear,
        end: -(_fontSize + _edgeClear),
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: SamayDurations.defaultCurve,
        ),
      );

  /// Fade in over the first ~18% of the travel (below → entering), hold, then
  /// fade out over the last ~18% (exiting → fully hidden above).
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.0,
        end: 1.0,
      ).chain(CurveTween(curve: Curves.easeOut)),
      weight: 18,
    ),
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 64),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.0,
        end: 0.0,
      ).chain(CurveTween(curve: Curves.easeIn)),
      weight: 18,
    ),
  ]).animate(_controller);

  Timer? _stagger;

  @override
  void initState() {
    super.initState();
    _dx = 0.12 + Random().nextDouble() * 0.76;
    // Random wobble per particle: ~1.5–3.5 cycles over the rise and a
    // ~6–18 px horizontal swing. Both are chosen once so the sway is smooth.
    _wobbleCycles = 1.5 + Random().nextDouble() * 2.0;
    _wobbleAmplitude = 6 + Random().nextDouble() * 12;
    // Small random stagger so a burst of reactions arrives with life rather
    // than as one rigid column (the owning canvas is the reduced-motion gate —
    // it never spawns a particle when animations are disabled).
    _stagger = Timer(Duration(milliseconds: Random().nextInt(320)), () {
      if (!mounted) return;
      _controller.forward().whenCompleteOrCancel(widget.onDone);
    });
  }

  @override
  void dispose() {
    _stagger?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// The horizontal sway offset at rise progress [t] (0 → 1): a sinusoid of
  /// the particle's random frequency × amplitude.
  double _sway(double t) {
    return _wobbleAmplitude * sin(2 * pi * _wobbleCycles * t);
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      // Horizontal: fraction of the card width (card can be wide) so the
      // glyph never hugs the very edges. Width animated freely — the canvas
      // treats the glyph's top-left as its origin and clips at the edges.
      left: widget.width * _dx,
      top: 0,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(_sway(_controller.value), _top.value),
            child: Opacity(opacity: _opacity.value, child: child),
          );
        },
        child: ReactionEmoji(kind: widget.spec.kind, fontSize: _fontSize),
      ),
    );
  }
}
