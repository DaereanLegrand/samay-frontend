# 2026-09-21 — Games tab: circular "UNO" card deck

## What was built

The Games bottom-nav tab moved from a 2-column grid of four square tiles to a
**fanned card deck** (`GamesDeck`):

- The Games tab shows **ONE card, centred, with no animation**: the current
  game, width `0.8×` and height `0.6×` of the base card (aspect `0.96`),
  scaled `1.5×` and clamped to the box.
- Navigation is **circular**: step forward from the last card → first, step
  back from the first → last (`((i + dir) % n + n) % n`).
- **Horizontal swipe** (40 px or 220 px/s) swaps the card instantly; **tap the
  card** opens that game's page.
- The red pending-invite `VCountBadge` is preserved on the card.

Files:

- `lib/features/minigames/widgets/games_deck.dart` — NEW pure widget (no
  provider dependency; static data can drive it, like the leaderboard
  carousel).
- `lib/features/minigames/screens/games_tab_screen.dart` — grid replaced by
  `VHeaderBar` (fixed header, expanding body) → `GamesDeck`; the screen still
  watches `pendingMinigameInvitesByTypeProvider` and pushes
  `RoutePaths.minigame(type.value)`.
- `lib/core/design_tokens/app_radius.dart` — new `AppRadius.card = 16`, the
  sanctioned rounded-surface exception.
- `docs/design/DESIGN.md` §3 — documents the rounded-card + Playfair-title
  exception and the scattered-stack layout (aspect 0.48, random tilt).

## Decisions made and why

- **Monochrome rounded cards + Playfair titles** (human directive): the deck
  is the one place a card needs a corner radius; `AppRadius.card` keeps that
  explicit instead of repurposing the "unused" scale values.
- **Implicit animations**, then superseded twice: the clock-pointer rewrite
  (single `AnimationController`, finger-driven) and finally the scattered
  stack (implicit `AnimatedPositioned` + `AnimatedRotation`).
- **Z-order snaps** on selection (center drawn last) while positions tween;
  accepted for the minimal scope — the new centre lands on top immediately.
- **`MediaQuery.disableAnimationsOf`** zeroes the durations (reduced motion).
- **~2× the card area** (human review): the deck sizes cards at `0.72 × width`
  / `0.70 × height` of the available box (linear ×1.38 ≈ area ×1.9) instead of
  the first `0.52 / 0.50`, so the fan fills the tab.
- **Muted outlines, no gold** (human review): the gold evaluation marker was
  removed permanently; every card carries a 1px `muted` border (selected =
  `surfaceAlt`, others = `surface`).

## Redesign #1 (same day) — clock-pointer fan (SUPERSEDED)

Human directive: *"redo from 0 … no translation … just the angle … each card
at the same height … like the tip of a clock pointer"* + *"finger slide on
horizontal animation on change"*.

- **Geometry** is now purely angular. Each card is
  `Transform.rotate(angle: slot * 7°, alignment: Alignment.bottomCenter)`.
  Because all cards are stacked on the same centre, the bottom edge is the
  SAME pivot for all of them, and the card's distance from it is constant —
  the pointer length. `slot` is a double in slot units (0 = centre, ±1 = the
  two neighbours), so a card's position and orientation are a single number.
- **Cards at 1.5× the base fraction** (`0.72 × width` / `0.70 × height`),
  clamped to the box so a card never exceeds the screen.
- **Only 3 visible**: `|slot| ≤ 1` shows; opacity fades out to 0 by `|slot| =
  1.6`; the 4th card sits hidden at `|slot| = 2`.
- **Finger-driven + physics settle** (methods 3+5): an UNBOUNDED
  `AnimationController` stores the live slide. `onHorizontalDragUpdate` adds
  `dx / cardWidth` under progressive **rubber-band** resistance past ±1
  (`_withResistance`, saturates ≈ ±1.4). On release the velocity is projected
  forward (`offset + v·0.15 s`), rounded to a step (a flick ≥ 1.2 slots/s
  always completes one), clamped to ±2 steps, then run through a
  `SpringSimulation` (`stiffness 200`, damping ratio 0.85) with the release
  velocity — momentum + a gentle overshoot instead of the old fixed 250 ms
  `easeOutCubic`. `_commit` runs when the spring rests and re-bases to 0 in
  the same frame (rendered slots identical, so the hand-over is invisible).
- **No `AnimatedSlide`, no `AnimatedScale`, no offset constants.** The old
  `_sideDx/_sideDy/_outer*/_tiltTurns` block was deleted.
- The hidden card's wrap from `-2` to `+2` happens while opacity is 0, so the
  slot-unit jump is invisible (this was the one thing the old per-card
  implicit-animation model could not do cleanly).

