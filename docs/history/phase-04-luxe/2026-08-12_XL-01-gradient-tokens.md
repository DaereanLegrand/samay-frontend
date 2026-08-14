# XL-01 — LUXE design tokens: pastel gradient system (2026-08-12)

**Agent:** XL-01 (LUXE v2 — DESIGN TOKENS) | **Branch:** `fixes`
**Status:** DONE | **Contract:** ORCHESTRATION-LUXE.md §"Gradient family →
screen map" + §"Foundation API contract (XL-01 implements EXACTLY this)"

## 1. Web research (done first, cited)

**Package survey (pub.dev):**

| Package | Verdict | Evidence |
|---|---|---|
| `gradient_text` | ❌ REJECT | 7 years old, **Dart 3 incompatible**, unverified uploader, 31 likes / 66 weekly downloads — the classic ShaderMask hack from 2019 (its own README credits the Reddit `ShaderMask` idea) — https://pub.dev/packages/gradient_text |
| `gradient_borders` | ❌ REJECT (out of scope) | Verified publisher, 205k downloads — but it only ships border/input-decor painters (a `GradientBoxBorder` + `GradientOutlineInputBorder`), i.e. exactly what XL-02 builds as `VGradientBorder` from our tokens; no family/token layer — https://pub.dev/packages/gradient_borders |
| `animated_gradient_text` | ❌ REJECT | 18 months old, 8 likes / 107 downloads, max-5-colors cap, animation baked into a widget (we need token-level gradients; pulse motion is XL-04's `VGlowPulse`) — https://pub.dev/packages/animated_gradient_text |
| `shader_mask` | n/a | No such package (404) — the pattern is Flutter's own `ShaderMask` widget + `Gradient.createShader` |

**Trend articles:**

- Kittl — *Gradient design trend: Color shades play* (2026-03-15): aurora
  gradients are the 2025-26 evolution; forms = linear, radial, angular,
  mesh; blurred/dreamy "ethereal" aesthetics over flat transitions —
  https://www.kittl.com/blogs/gradient-design-trend-stl/
- DEV — *CSS Gradient Trends in 2026* (2026-05-27): pastel gradients,
  aurora gradients, dark-mode gradients, glassmorphism and **blurred glow
  effects** are the core set; guidance: gradients as accents, combine with
  blur, test contrast on dark backgrounds —
  https://dev.to/will_indie/css-gradient-trends-in-2026-and-how-developers-actually-use-them-3hec
- PXLTool — *10 Design Trends for 2026 (Glass, Blob, Mesh)* (2026-05-07):
  "gradient blur backgrounds" on dark (Vercel/OpenAI pattern), blobs,
  mesh, glassmorphism, **gradient text headlines** (CSS `background-clip:
  text` — Flutter's exact equivalent is `ShaderMask`) —
  https://pxltool.com/en/blog/design-trends-2026

**DECISION — no new package:** gradients are built on Flutter's own
`LinearGradient` / `RadialGradient` / `ShaderMask` (dart:ui). Justification:
(a) every candidate package is either unmaintained, tiny, or out of scope
(table above) — no clear winner; (b) the trend sources confirm the design is
achievable with plain linear/radial primitives + blur (CSS `background-clip:
text` ≈ Flutter `ShaderMask`); (c) zero runtime/dependency risk, and the
token layer stays pure Dart consts — XL-02..XL-04 compose it into
widgets. 3-stop pastel→vivid runs on black with blurred glow are exactly
the published 2026 pattern.

## 2. What was built

### NEW `lib/core/design_tokens/app_gradients.dart`
- `class AppGradient` — `name` / `colors` / `stops` (const), `linear({begin,
  end})` defaulting to `topLeft → bottomRight`, `radial({center})`
  defaulting to `center` (aurora blob anchors).
- `abstract final class AppGradients`:
  - `rose` `violet` `cyan` `gold` `mint` `peach` — the 6 const families,
    each exactly `[0.0, 0.5, 1.0]` stops, doc-exact hexes. **Decision:** the
    12 colors that now have AppColors tokens (6 pastels + 4 pre-existing
    vivid ends + new `mint`/`peach`) **reference the tokens** (single source
    of truth); only the 6 mid stops are in-file hexes (they have no
    standalone token by contract — family-exclusive, documented in
    app_colors.dart section header).
  - `all` — name → family map (exactly 6 entries, canonical consts).
  - `familyOf(String screenKey)` — switch expression mirroring the doc table
    1:1 (rose for welcome/signup/banned/party_finder, … peach for
    forgot_password/chat/events), `_ => rose` fallback.
  - `glowShadows(g, {alpha = 0.35, blur = 48})` — 3 zero-offset BoxShadows:
    mid @α·1/blur, vivid @α·0.6/blur·2, vivid @α·0.3/blur·3.5.
  - `textShader(g, Rect bounds)` → `g.linear().createShader(bounds)` for
    ShaderMask text (contract simplification — see MISTAKE).
  - `watered(base, {mix = 0.6})` → `Color.lerp(c, white, mix)` per color.

### EXTENDED `lib/core/design_tokens/app_colors.dart`
- 8 new canonical tokens + `all` map entries, each with WCAG-vs-black
  doc comment (computed with the file's own `contrastRatio` helper, Python
  cross-checked): `pastelRose` 16.04, `pastelViolet` 15.64, `pastelCyan`
  18.61, `pastelGold` 19.04, `pastelMint` 19.46, `pastelPeach` 17.57 (all
  AAA), `mint` 13.02 (AAA), `peach` 9.08 (AA). Pastel section header
  documents the "gradient layers, not body text" usage rule.
- `SamayThemeExtension` intentionally NOT touched: its exhaustive 16-field
  lerp/copyWith tests are the contract for the extension; the pastel tokens
  are gradient-layer colors, not theme surfaces (XL-03 decides if the
  extension needs them).

### Tests (TDD: RED → GREEN)
- NEW `test/design_tokens/app_gradients_test.dart` — 17 tests: 6 families ×
  exact stops; `all` registry (6 names, canonical identity, const
  constructibility); vivid-end token aliasing; full `familyOf` table
  (23 keys) + rose fallback (unknown/empty/case-sensitive); linear/radial
  defaults + overrides; glowShadows (3 layers, blur 48/96/168, alpha
  0.35/0.21/0.105, zero offset, param scaling, all 6 families); textShader
  (non-null `Shader` for a rect); watered (exact lerp, mix 0/1, closer to
  white).
- UPDATED `test/design_tokens/app_colors_test.dart` — palette-completeness
  map now 24 entries (+8); new LUXE group: exact hexes, pastels ≥4.5:1,
  vivid mint/peach ≥3:1, documented ratios closeTo (tolerance 0.02).

## 3. Validation

```
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
flutter test test/design_tokens/   → 93/93 pass (incl. 17 new gradients tests)
dart analyze lib/core/design_tokens/ test/design_tokens/ → 0 issues
```

## MISTAKE

- **`textShader` signature (contract deviation, decided deliberately):** the
  ORCHESTRATION contract shows `textShader(g, TextSpan span)`, but computing
  a paint rect from a span inside a token class forces layout knowledge
  (TextPainter, strut, text direction) into a token — the orchestrator's
  task brief explicitly simplified it to `textShader(g, Rect bounds)` (caller
  passes the text's rect; `VGradientText` XL-03 owns layout). Implemented the
  brief version; flagged here so XL-03 wires the rect from `TextPainter`.
- **Test bug (my first `watered` assertion):** asserted per-channel
  "closer to white" via `|1−r|` on `#FF2E88` — but its red channel is
  already `1.0`, so `lerp(1.0, white, t)` doesn't move it and
  `0.0 < 0.0` failed. Fixed with a summed distance-to-white over all 3
  channels, which strictly decreases for any non-white color (each channel
  either stays at 1.0 or moves toward it). RED caught it on first run —
  exactly what the TDD loop is for.
- **unnecessary_import lint (fixed):** `dart:ui` import in both new files is
  redundant (material exports `Shader`/`Rect`) — analyzer flagged it in
  validation; removed (this is why we run `dart analyze` on touched files).

## Commands run (reproducibility)

```
tools/agent_lock.sh acquire|run <path> --owner XL-01 … (every file below)
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
flutter test test/design_tokens/            # RED: 2 loading failures
flutter test test/design_tokens/            # GREEN: 93/93
dart analyze lib/core/design_tokens/ test/design_tokens/   # 0 issues
python3 (WCAG ratio cross-check of all 18 gradient stop hexes)
tools/agent_lock.sh list                    # all released
```

Files locked/edited by XL-01: `lib/core/design_tokens/app_gradients.dart`
(new), `lib/core/design_tokens/app_colors.dart`, `test/design_tokens/
app_gradients_test.dart` (new), `test/design_tokens/app_colors_test.dart`,
this log. All locks released. No commit (orchestrator-only).

## Handoffs to downstream agents

- **XL-02 (glass primitives):** `AppGradient.linear()` colors/stops are the
  gradient-border source; `glowShadows(g)` is the card/input halo;
  `radial()` feeds glass fills (α 0.03–0.08 white-mix — use
  `AppGradients.watered(colors, mix: …)` for the fills).
- **XL-03 (typography/display):** `VGradientText` renders via
  `ShaderMask(shader: AppGradients.textShader(family, textPainterBounds))`;
  `familyOf` is the per-screen resolver.
- **XL-04 (motion):** `glowShadows` are the alpha-animated layers —
  `VGlowPulse` animates overall alpha (0.35↔0.7 band, reduce-motion static);
  `radial()` blobs are `VAurora`'s paint sources.
- **XL-05..XL-13 (screens):** call `AppGradients.familyOf('<screen_key>')`
  with the doc's snake_case key — the fallback is rose, so an unmapped
  screen silently gets the brand family (by design).

*XL-01 · LUXE v2 · 2026-08-12*
