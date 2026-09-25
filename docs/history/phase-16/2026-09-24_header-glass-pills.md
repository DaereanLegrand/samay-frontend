# 2026-09-24 — Apple-style glass-pill headers (transparent bar)

Agent: `header-glass-pills`. Branch: `truth-or-dare-leaderboard`.

## What was built

The tab headers' always-transparent bar kept the title row legible with a top
scrim. This session first tried, then abandoned, a header-wide progressive blur
and finally landed on the requested Apple-style treatment: **the title and every
action each get their own blurred glass pill**, and the bar paints nothing else.

- `lib/shared/widgets/v_glass_pill.dart` (new): `VGlassPill` — a stadium capsule
  (`ClipRRect` → `BackdropFilter` blur 20 → `surface` α0.1 fill + white α0.15
  hairline). The exact recipe of `MainShell._FloatingNavBar` / `VPillTabBar`, so
  every glass surface matches. The pill hugs its child (plus optional padding)
  and the child paints ON TOP, un-clipped, so badges spilling past a button
  survive; a square child renders as a circle, a wide one as a capsule.
- `lib/shared/widgets/v_header_bar.dart`:
  - `VHeaderTitleRow` gained `pills`. **Bare** (default) is the historical row.
    **Pills** wraps the back arrow, title and every action in `VGlassPill`,
    shrinking the title to `VHeaderMetrics.pillTitleSize` (28, Playfair
    `headlineLarge`) and using `pillDiameter = titleRowHeight` (48) so the row
    never grows. The optical centerline (`_opticalShift`) is preserved inside the
    title pill; the text action label shift is preserved inside its pill.
  - `_ScrollReactiveHeaderRow` (new, stateful): the pinned sliver can't rebuild
    per scroll frame (`minExtent == maxExtent`), so this listens to the enclosing
    `ScrollPosition` (`Scrollable.maybeOf`) and rebuilds the row; `scrolled`
    flips as soon as `pixels > 0.5`.
  - `VHeaderSliver`: keeps the pinned row + top scrim; the row's `pills` =
    `scrolled`. At rest it is the bare large title; once scrolled it becomes
    pills + the smaller title.
  - `VHeaderBar`: always `pills: true` (a fixed bar is permanently docked over
    its body); the bar paints nothing but the pills.
  - Deleted the whole progressive-blur stack: `_HeaderBackdrop`,
    `_HeaderBlurProgram`, the `headerBlurSigma` / `headerBlurDissolve` metrics,
    the `dart:ui` import, `shaders/header_blur.frag`, and the `flutter: shaders:`
    block in `pubspec.yaml`.
- `docs/design/DESIGN.md` §3: the header bullets rewritten to the glass-pill
  spec (transparent bar, per-element pills, bare-at-rest/scrolled pills, the
  always-pill fixed bar).
- **Morph animation** (same session, user request): `VHeaderTitleRow` now takes
  a `double pillProgress` (0 bare → 1 pills) instead of a bool, and
  `_AnimatedPillHeaderRow` drives it with a 250 ms `AnimationController`
  (`SamayDurations.standard`, instant under reduced motion) that runs forward on
  scroll and reverses back to the top. Every visual is interpolated: title
  40→28, capsule horizontal padding 0→16, back/title gap 12→8, action gaps 0→8,
  bubble `reveal` 0→1 and scale (0.6→1 for back/actions, 0.92→1 for the title).
  The back glyph slides from its bare optical x to the circle centre.
  `VGlassPill.reveal` ramps the blur sigma and the fill/border alpha;
  `VGlassPill.scale` is a plain `Transform` of the bubble ONLY (the child never
  scales). A hidden bubble (`reveal <= 0.001`) skips its `BackdropFilter`, so a
  resting header costs nothing.

## Decisions

- **Pills, not a header-wide blur.** Four blur iterations (banded `BackdropFilter`
  → progressive `ImageFilter.shader` → frost tail → in-band quintic) were all
  rejected on device ("yucky", "too big … MUST ONLY BE header height", "only
  bottom part is blurred" [an inverted-smoothstep bug]). The user's reference was
  Apple's floating glass pills, so the clean answer is a per-element capsule.
- **`VGlassPill` reuses the nav pill recipe** rather than inventing tokens, so a
  header pill and the bottom-nav pill read as the same material.
- **Bare at rest, pills on scroll** for the tab roots; the fixed bar is always
  pills. The row's height/extents are unchanged either way (pill diameter = row
  height) — no layout shift.
- **Scrim kept** (user directive): the bar stays transparent but the top scrim
  gradient still helps the bare title at rest.

## MISTAKES (kept for searchability)

- `overlapsContent` is useless for a pinned sliver: `RenderSliverPinnedPersistent
  Header` computes it as `constraints.overlap > 0`, which is 0 for the first
  sliver (`sliver_persistent_header.dart:423`). The floating header's
  `_effectiveScrollOffset < scrollOffset` at line 684 is a different class. Gate
  on the `ScrollPosition` instead.
- A shader `BackdropFilter` with no `ClipRect` is NOT bounded by its widget: it
  smears the filtered backdrop over the whole viewport. Plain `ImageFilter.blur`
  inside a `ClipRRect` (what `VGlassPill` uses) is bounded correctly.
- A GLSL reserved word (`half`) failed impellerc; `AlignmentDirectional` has no
  `centerLeft` (use `centerStart`).
- **Never wrap `BackdropFilter` in `Opacity`** (or any saveLayer-pushing filter
  widget like `ShaderMask`/`ImageFiltered`): the blur stops working
  (flutter#31706, and flutter#164079 for `ShaderMask`). The first morph attempt
  used `Opacity`; replaced by ramping the blur sigma + tint alpha in
  `VGlassPill.reveal`.

## Commands

```bash
dart analyze lib        # No issues found!
flutter build bundle    # exit 0
```

## Follow-ups

- Visual check on the simulator after the human restarts `make dev` (agent must
  not trigger reloads).