## Redesign #2 (same day) — scattered stack (SUPERSEDED)

Human directive: *"whole change, remove idea completely. Current card
centered, reduce width 0.8×, height 1.2×. Other cards behind the main card,
up, random position, random rotation."*

- **Card shape**: base `min(0.72·w, 0.70·h)` × `1.5` → then width `0.8×` and
  height `1.2×`, i.e. aspect `0.72 × (0.8/1.2) = 0.48` (tall and narrow).
  Clamped to `0.92·height` so the behind cards have room to peek up.
- **Current card centred, upright, on top.** All others are placed behind it:
  `dy = -(rand·0.10 + 0.02·depth)·cardH` (up), `dx = ±0.07·cardW`, and a random
  tilt of up to ±12°. The randomness is seeded by the card's list index
  (`Random(j·7919 + 17)`), so each card has a stable "tossed" pose.
- **z-order** by `|delta|` descending, so the centred card is always last/top.
- **Implicit `AnimatedPositioned` + `AnimatedRotation`** (250 ms, easeOutCubic,
  zeroed under `MediaQuery.disableAnimationsOf`) — the stack re-settles on a
  horizontal swipe (40 px / 220 px/s). The clock-pointer controller, spring
  simulation, rubber-band and slot maths were all deleted.
- Tap the centred card opens the game; the badge, Playfair name,
  `AppRadius.card` and `muted` border are unchanged.

## Final design (same day) — ONE card, centred, no animation

Human directive: *"Height 0.6x. I want only one card at the center. No
animation, all removed — only one card at the center."*

- `GamesDeck` is now a **single** `_DeckCard` for `games[_index]`, placed with
  a plain `Center` → `SizedBox`. No `Stack` of cards, no behind cards, no
  random placement, no `Animated*` widgets, no controller/simulation.
- **Shape**: width `0.8×`, height `0.6×` of the base card → aspect
  `0.72 × (0.8/0.6) = 0.96`; still scaled `1.5×` and clamped to the box.
- **Interaction**: horizontal swipe (40 px / 220 px/s) swaps the card
  **instantly**; tap opens the game. Circular over the game list.
- `_DeckCard` lost its `selected` flag (always the one card).

## Follow-up (same day) — `cur - 1` below the current card

Human directive: *"the one at index cur - 1, at a y position between the cur
position and nav bar."*

- The deck is now a **two-card `Stack`, still no animation**: the current card
  centred on top, and `games[cur - 1]` behind it (opacity 0.55,
  `IgnorePointer`) with its centre at `centerY + 0.62·(height/2)` — i.e.
  between the current card and the nav bar, clipped at the bottom of the body.
- Both share the same size; only the current card is tappable.

## Follow-up (same day) — nav-bar glass + `cur - 1` random tilt

- **Nav bar was never solid black** — it is the floating pill in
  `main_shell.dart` (`BackdropFilter` blur + `surface` fill + white sheen).
  At the old α0.85 over a black page it *read* as black, so the fill was
  lightened to α0.55, the sheen to α0.22 and the blur to 24 — the content
  behind it now visibly blurs through (liquid-glass). App-wide change, one
  widget.
- The `cur - 1` card now carries a **stable random tilt up to ±15°**
  (`_prevRotation`, seeded by its list index) via `Transform.rotate` — no
  animation.
- Follow-up: the `cur - 1` card also gets a **stable random x shift up to
  ±10vw** (`_behindPlacement`), and the deck `Stack` uses `Clip.none` so the
  card can run UNDER the floating nav pill instead of being cut at the body
  edge. Card height eased another **1.2×** (`_heightScale` 0.6 → 0.72, aspect
  0.96 → 0.8). The nav pill was made much more transparent (`surface` α0.55 →
  **0.25**, sheen α0.22 → **0.30**, blur 24 → **30**) since α0.55 over black
  still read as a solid black bar.
- Follow-up 2: added the mirrored **`cur + 1` card ABOVE** the centre (same
  `gapDy`, `-Y`), with its own stable random tilt (±8°) and ±10vw x shift;
  drawn only when `n >= 3`.
- Follow-up 3: the nav-pill gradient/sheen experiment was **reverted** — the
  user never asked to change the navbar. The real answer came from reading
  `the reference app/lib/shared/widgets/premium_card.dart` + `main_shell.dart`: the reference app's
  glass is `BackdropFilter(blur: 20)` + `surface` at **alpha 0.1** + a `0.2`
  border. Our port had α0.85 (mis-port), which is why the pill read as solid
  black. `main_shell.dart` now uses `surface` α0.1 + white α0.15 sheen + blur
  20 — no gradient.
