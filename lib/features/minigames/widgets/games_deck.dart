import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// The Games tab's card deck — a vertical, finger-tracked stack.
///
/// At rest: the current game is a centred, upright card; `cur - 1` sits behind
/// and BELOW it and `cur + 1` sits behind and ABOVE it, each carrying a stable
/// random tilt + sideways shift seeded by its list index (so a card keeps its
/// "tossed" pose) — [GamesDeck.games] order is the circular deck order.
///
/// A **vertical** drag moves the deck. The gesture is two-phase:
/// 1. **Hero on its track** — the centred card follows the finger vertically
///    while its horizontal offset is LOCKED to a quadratic-Bézier arc
///    (`x = t² · targetX`), so the finger can never pull the card off its
///    connecting curve. The other cards hold their pose with a slight drift.
/// 2. **Deck catch-up** — the moment the hero crosses [GamesDeck._arrival],
///    the remaining cards animate along their own arcs into the new slots
///    (the incoming card rises to the centre, the outgoing card leaves toward
///    the viewport edge, and a freshly-initialised random card curves in from
///    beyond the opposite edge).
///
/// The offset is **unbounded**: dragging past a slot keeps cycling the deck,
/// and a hard throw is projected through several slots (`velocity /
/// _flingDamping`) so the deck keeps flipping instead of locking at one card.
/// Releasing before [GamesDeck._arrival] snaps everything back; otherwise the
/// release velocity drives a [SpringSimulation] that eases the momentum and
/// settles on the projected slot. Reduced motion
/// (`MediaQuery.disableAnimationsOf`) snaps instead of animating.
///
/// Pure widget: no provider dependency, so static data can drive it — the
/// root screen resolves the game list and the pending invite counts and passes
/// them in.
class GamesDeck extends StatefulWidget {
  const GamesDeck({
    super.key,
    required this.games,
    required this.pendingByType,
    required this.onOpen,
    required this.onPlay,
  });

  /// The plugged minigames, in deck order.
  final List<MinigameType> games;

  /// Pending invite counts keyed by `game_type` value (the red badge source).
  final Map<String?, int> pendingByType;

  /// Opens the game page for the centred card (its own tap).
  final ValueChanged<MinigameType> onOpen;

  /// Starts a game immediately from the card's play button.
  final ValueChanged<MinigameType> onPlay;

  @override
  State<GamesDeck> createState() => _GamesDeckState();
}

/// One deck slot: [game] at continuous slot offset [s] (`0` = centred, negative
/// = below, positive = above).
class _DeckSlot {
  const _DeckSlot({required this.game, required this.s});

  final int game;
  final double s;
}

