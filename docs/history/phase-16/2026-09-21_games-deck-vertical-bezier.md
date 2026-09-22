# 2026-09-21 — Games tab: vertical two-phase Bézier deck

## What was built

The Games-tab deck (`lib/features/minigames/widgets/games_deck.dart`) moved
from an instant horizontal swipe to a **vertical, finger-tracked, two-phase
Bézier transition**:

- **Phase 1 — hero on its locked track.** The centred card follows the finger
  vertically (`_t -= delta.dy / gapDy` — inverted so an upward drag reveals the
  card above; unbounded). Its horizontal offset is **locked to a
  quadratic-Bézier arc**
  (`dx = randX · 10vw · t²`, `t = |s|`), so horizontal finger movement can
  never pull the card off its connecting curve. The other cards keep their
  pose with a slight `_drift = 0.12` fraction of the transition.
- **Phase 2 — deck catch-up.** The instant the hero crosses `_arrival = 0.5`
  of a slot, the remaining cards leave the drift and animate along their own
  arcs into the new slots: the incoming card rises to the centre, the
  outgoing card leaves toward the viewport edge, and the card beyond it
  (freshly initialised with its stable random pose) curves in from outside the
  viewport. The catch-up remap lands exactly with the hero at a full step.
- **Release — momentum spring.** The release velocity (px/s → slots/s) is fed
  into a `SpringSimulation(mass 1, stiffness 420, damping 34)` via
  `AnimationController.animateWith`; a fling or a release past `_arrival`
  commits, anything earlier snaps back to rest. A commit advances `_index` and
  re-bases `_t` to 0 in the same frame — invisible because every slot is
  computed relative to `_index`.
- **Direction-aware window.** Four slots are rendered: forward shows
  `{-1, 0, 1, 2}` (the off-viewport card above), backward `{-2, -1, 0, 1}`
  (the off-viewport card below). Slots are deduped by game (smallest `|s|`
  wins) so short decks stay correct. Opacity is 1 → 0.55 → 0 across
  `|s| = 0.4 → 1.0 → 1.8`; the furthest cards paint first, the centred last.
- **Tap** opens the slot with `|s| < 0.5`; `Semantics` + the pending-invite
  `VCountBadge` are preserved. Reduced motion
  (`MediaQuery.disableAnimationsOf`) tracks the finger but snaps on release.

## Decisions made and why

- **One controller is the source of truth.** `AnimationController(value: 0,
  lowerBound: -1.6, upperBound: 1.6)` holds `_t`; drag writes `_t`, the spring
  animates `_t`, and a single `AnimatedBuilder` rebuilds the ≤4 cards. No
  per-frame `setState` of the screen.
- **Vertical is finger-locked, horizontal is curve-locked.** The finger only
  drives the vertical slot progress; the sideways swing is a function of that
  progress (`t²`), which is what makes the motion a Bézier arc instead of a
  free drag. A quadratic with its control point on the vertical axis keeps
  `y` linear (so it tracks the finger) while `x` lags — the card moves first,
  then swings out.
- **Drift instead of a hard freeze.** Non-hero cards move a small `_drift`
  fraction during phase 1 (human choice) so the deck breathes without stealing
  the hero's motion; the catch-up then re-couples everything.
- **Spring, not a fixed curve.** The release is velocity-driven, so fast and
  slow flicks settle with matching momentum; the near-critical damping gives a
  single small overshoot.
- **No new dependency.** Hand-rolled core Flutter (`AnimationController`,
  `SpringSimulation`, `Transform`, `FadeTransition`). Patterns informed by the
  Flutter physics-simulation cookbook, the animations API overview, `Curves`/
  `Cubic`, `PathMetric.getTangentForOffset` follow-path recipes and the
  AnimatedBuilder/performance best-practices notes; `flutter_card_swiper` was
  read for parameterization only.

## Follow-up — throws go and go (unbounded offset)

A hard flick used to cap at one card and a long drag used to lock at ±1.6
slots. The offset is now **unbounded**:

- `_controller` is `AnimationController.unbounded` and `_onDragUpdate` no
  longer clamps, so dragging past a slot keeps cycling the deck instead of
  locking.
- `_visibleSlots` re-bases the unbounded `_t` to the current step
  (`shift = t >= 0 ? floor : ceil`, `localT = t - shift`, `base = _index +
  shift`) and renders the periodic geometry, so a throw of ±N reads as N
  consecutive transitions. Integer `_t` renders exactly like a committed rest
  frame — that is what makes a multi-step throw seamless.
- On release, a throw is projected with friction-style decay
  (`target = value + velocity / _flingDamping`, `_flingDamping = 4.0`) and the
  spring settles on that integer slot; `_finish` commits `round(target)` steps
  in one re-base. `_flingVelocity = 3.0` slots/s gates a throw from a slow
  release.

## Follow-up — inverted gesture + taller cards

- **Gesture direction inverted:** a downward drag now moves the deck the other
  way (`_t -= delta.dy / gapDy`, and the fling velocity is negated to match), so
  an upward drag reveals the card above.
- **Card height ×1.1:** `_heightGain = 1.1` multiplies the eased base height,
  giving `_aspect = 0.72 × (0.8 / (0.72 × 1.1)) ≈ 0.727` (was `0.8`) — the card
  is 1.1× taller.

## Mistakes / gotchas

**GOTCHA** — `AnimationController` defaults its `value` to `lowerBound`. The
deck needs to start at rest = `0`, so `value: 0` must be passed explicitly;
omitting it starts the deck at `-1.6` (one whole card off).

**GOTCHA** — a window of five slots `{-2..2}` collides for a four-game deck
(`-2` and `+2` are the same game). Fixed by choosing the window by transition
direction (four distinct slots) and deduping by game, preferring the smallest
`|s|`.

**GOTCHA** — `TickerFuture.whenComplete` can fire when a NEW gesture stops the
running spring, at a value far from the target. `_onSettled` guards with
`|value - target| <= 0.02`, and `_onDragDown` clears `_settleTarget` before
stopping.

**NOTE** — the card is large relative to the viewport (height ≈ 0.6–1.0 of the
body), so a slot at `|s| = 2` is only partially off-screen. The "enters from
outside the viewport" read comes from the opacity ramp (`0` by `|s| = 1.8`)
rather than pure position.

## Commands run

```bash
dart analyze lib/features/minigames/widgets/games_deck.dart   # No issues found!
dart analyze lib/features/minigames/screens/games_tab_screen.dart
dart analyze lib                                              # No issues found!
```

No backend/migration/RLS change; no pub dependency; the Flutter/Dart test trees
stay deleted (directive 2026-08-31). Human to hot reload the running `make dev`
to view.