- The Games screen is now a `Stack`: the deck is `Positioned.fill` below the
  header height, and `VHeaderBar` is the LAST child, so the upper (`cur + 1`)
  card overflows **behind the header/title** instead of covering it.
- Follow-up 4: the opaque-white debug face was **reverted** — the missing
  nav-bar "transparency" was **optical** (the pill's backdrop was a dark card,
  nothing bright to blur), not a rendering bug. The 5px border probe was also
  reverted to the standard **1px** `muted` outline (fill/opacity restored to
  `surfaceAlt` and the behind cards' 0.55 opacity).


## Follow-up 5 (same day) — circulating lowercase name bands

Human directive: *"Each game card. Must change its title position, now 2 rows,
but at top and bottom, icon + name of game (not capitalized). Smaller font.
This are circulating bands of text like a ring."*

- The centred 48px icon + 24px Playfair title was **removed**. Each card now
  carries **two circulating text bands** (`GameNameBand`,
  `lib/features/minigames/widgets/game_name_band.dart`): one flush to the top
  edge and one to the bottom edge, each a single-line row of repeated
  `icon + lowercase game name` units.
- **Playfair via `VDisplayText`, size 18** (below the §3.3 tokens) and the icon
  at `AppIconSizes.sm`; the name is `name.toLowerCase()`, so "Verdad o Reto"
  reads "verdad o reto". `_DeckCard`'s `Semantics(label:)` keeps the natural
  case for screen readers.
- **Opposite directions** (top forward, bottom `reverse: true`) so the two
  bands circulate like a ring. The loop is seamless: the row is translated by
  exactly one unit width and the pattern repeats. Duration scales with the
  measured unit width, so every band scrolls at the same `28 px/s` regardless
  of name length.
- **Band is clipped by `ClipRRect(AppRadius.card)`** so the strip does not
  paint into the rounded corners; the pending `VCountBadge` stays top-right and
  floats over the top band.
- **Reduced motion** (`MediaQuery.disableAnimationsOf`) freezes the band
  (first repetitions, no ticker) and stops the controller. The unit width is
  measured with a `TextPainter` and memoized (`.name` change resets the cache)
  so the drag-time rebuilds do not re-layout text.
- `docs/design/DESIGN.md` §3 Games-deck paragraph updated: the card identity is
  now the two circulating lowercase bands, not a centred 24px title.

## Mistakes / gotchas

**MISTAKE** — scaling a behind-card down moves its top edge DOWN, not up. The
first geometry (`dy = -0.055·cardH`, `scale = 0.83`) left the stacked card
fully hidden: the scale drops its top by `cardH/2·(1-s) ≈ 0.085·cardH`, which
exceeds the lift. Fixed by lifting `_backDy = -0.14` (net peek
`≈ 0.05·cardH`) and keeping `_backScale = 0.82`. Superseded twice the same day
(outer-card fan, then the clock-pointer rewrite, where cards never stack behind
the centre at all) — kept because the scale/offset relationship still applies
to any future stacked layout.

**MISTAKE** — `SliverFillRemaining(hasScrollBody: false)` + the deck's
`LayoutBuilder` = an immediate crash:
`Null check operator used on a null value` at
`RenderViewportBase._paintContents` (`viewport.dart:998`). Chain:
`RenderSliverFillRemaining.performLayout` probes
`child.getMaxIntrinsicHeight(...)`; that query descends into the
`LayoutBuilder`, whose render object refuses intrinsics and throws
(`layout_builder.dart:478`) because answering them would require a
speculative layout of a builder that may mutate the tree. The throw aborts
`performLayout` BEFORE its last line sets `geometry`, so the sliver paints
with `geometry == null` and the viewport's `child.geometry!` force-unwrap
blows. FIX: the Games tab now uses `VHeaderBar` (fixed header + expanding
body) instead of a `CustomScrollView` — the page does not scroll, so the
collapsing `VHeaderSliver` was inert, and the `Expanded` child gives the
`LayoutBuilder` finite constraints with no intrinsic probe. Equivalent at
rest: `VHeaderBar`'s title sits on the same line as the sliver's expanded
title. (`hasScrollBody: true` would also dodge the intrinsic query but
leaves scroll slack up to the header height — rejected.)

## Commands run

```bash
dart analyze lib/features/minigames/widgets/games_deck.dart \
  lib/features/minigames/screens/games_tab_screen.dart \
  lib/core/design_tokens/app_radius.dart   # No issues found!
dart analyze lib                            # No issues found!

# Follow-up 5
dart analyze lib/features/minigames/widgets/game_name_band.dart \
  lib/features/minigames/widgets/games_deck.dart   # No issues found!
```

No backend/migration/RLS change; the Flutter/Dart test trees stay deleted
(directive 2026-08-31). Human to hot reload the running `make dev` to view.