class _GamesDeckState extends State<GamesDeck>
    with SingleTickerProviderStateMixin {
  /// Card width / height as a fraction of the available box, then scaled 1.5x
  /// and eased 0.8x wide / 0.72x tall, with the height gained another 1.1x
  /// (aspect ≈ 0.727) — the stacked deck geometry.
  static const double _widthFactor = 0.72;
  static const double _heightFactor = 0.70;
  static const double _sizeScale = 1.5;
  static const double _widthScale = 0.8;
  static const double _heightScale = 0.72;

  /// The card is 1.1x taller than the eased base height.
  static const double _heightGain = 1.1;

  /// width / height: `0.72 × (0.8 / (0.72 × 1.1)) ≈ 0.727`.
  static const double _aspect =
      0.72 * (_widthScale / (_heightScale * _heightGain));

  /// How far down the `cur - 1` card sits (fraction of the half-box below the
  /// centred card), so it reads between the current card and the nav bar.
  static const double _prevGapFactor = 0.62;

  /// Maximum random tilt of a behind card: `cur - 1` up to ±15°, `cur + 1`
  /// (and the off-viewport card above it) up to ±8°.
  static const double _prevMaxRotation = 15 * math.pi / 180;
  static const double _nextMaxRotation = 8 * math.pi / 180;

  /// Maximum random sideways shift of a behind card (±10vw).
  static const double _behindMaxXFactor = 0.10;

  /// Hero progress (fraction of a slot) at which the deck catch-up starts.
  static const double _arrival = 0.5;

  /// How much of the deck's catch-up the other cards show while the hero is
  /// still on its own track (phase 1) — a slight, deliberate drift.
  static const double _drift = 0.12;

  /// Drag / spring travel is unbounded in slot units — a hard throw carries
  /// through as many cards as its velocity projects (endless-deck feel).

  /// Fling speed (slots/s) that commits a transition even below [_arrival].
  static const double _flingVelocity = 3.0;

  /// Friction-style decay (1/s) used to project a throw's travel:
  /// `slots = velocity / _flingDamping`, so harder throws carry more cards.
  static const double _flingDamping = 4.0;

  /// Momentum spring for the release settle — near-critically damped but soft,
  /// so the deck eases into the next/previous card SLOWLY instead of snapping.
  static const SpringDescription _spring = SpringDescription(
    mass: 1,
    stiffness: 80,
    damping: 18,
  );

  /// Drives every card position (`value` = the unbounded deck offset `_t`).
  late final AnimationController _controller = AnimationController.unbounded(
    vsync: this,
  );

  /// The title pastels in a fresh RANDOM order per deck (i.e. per app launch).
  /// Each card reads the order starting at its own index, so the four games
  /// always differ from one another while the assignment itself is arbitrary.
  late final List<Color> _pastelOrder = [..._DeckTitle.pastels]
    ..shuffle(math.Random());

  /// Index of the centred game (committed).
  int _index = 0;

  /// The vertical distance between two slots (px), cached from the last build
  /// so the gesture handler can convert pixels to slot units.
  double _gapDy = 1;

  /// The slot target the running spring is settling on, or null when idle.
  double? _settleTarget;

  /// Continuous, unbounded deck offset in slot units: `0` = rest, `±1` = one
  /// card on, `±3` = three cards on.
  double get _t => _controller.value;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDragStart(DragStartDetails details) {
    _settleTarget = null;
    _controller.stop();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (widget.games.length <= 1) return;
    // Unbounded: dragging past a slot keeps cycling the deck instead of
    // locking at one position. Inverted vs the raw delta: an upward drag
    // reveals the card above.
    _controller.value = _controller.value - details.delta.dy / _gapDy;
  }

  void _onDragEnd(DragEndDetails details) {
    final n = widget.games.length;
    if (n <= 1) {
      _controller.value = 0;
      return;
    }

    final velocitySlots = -(details.primaryVelocity ?? 0) / _gapDy;
    final value = _controller.value;
    final double target;
    if (velocitySlots.abs() >= _flingVelocity) {
      // A throw: project the travel with friction-style decay and land on an
      // integer slot, so a harder throw flips more cards (no per-step lock).
      target = (value + velocitySlots / _flingDamping).roundToDouble();
    } else if (value.abs() >= _arrival) {
      target = value.roundToDouble();
    } else {
      target = 0;
    }

    _settleTo(target, velocitySlots);
  }

  /// A cancelled gesture (another recognizer won) still has to land the deck,
  /// so it settles like a slow release.
  void _onDragCancel() {
    final value = _controller.value;
    _settleTo(value.abs() >= _arrival ? value.roundToDouble() : 0, 0);
  }

  /// Settles `_t` on [target] from the current value with [velocitySlots] of
  /// throw momentum (0 for a slow release/scroll snap).
  void _settleTo(double target, double velocitySlots) {
    final value = _controller.value;
    if (target == 0 && value == 0) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _finish(target);
      return;
    }
    _settleTarget = target;
    _controller
        .animateWith(SpringSimulation(_spring, value, target, velocitySlots))
        .whenComplete(_onSettled);
  }

  void _onSettled() {
    if (!mounted) return;
    final target = _settleTarget;
    if (target == null) return;
    // Interrupted by a new gesture: the value won't be at the target.
    if ((_controller.value - target).abs() > 0.02) return;
    _finish(target);
  }

  /// Commits a settled transition: `target == 0` re-bases to rest, otherwise
  /// advances `round(target)` games and re-bases in the same frame (invisible —
  /// slots are computed relative to the new [_index]).
  void _finish(double target) {
    final steps = target.round();
    if (steps == 0) {
      _settleTarget = null;
      setState(() => _controller.value = 0);
      return;
    }
    final n = widget.games.length;
    _settleTarget = null;
    setState(() {
      _index = ((_index + steps) % n + n) % n;
      _controller.value = 0;
    });
  }

  /// The deck progress the non-hero cards follow: a slight drift while the
  /// hero is on its own track, then a fast catch-up that lands exactly with
  /// the hero at a full step.
  double _deckProgress(double t) {
    final at = t.abs();
    if (at <= _arrival) return _drift * t;
    final rem = ((at - _arrival) / (1 - _arrival)).clamp(0.0, 1.0);
    final p =
        _drift * _arrival +
        (1 - _drift * _arrival) * Curves.easeInOut.transform(rem);
    return t.isNegative ? -p : p;
  }

  /// The visible slots around [_index]: a direction-aware four-card window
  /// (the hero, the two neighbours and the off-viewport card the transition
  /// pulls in). Deduped by game (small `|s|` wins) for very short decks.
  List<_DeckSlot> _visibleSlots(int n) {
    final t = _t;
    // Re-base the unbounded offset to the current step so the geometry stays
    // periodic: a throw of ±3 renders as three consecutive transitions.
    final shift = t >= 0 ? t.floor() : t.ceil();
    final localT = t - shift;
    final base = _index + shift;
    final tDeck = _deckProgress(localT);
    final ks = localT < 0 ? const [-2, -1, 0, 1] : const [-1, 0, 1, 2];
    final candidates = <_DeckSlot>[];
    for (final k in ks) {
      final s = k == 0 ? -localT : k - tDeck;
      if (s.abs() > 2.0) continue;
      candidates.add(_DeckSlot(game: ((base + k) % n + n) % n, s: s));
    }
    candidates.sort((a, b) => a.s.abs().compareTo(b.s.abs()));
    final seen = <int>{};
    final result = <_DeckSlot>[];
    for (final c in candidates) {
      if (seen.add(c.game)) result.add(c);
    }
    return result;
  }

  /// Stable random pose for a game (tilt ∈ [-1, 1], sideways ∈ [-1, 1]),
  /// seeded by its list index so it never jitters between rebuilds.
  ({double rot, double x}) _placement(int game) {
    final rng = math.Random(game * 7919 + 17);
    return (rot: rng.nextDouble() * 2 - 1, x: rng.nextDouble() * 2 - 1);
  }

  /// Opacity by absolute slot distance: full at the centre, 0.55 behind,
  /// fading to nothing as the card leaves the viewport.
  double _opacityFor(double as) {
    if (as <= 0.4) return 1.0;
    if (as <= 1.0) return 1.0 - 0.45 * ((as - 0.4) / 0.6);
    if (as <= 1.8) return 0.55 * (1 - (as - 1.0) / 0.8);
    return 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final games = widget.games;
    if (games.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 0.0;
        final height = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 0.0;

        final base = math.min(width * _widthFactor, height * _heightFactor);
        var cardW = base * _sizeScale * _widthScale;
        var cardH = cardW / _aspect;
        if (cardW > width) {
          cardW = width;
          cardH = cardW / _aspect;
        }
        if (cardH > height) {
          cardH = height;
          cardW = cardH * _aspect;
        }

        final gapDy = (height / 2) * _prevGapFactor;
        _gapDy = gapDy > 0 ? gapDy : 1;
        final centerX = width / 2;
        final centerY = height / 2;
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final n = games.length;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: _onDragStart,
          onVerticalDragUpdate: _onDragUpdate,
          onVerticalDragEnd: _onDragEnd,
          onVerticalDragCancel: _onDragCancel,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final slots = _visibleSlots(n);
              // Furthest cards first, the centred one last (on top).
              slots.sort((a, b) => b.s.abs().compareTo(a.s.abs()));
              return SizedBox.expand(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (final slot in slots)
                      _positionedCard(
                        context,
                        l10n,
                        slot,
                        cardW,
                        cardH,
                        centerX,
                        centerY,
                        gapDy,
                        viewportWidth,
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Places one slot on its Bézier arc: vertical follows the finger (or the
  /// deck catch-up), horizontal is the locked quadratic curve `t² · target`.
  Widget _positionedCard(
    BuildContext context,
    AppLocalizations l10n,
    _DeckSlot slot,
    double cardW,
    double cardH,
    double centerX,
    double centerY,
    double gapDy,
    double viewportWidth,
  ) {
    final as = slot.s.abs();
    final t = as.clamp(0.0, 1.0);
    // Quadratic Bézier with the control point on the vertical: the card moves
    // first, then swings sideways into its random behind pose.
    final curve = t * t;

    final place = _placement(slot.game);
    final maxRotation = slot.s < 0 ? _prevMaxRotation : _nextMaxRotation;
    final rotation = place.rot * maxRotation * curve;
    final dx = place.x * _behindMaxXFactor * viewportWidth * curve;
    final dy = slot.s * gapDy;

    final type = widget.games[slot.game];
    final card = _DeckCard(
      name: minigameGameName(l10n, type.value),
      pending: widget.pendingByType[type.value] ?? 0,
      onPlay: () => widget.onPlay(type),
      pastelOrder: _pastelOrder,
      pastelIndex: slot.game,
    );

    return Positioned(
      left: centerX - cardW / 2 + dx,
      top: centerY - cardH / 2 + dy,
      width: cardW,
      height: cardH,
      child: Transform.rotate(
        angle: rotation,
        child: FadeTransition(
          opacity: AlwaysStoppedAnimation(_opacityFor(as)),
          // Only the card nearest the centre is tappable.
          child: as < 0.5
              ? GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onOpen(type),
                  child: card,
                )
              : IgnorePointer(child: card),
        ),
      ),
    );
  }
}

/// One deck card: the rounded face (the sanctioned rounded-surface exception —
/// DESIGN.md §3) with the game name as the centred display title and the
/// circular play control in its bottom-right corner. Nothing else: no
/// circulating bands, no match bubbles. `surfaceAlt` fill with a 1px
/// `mutedForeground` outline.
///
/// The title is the deck's one colour surface: odd lines take soft pastels,
/// even lines are white outlines (see [_DeckTitle]).
class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.name,
    required this.pending,
    required this.onPlay,
    required this.pastelOrder,
    required this.pastelIndex,
  });

  /// Natural-case name, painted lowercase like every other game surface.
  final String name;
  final int pending;

  /// Starts the game from the card's play button.
  final VoidCallback onPlay;

  /// The deck's random pastel order (shared by every card).
  final List<Color> pastelOrder;

  /// Where this card starts in [pastelOrder] — its index in the deck, so no
  /// two cards begin on the same colour.
  final int pastelIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      label: name,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          color: context.palette.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: context.palette.mutedForeground),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // The title is solved against the real text metrics so every
              // line is painted WHOLE — never an ellipsis, never a mid-word cut.
              // A short multi-word name stacks one word per line ("verdad" /
              // "o" / "reto"); a longer one splits in two balanced lines.
              final lines = _cardTitleLines(name);
              final nameSize = _fittedTitleSize(
                lines,
                constraints.maxWidth - AppSpacing.lg * 2,
                math.min(constraints.maxWidth * 0.18, 44.0).clamp(16.0, 44.0),
                MediaQuery.textScalerOf(context),
              );
              return Stack(
                children: [
                  // Title: centred, independent of the button's corner.
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Center(
                        child: _DeckTitle(
                          lines: lines,
                          size: nameSize,
                          order: pastelOrder,
                          start: pastelIndex,
                        ),
                      ),
                    ),
                  ),
                  if (pending > 0)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: VCountBadge(count: pending),
                    ),
                  // Symbol-only primary action: circular, floating in the
                  // bottom-right corner, so it never collides with the title.
                  Positioned(
                    right: AppSpacing.lg,
                    bottom: AppSpacing.lg,
                    child: _PlayButton(
                      label: l10n.minigamesPlayNow,
                      onPressed: onPlay,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The circular play control: `foreground` disc with the play triangle cut in
/// `background`, so it reads on every theme preset. Positioned by the card, so
/// it is independent of whatever it sits next to.
class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.label, required this.onPressed});

  /// Accessibility label ("jugar ahora"). The control paints no text.
  final String label;
  final VoidCallback onPressed;

  /// Diameter of the disc.
  static const double size = 56;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: context.palette.foreground,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              Icons.play_arrow_rounded,
              size: 30,
              color: context.palette.background,
            ),
          ),
        ),
      ),
    );
  }
}

