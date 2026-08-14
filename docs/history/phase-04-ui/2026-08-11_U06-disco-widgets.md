# U-06 — Disco signature widgets: `VGlowText`, `VDiscoDivider`, `VShimmer` + coming-soon wiring (2026-08-11)

**Agent:** U-06 | **Phase:** 04-ui (4.4) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §3.4/§5.7/§5.8/§6.2/§7.5
(read in full — THE CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` +
`docs/process/FILE-OWNERSHIP.md` + `docs/process/DEVELOPMENT-WORKFLOW.md` +
`docs/process/DEVELOPMENT-WORKFLOW.md` (read in full), U-01..U-05 daily logs,
AGENTS.md. Baseline before edits: `dart analyze` 0 issues; full `flutter test`
**1740/0** (U-05 checkpoint).

## What was built

The three missing signature widgets + the barrel, per the mission contract
(U-06's §3.4/§5.7/§5.8 row of the design doc):

| Widget | File | Contract |
|---|---|---|
| `VGlowText` | `lib/shared/widgets/v_glow_text.dart` | §3.4 glow text: wraps a style in the canonical shadow stack |
| `VDiscoDivider` | `lib/shared/widgets/v_disco_divider.dart` | §2.1/§4.2 spirit hairline + glowPink center accent |
| `VShimmer` + `VShimmerBox` | `lib/shared/widgets/v_shimmer.dart` | §5.8/§6.3 skeleton + sweep (U-22's primitive) |
| barrel | `lib/shared/widgets/disco_widgets.dart` | exports all three |

### 1. `VGlowText(text:, style:, soft:, color:, textAlign:)`

- **Const-constructible**; the glow is computed in `build()` because
  `Color.withValues` is non-const and blur radii depend on the resolved
  `style.fontSize` (`em`-relative, like the CSS source `text-shadow`).
- `soft: false` → the glow-strong 3-layer stack (α0.9 @ fontSize×0.35 ·
  α0.5 @ ×0.7 · α0.25 @ ×1.0); `soft: true` → the glow-soft 2-layer stack
  (α0.6 @ ×0.3 · α0.25 @ ×0.6) — **byte-identical to
  `AppTypography.fancyTitle`** for the default color (parity pinned by two
  tests), and `color:` extends the halo to any token (e.g. `discoCyan`).
- Fill untouched (opaque glyphs, halo strictly behind — §7.4). No animation
  in this widget: breathing is U-18's §6.2 scope.

### 2. `VDiscoDivider(thickness:, accentWidth:, color:, accentColor:)`

- Const. Full-width `hairline #1A1A1A` 1px rule (two `Expanded` boxes)
  with a centered `glowPink` segment (default width `AppSpacing.xxxl` 48).
- Flat by design (P2): a divider is chrome, so no §4.3 glow stack — the pink
  segment *is* the accent (P3, with contrast 6.00:1 on black).
- The mission's "or" branch (full-width hairline with soft pink glow) was
  resolved to the **short pink segment** variant: glow stacks are brand
  moments only (§4.3 — "never for ordinary cards"; a divider is not a brand
  moment), and the segment keeps the doc's hairline-flat geometry.

### 3. `VShimmer(child:)` + `VShimmerBox(width:, height:, color:)`

- `VShimmerBox` — const primitive: fixed-size `surfaceAlt #111111` block,
  sharp corners (no `decoration` — §4.2 radius 0).
- `VShimmer` — StatefulWidget (AnimationController, 1200ms §4.5 `shimmer`,
  `repeat(reverse: true)` = back-and-forth sweep, P5 subtle). `ShaderMask`
  + `LinearGradient` with a custom `_SlidingGradientTransform`; highlight
  alpha oscillates **0.5 → 0.9** (§5.8) via `Curves.easeInOut`.
- Reduced motion: `MediaQuery.disableAnimationsOf(context)` in
  `didChangeDependencies` → controller `stop()`, build renders the child
  **without** the mask (static gray blocks, zero tickers — asserted via
  `tester.binding.transientCallbackCount`). Re-enabling animations restarts
  the sweep (tested).
- Zero external deps. The 1200ms const lives locally
  (`_shimmerSweep`) with a handoff note: `SamayDurations.shimmer` is U-18's
  source-of-truth token, not yet landed (§4.5).

### 4. Coming-soon wiring (`v_coming_soon.dart`)

The "Próximamente" headline switched from inline
`Text(style: AppTypography.fancyTitle(displaySmall, soft: true))` to
`VGlowText(text:, style: AppTypography.displaySmall, soft: true)` — **zero
visual change** (same Text widget, identical style values; all 7 existing
`v_coming_soon_test.dart` assertions green unchanged, incl. the §5.7 style
assertions on fontSize/family/italic/shadows).

## Files created / modified (lock evidence)

All 11 locks via `tools/agent_lock.sh acquire <path> --owner U-06`
(acquired 04:05Z, held for the whole edit, released after — see the final
release transcript in the commands section):

| File | Action | Lock evidence |
|---|---|---|
| `lib/shared/widgets/v_glow_text.dart` | created | acquire 78a7ecdc6c975636a1877722 → release |
| `lib/shared/widgets/v_disco_divider.dart` | created | acquire 4a387e018d6bd7a09e3c8cf9 → release |
| `lib/shared/widgets/v_shimmer.dart` | created | acquire 38535e33bbb888900dd249bc → release |
| `lib/shared/widgets/disco_widgets.dart` | created (barrel) | acquire cddcfb79e9843b023f98bce5 → release |
| `lib/shared/widgets/v_coming_soon.dart` | modified (VGlowText wiring) | acquire 6a4a71094adc35e05dc469b6 → release |
| `test/widgets/v_glow_text_test.dart` | created (8) | acquire f6e766dbc9e1224bca7b9f85 → release |
| `test/widgets/v_disco_divider_test.dart` | created (4) | acquire 0fcb0dbca22f2fdf80b25cfc → release |
| `test/widgets/v_shimmer_test.dart` | created (6) | acquire 84ecef32dd7ef8349cff858a → release |
| `test/widgets/v_coming_soon_test.dart` | locked, unmodified (verification only — stayed green) | acquire e4aa90eec287b1b4683f4d21 → release |
| `docs/to-fix/TODO.md` | modified (U-06 workstream block) | acquire b802f899fb97030c6d655fd5 → release |
| `docs/history/phase-04-ui/2026-08-11_U06-disco-widgets.md` | created (this log) | acquire 057e7cbaac96df56b6a17869 → release |

## Commands run (reproducibility)

```bash
export AGENT_NAME="U-06"
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
tools/agent_lock.sh acquire <11 files> --owner U-06        # all held (see table)
# RED: 3 test files written against absent widgets
flutter test test/widgets/v_glow_text_test.dart test/widgets/v_disco_divider_test.dart test/widgets/v_shimmer_test.dart
#   → 3 loading failures (missing imports) = RED
# GREEN: v_glow_text.dart + v_disco_divider.dart + v_shimmer.dart + disco_widgets.dart + coming-soon edit
flutter test test/widgets/v_glow_text_test.dart test/widgets/v_disco_divider_test.dart test/widgets/v_shimmer_test.dart
#   → RED-iterate: Container.width/height getters don't exist (test bug), color-test alphas
flutter test test/widgets/v_glow_text_test.dart test/widgets/v_disco_divider_test.dart test/widgets/v_shimmer_test.dart
#   → 18/18 GREEN
flutter test test/widgets/                                # 149/149
dart format <8 files>                                     # formatted
dart analyze                                               # 0 issues (fixed +3 prefer_const infos)
flutter test test/widgets/                                # 149/149 (2nd)
flutter test                                               # FULL 1758/0 (baseline 1740 → +18)
tools/agent_lock.sh release <path> --owner U-06            # all 11 released
```

## Test results

- `flutter test test/widgets/v_glow_text_test.dart` — **8/8** (renders;
  strong/soft exact stacks with α + `fontSize×f` blurs; **parity with
  `AppTypography.fancyTitle` both variants**; color param; em-scaling at
  64px; const).
- `flutter test test/widgets/v_disco_divider_test.dart` — **4/4** (hairline
  ×2 + pink accent 48×1 centered; 1px height; configurable
  thickness/colors/sizes; const).
- `flutter test test/widgets/v_shimmer_test.dart` — **6/6** (box size/color/
  sharp; animated sweep + ticker; `disableAnimations` → static, no mask,
  zero tickers; sweep restart on re-enable; const).
- `flutter test test/widgets/` — **149/149** (131 prior + 18 new).
- `flutter test` (full) — **1758 pass / 0 failures** (U-05 baseline 1740/0,
  +18 = the new tests, zero regressions; coming-soon tests green unchanged).
- `dart analyze` — **0 issues**.

## Decisions made and why

- **VGlowText carries its own stack (mirror of `fancyTitle`) instead of
  calling it:** `fancyTitle` hardcodes `glowPink` and the mission requires a
  `color:` param; a special-case branch (call fancyTitle only when color is
  default) would split behavior. The widget documents the §3.4 constants and
  the parity is **pinned by tests** (both variants compare shadow-for-shadow
  against `AppTypography.fancyTitle`) — a future drift in either side fails
  red.
- **`VDiscoDivider` = short centered pink segment**, not a pink-glow
  full-width hairline: §4.3 reserves glow stacks for brand moments; a
  divider is chrome (P2 flat + hairline). The segment is the brand accent
  (P3) at 6.00:1.
- **Reduced-motion shimmer = static blocks, mask removed entirely**: §5.8
  ("Disable shimmer animation when disableAnimations") + §7.5 (static
  fallbacks per component). No frozen mid-sweep gradient — the blocks stay
  flat gray, which is also the most testable interpretation (zero tickers).
- **`didChangeDependencies` (not `initState`) reads the MediaQuery:** the
  framework forbids inherited-widget lookups in `initState`, and this also
  makes the sweep react to runtime a11y toggles (tested: reduce → static →
  re-enable → sweeps again).
- **`_shimmerSweep` local const, not `SamayDurations`:** §4.5 says
  `samay_durations.dart` is the source of truth, but `SamayDurations.shimmer`
  doesn't exist yet (U-18's token). Touching U-18's file is out of scope —
  handoff logged.
