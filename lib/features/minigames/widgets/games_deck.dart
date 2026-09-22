import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_display_text.dart';

/// The Games tab's card — ONE card, centred, no stack and no animation.
///
/// The current game is rendered as a single centred card; a horizontal swipe
/// swaps it for the next / previous game instantly (circular), and a tap opens
/// that game's page. No other cards are drawn.
///
/// Pure widget: no provider dependency, so static data can drive it.
class GamesDeck extends StatefulWidget {
  const GamesDeck({
    super.key,
    required this.games,
    required this.pendingByType,
    required this.onOpen,
  });

  /// The plugged minigames, in deck order.
  final List<MinigameType> games;

  /// Pending invite counts keyed by `game_type` value (the red badge source).
  final Map<String?, int> pendingByType;

  /// Opens the game page for the centred card.
  final ValueChanged<MinigameType> onOpen;

  @override
  State<GamesDeck> createState() => _GamesDeckState();
}

class _GamesDeckState extends State<GamesDeck> {
  /// The current game's index into [GamesDeck.games].
  int _index = 0;

  /// Accumulated horizontal drag of the in-flight gesture (px).
  double _dragDx = 0;

  /// Card width / height as a fraction of the available box. The card is then
  /// scaled 1.5x, width eased 0.8x and height eased 0.72x (0.6x then +1.2x,
  /// human directive).
  static const double _widthFactor = 0.72;
  static const double _heightFactor = 0.70;
  static const double _sizeScale = 1.5;
  static const double _widthScale = 0.8;
  static const double _heightScale = 0.72;

  /// width / height: `0.72 × (0.8 / 0.72) = 0.8`.
  static const double _aspect = 0.72 * (_widthScale / _heightScale);

  /// How far down the `cur - 1` card sits (fraction of the half-box below the
  /// centred card), so it reads between the current card and the nav bar.
  static const double _prevGapFactor = 0.62;

  /// Maximum random tilt of the `cur - 1` card (±15°) and of the card placed
  /// above (`cur + 1`, a slighter ±8°).
  static const double _prevMaxRotation = 15 * math.pi / 180;
  static const double _nextMaxRotation = 8 * math.pi / 180;

  /// Maximum random sideways shift of a behind card (fraction of the viewport
  /// width — ±10vw).
  static const double _behindMaxXFactor = 0.10;

  /// Drag past this distance, or a fling past this velocity, steps the deck.
  static const double _dragDistance = 40;
  static const double _dragVelocity = 220;

  void _step(int dir) {
    final n = widget.games.length;
    if (n <= 1) return;
    setState(() => _index = ((_index + dir) % n + n) % n);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    _dragDx += details.delta.dx;
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dx = _dragDx;
    _dragDx = 0;
    // Finger left (negative) reveals the next card.
    if (dx <= -_dragDistance || velocity <= -_dragVelocity) {
      _step(1);
    } else if (dx >= _dragDistance || velocity >= _dragVelocity) {
      _step(-1);
    }
  }

  /// A stable random placement for a behind card — tilt (up to [maxRotation])
  /// + sideways shift — seeded by its list index, so it never jitters between
  /// rebuilds.
  ({double rotation, double x}) _behindPlacement(
    int index,
    double maxRotation,
  ) {
    final rng = math.Random(index * 7919 + 17);
    return (
      rotation: (rng.nextDouble() * 2 - 1) * maxRotation,
      x: (rng.nextDouble() * 2 - 1) * _behindMaxXFactor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final games = widget.games;
    if (games.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
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

        final n = games.length;
        final current = games[_index];
        final prevIndex = ((_index - 1) % n + n) % n;
        final nextIndex = ((_index + 1) % n + n) % n;
        final prev = _behindPlacement(prevIndex, _prevMaxRotation);
        final next = _behindPlacement(nextIndex, _nextMaxRotation);
        final viewportWidth = MediaQuery.sizeOf(context).width;

        final centerX = width / 2;
        final centerY = height / 2;
        // The behind cards sit the same distance apart vertically — `cur - 1`
        // below (between the current card and the nav bar) and `cur + 1` above
        // — each with a stable random tilt + sideways shift. `Clip.none` lets
        // them run past the body edges; the lower one passes under the floating
        // nav pill.
        final gapDy = (height / 2) * _prevGapFactor;
        final prevLeft = centerX + prev.x * viewportWidth - cardW / 2;
        final nextLeft = centerX + next.x * viewportWidth - cardW / 2;
        // Only show the upper card once there are at least 3 games, so its
        // index never collides with the lower one.
        final showNext = n >= 3;

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: SizedBox.expand(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // cur + 1, behind and ABOVE (-Y).
                if (showNext)
                  Positioned(
                    left: nextLeft,
                    top: centerY - gapDy - cardH / 2,
                    width: cardW,
                    height: cardH,
                    child: Transform.rotate(
                      angle: next.rotation,
                      child: IgnorePointer(
                        child: Opacity(
                          opacity: 0.55,
                          child: _card(context, games[nextIndex]),
                        ),
                      ),
                    ),
                  ),
                // cur - 1, behind and BELOW (+Y).
                Positioned(
                  left: prevLeft,
                  top: centerY + gapDy - cardH / 2,
                  width: cardW,
                  height: cardH,
                  child: Transform.rotate(
                    angle: prev.rotation,
                    child: IgnorePointer(
                      child: Opacity(
                        opacity: 0.55,
                        child: _card(context, games[prevIndex]),
                      ),
                    ),
                  ),
                ),
                // cur, centred on top.
                Positioned(
                  left: centerX - cardW / 2,
                  top: centerY - cardH / 2,
                  width: cardW,
                  height: cardH,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => widget.onOpen(current),
                    child: _card(context, current),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _card(BuildContext context, MinigameType type) {
    return _DeckCard(
      type: type,
      name: minigameGameName(AppLocalizations.of(context), type.value),
      pending: widget.pendingByType[type.value] ?? 0,
    );
  }
}

/// One deck card: monochrome rounded face (the sanctioned rounded-surface
/// exception — DESIGN.md §3), game icon + Playfair name, and the pending
/// invite badge. Strictly monochrome: `surfaceAlt` fill with a 1px `muted`
/// outline.
class _DeckCard extends StatelessWidget {
  const _DeckCard({
    required this.type,
    required this.name,
    required this.pending,
  });

  final MinigameType type;
  final String name;
  final int pending;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: name,
      button: true,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppColors.muted),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    minigameIcon(type),
                    color: AppColors.white,
                    size: AppIconSizes.xxl,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: VDisplayText(
                      text: name,
                      size: 24,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                    ),
                  ),
                ],
              ),
            ),
            if (pending > 0)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: VCountBadge(count: pending),
              ),
          ],
        ),
      ),
    );
  }
}