/// Up to this many words a card title stacks one word per line; longer names
/// split into two balanced lines instead (four stacked lines read as a column,
/// not a title).
const int _stackedWordsMax = 3;

/// The title's lines, lowercase: one word per line for names of up to
/// [_stackedWordsMax] words ("verdad o reto" → ["verdad", "o", "reto"]). A
/// longer name splits in two lines balanced by length ("2 mentiras, 1 verdad" →
/// ["2 mentiras,", "1 verdad"], never "2 mentiras, 1" / "verdad").
List<String> _cardTitleLines(String name) {
  final words = name.toLowerCase().trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return const [];
  if (words.length <= _stackedWordsMax) return words;

  final half = words.fold<int>(0, (sum, w) => sum + w.length) / 2;
  var run = 0;
  var split = 1;
  for (var i = 0; i < words.length - 1; i++) {
    run += words[i].length;
    if (run >= half) {
      split = i + 1;
      break;
    }
  }
  return [words.take(split).join(' '), words.skip(split).join(' ')];
}

/// Picks the largest display size in ([min], [max]) at which EVERY line of the
/// title fits on its own single line inside [width] — so the name is painted
/// whole at a stable size instead of being clipped. Falls back to [min] when
/// even that does not fit.
///
/// Measured with the same [VDisplayText.styleFor] metrics the widget paints, at
/// the ambient text scale.
double _fittedTitleSize(
  List<String> lines,
  double width,
  double max,
  TextScaler scaler,
) {
  const double min = 16;
  if (width <= 0 || lines.isEmpty) return max;

  // 2% safety margin: glyph advances round, and the painted line box is a hair
  // wider than the measured paragraph.
  final safeWidth = width * 0.98;

  bool fits(double size) {
    for (final line in lines) {
      final painter = TextPainter(
        text: TextSpan(text: line, style: VDisplayText.styleFor(size)),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        textScaler: scaler,
      )..layout(maxWidth: safeWidth);
      final overflows = painter.didExceedMaxLines;
      painter.dispose();
      if (overflows) return false;
    }
    return true;
  }

  if (fits(max)) return max;
  if (!fits(min)) return min;
  var lo = min; // fits
  var hi = max; // does not
  for (var i = 0; i < 12; i++) {
    final mid = (lo + hi) / 2;
    if (fits(mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

/// The card title, painted line by line with the colour contract the owner
/// asked for: **odd lines** (1st, 3rd, …) take a soft pastel picked **at
/// random** per game; **even lines** (2nd, 4th, …) are painted as a white
/// **outline only** — a stroked foreground with no fill.
///
/// The randomness is seeded by [seed] (the game's name), so every game keeps its
/// own toss instead of the title repainting on every drag frame.
///
/// Deliberate exception to the deck's monochrome rule (same family as the two
/// documented legacy pastel screens): the pastels are the §2.3 gradient tokens,
/// not invented hexes, and they only ever sit on the card's dark surface.
class _DeckTitle extends StatelessWidget {
  const _DeckTitle({
    required this.lines,
    required this.size,
    required this.order,
    required this.start,
  });

  final List<String> lines;
  final double size;

  /// The deck's randomly shuffled pastel order.
  final List<Color> order;

  /// This card's offset into [order].
  final int start;

  /// How far each pastel is pushed toward white for the title ink.
  ///
  /// The §2.3 pastel tokens are gradient ends (already near-white), but as
  /// display-size title glyphs they still read as fully saturated on the card.
  /// Blending them a third of the way to white keeps the hue recognisable while
  /// making the ink read as a *soft* tint (owner directive).
  static const double whitening = 0.35;

  /// The pool the deck shuffles, whitened for title use.
  static final List<Color> pastels = [
    AppColors.pastelRose,
    AppColors.pastelCyan,
    AppColors.pastelGold,
    AppColors.pastelViolet,
    AppColors.pastelMint,
    AppColors.pastelPeach,
  ].map<Color>((c) => tinted(c, whitening)).toList(growable: false);

  /// Blends [color] toward white by [amount] (0 = unchanged, 1 = white).
  static Color tinted(Color color, double amount) {
    final t = amount.clamp(0.0, 1.0);
    return Color.fromARGB(
      255,
      (color.r * 255 + (255 - color.r * 255) * t).round(),
      (color.g * 255 + (255 - color.g * 255) * t).round(),
      (color.b * 255 + (255 - color.b * 255) * t).round(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final base = VDisplayText.styleFor(size);
    // The deck shuffles the pool ONCE per launch; each card reads it from its
    // own index, so the assignment is arbitrary yet every game differs and a
    // multi-line title never repeats a colour.
    final pool = order.isEmpty ? pastels : order;
    var pastelIndex = pool.isEmpty ? 0 : start % pool.length;
    final children = <Widget>[];
    for (var i = 0; i < lines.length; i++) {
      children.add(
        Text(
          lines[i],
          textAlign: TextAlign.center,
          maxLines: 1,
          style: i.isEven
              ? base.copyWith(color: pool[pastelIndex++ % pool.length])
              : _outlineStyle(base, size),
        ),
      );
    }
    return Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  /// A hollow, white-stroked version of [base]: `color` must stay null while
  /// `foreground` is set, so the style is rebuilt instead of copied.
  static TextStyle _outlineStyle(TextStyle base, double size) {
    return TextStyle(
      fontFamily: base.fontFamily,
      fontSize: base.fontSize,
      fontWeight: base.fontWeight,
      letterSpacing: base.letterSpacing,
      height: base.height,
      shadows: base.shadows,
      foreground: Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, size * 0.035)
        ..color = AppColors.white,
    );
  }
}