- **Barrel ships** (`disco_widgets.dart`): one import for the disco
  signature family; consumers (U-12/U-22) can import the barrel or the
  specific file.

## MISTAKE

- **`Container` has no `width`/`height` getters (×2 files, caught by RED):**
  the tests read `container.width`/`container.height` — `Container`'s
  width/height are *constructor params*, not fields. Switched to
  `tester.getSize(finder)` (rendered size assertions, which are actually
  stronger — they pin the laid-out geometry, e.g. accent exactly 48×1).
- **Color-param test asserted the wrong alphas:** initially wrote "all three
  shadows at α0.9" for the custom-color case; the stack keeps its canonical
  alphas (0.9/0.5/0.25) and only the color changes. The failure message
  (`Color(alpha: 0.5000 …)`) made it obvious; fixed to per-shadow asserts.
- **3 `prefer_const_constructors` infos in the reduced-motion test:** the
  const-ness was only on the inner `MediaQueryData` — hoisted `const` to the
  whole `MaterialApp` tree. `dart analyze` back to 0.

## Issues found / handoffs

- **U-22:** `VShimmer(child:)` + `VShimmerBox(width:, height:)` are ready —
  compose skeleton screens as columns/rows of boxes inside one `VShimmer`
  (surfaceAlt base + sweep), reduced-motion handled.
