# 2026-08-12 — XL-02: liquid-glass primitives (VGlass / VGlassCard / VGradientBorder)

**Agent:** XL-02 | **Campaign:** LUXE v2 UI overhaul | **Branch:** `fixes`

## What was built

New glass layer under `lib/shared/widgets/glass/`:

- `v_gradient_border.dart` — `VGradientBorder`, the 1px gradient-border
  primitive. Classic double-container trick: outer `Container` paints the
  caller's `LinearGradient` across a ring of `width` (as its `padding`),
  inner `Container` fills with `color` (default `AppColors.surface`) and
  clips its child to the radius minus the ring width. Const-constructible.
- `v_glass.dart` — `VGlass` + `VGlassCard`. Stack (back → front):
  `BackdropFilter` (sigma `blur`, default 12) over a white gradient fill
  (α0.05 → α0.01, topLeft → bottomRight), child (padded, clipped to radius),
  1px top highlight sheen (white α0.10, fading at the ends), `VGradientBorder`
  ring (white α0.28 → pastel α0.18 → transparent; white-only when the
  `AppGradient?` is null), and — when `glowAlpha > 0` and a gradient is
  present — an outer `DecoratedBox` carrying `AppGradients.glowShadows`.
  Whole thing wrapped in `RepaintBoundary`. `VGlassCard` = radius zero +
  `glowAlpha` 0.18 + card padding 16 (the liquid-glass `VCard`).
- `glass.dart` — barrel exporting both; `disco_widgets.dart` re-exports it.
- Tests: `test/widgets/v_gradient_border_test.dart` (7) +
  `test/widgets/v_glass_test.dart` (11) — 18 tests, all green.

## Decisions

- **Custom primitives on dart:ui — no pub dependency.** Researched `glass_kit`
  4.0.2 (pub.dev): a monolithic `GlassContainer` with opinionated defaults
  (own blur/borderGradient/elevation stack, legacy `withOpacity` API, fixed
  frosted-opacity model), impossible to make token-driven without fighting it.
  The whole feature is ~100 lines of `BackdropFilter` +
  `ImageFilter.blur` + `LinearGradient` + `BoxShadow` (Flutter docs confirm
  the pattern). Token-driven (AppColors/AppGradients) per the LUXE rules and
  the repo's "no raw hex" guard.
- **`radius.subtract` instead of a hypothetical `deflate`:** this Flutter
  (3.44.1) has no `BorderRadius.deflate` — the inner box corner is
  `radius.subtract(BorderRadius.all(Radius.circular(width)))`, clamped to
  zero at render so sharp corners stay sharp (MISTAKE below).
- **Glow discipline:** glow shadows only when `glowAlpha > 0` AND a gradient
  family exists — white-only glass is a pure hairline surface (no pastel
  glow), matching the design language "soft pastel glow shadow".
- **BackdropFilter must be clipped:** an unclipped `BackdropFilter` blurs
  everything on screen — it's wrapped in `ClipRRect(radius)` (Flutter docs).
- **Highlight above content, below the ring:** the 1px sheen is decorative;
  painting it over the content edge is the intended glass-rim look.
- **Test finders disambiguate the ring by `padding: EdgeInsets.all(1)`** —
  the top highlight is also a gradient-decorated `Container`; tree-order
  alone picked the wrong one (MISTAKE below).

## MISTAKE blocks

- **MISTAKE (compile):** used `BorderRadius.deflate(width)` which does not
  exist in Flutter 3.44.1 — the API is `subtract`. Fix: `radius.subtract(
  BorderRadius.all(Radius.circular(width)))`; return type must be
  `BorderRadiusGeometry` (the typed `BorderRadius` return is only a runtime
  branch, statically it's the geometry type).
- **MISTAKE (test):** the "border ring" finder matched the top-highlight
  `Container` first (both carry a gradient `BoxDecoration`), asserting
  α0.0/α0.1 stops instead of the ring's α0.28. Fix: filter on
  `padding == EdgeInsets.all(1)` (only the ring container is padded by the
  ring width).
- **MISTAKE (analyze):** `final rose = AppGradients.rose;` cannot appear
  inside a `const MaterialApp(...)` — "invalid constant value" (local
  non-const variable). Fix: `const rose = ...`. Local consts are fine in
  const expressions (XL-01's tests do the same).

## Sources

- glass_kit 4.0.2 (pub.dev) — evaluated, rejected:
  https://pub.dev/packages/glass_kit
- BackdropFilter class docs (Flutter API) — blur scope + clip requirement:
  https://api.flutter.dev/flutter/widgets/BackdropFilter-class.html
- Design language: docs/history/phase-04-luxe/ORCHESTRATION-LUXE.md
  §"Component vocabulary" + §"Foundation API contract" (AppGradient/
  AppGradients.glowShadows — XL-01's landed implementation matches the
  contract verbatim).

## Commands run

```bash
# locks
tools/agent_lock.sh acquire <path> --owner XL-02 --timeout 60   # 7 files
# tests (all green: +18)
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
flutter test test/widgets/v_gradient_border_test.dart test/widgets/v_glass_test.dart
# analyze (0 issues on touched files)
dart analyze lib/shared/widgets/glass/ test/widgets/v_gradient_border_test.dart test/widgets/v_glass_test.dart
dart analyze lib/shared/widgets/disco_widgets.dart
# conventions guard (no palette violations, 27/27)
flutter test test/meta/conventions_test.dart
# locks released
tools/agent_lock.sh release <path> --owner XL-02
```

## Validation gate

- [x] `flutter test` on both new test files — 18/18 green
- [x] `dart analyze` on glass/ + tests + disco_widgets.dart — 0 issues
- [x] `test/meta/conventions_test.dart` — 27/27 (no raw hues/hexes in shared
      widgets; only `AppColors`/`AppGradients` tokens + `withValues(alpha:)`
      and the doc-sanctioned `Colors.transparent`)
- [x] No commit (orchestrator-only)
- [x] No print, no dead code, no commented code