- **U-18:** promote the local `_shimmerSweep` 1200ms const into
  `SamayDurations.shimmer` (the §4.5 token) and re-point `v_shimmer.dart`.
- **U-12/U-08:** `VGlowText` is the canonical way to render §3.2 brand
  titles (coming-soon screens, shell AppBar brand titles) — replaces
  hand-rolled `fancyTitle` calls; `VDiscoDivider` available for section
  separations.
- **U-27:** widget tests for the trio live in `test/widgets/` — extend as
  consumers land (e.g. assert shimmer usage in a U-22 skeleton screen).
- **U-26:** no contrast change — glow sits behind opaque fills (§7.4 legal
  halo); divider accent 6.00:1 AA; shimmer is non-text gray-on-black (depth
  only, §5.8 "No color").

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §3.4, §4.3, §5.8, §6.3, §7.4/§7.5
  (read in full — the contract).
- Flutter SDK source (read-only, 3.44.1): `painting/gradient.dart`
  (`GradientTransform` API), `widgets/media_query.dart`
  (`disableAnimationsOf`), `widgets/ticker_provider.dart` (ticker semantics —
  `transientCallbackCount` in widget tests).
- U-01..U-05 daily logs (palette/typography/spacing/theme/widgets — the
  token layer this work composes), U-02's `fancyTitle` handoff table.
