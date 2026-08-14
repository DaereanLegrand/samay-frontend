# 2026-08-12 — XL-03: typography + display text + glass inputs + theme (LUXE v2)

**Agent:** XL-03 | **Branch:** `fixes` | **Campaign:** LUXE v2 UI overhaul
**Role:** Typography / display text / glass inputs / theme + iOS swipe-back

## What was built

### A. `lib/core/design_tokens/app_typography.dart` (ADDITIVE)
- New `static const TextStyle sectionLabel` — Inter w600 12, letterSpacing 2.0,
  color `AppColors.mutedStrong` (7.37:1 AA). Standalone token, NOT in
  `textTheme` (TextTheme has no such role) — callers reference it directly.
- New doc block "LUXE v2 display-voice contract": display roles are Playfair
  italic bold, MUST render UPPERCASE, always through `VDisplayText` (never raw
  `Text`), callers pass natural case. The U-27 14-role field-for-field pin is
  untouched (no existing role changed).

### B. `lib/shared/widgets/v_display_text.dart` (NEW)
`VDisplayText` — the only sanctioned display voice:
- `text.toUpperCase()` — the MAYUS rule enforced here, never at call sites.
- Playfair Display italic bold at `size` (default 40), mapped to the §3.3
  display tokens (64/40/32/28) or a same-metric custom style.
- Gradient glyph fill via `ShaderMask(BlendMode.srcIn)` +
  `AppGradients.textShader(gradient, bounds)` (contract as landed by XL-01);
  `gradient == null` → white→white shader, no halo.
- Slow pulsing halo: the VBreathingGlow idle-safe engine mirrored exactly —
  3.8s easeInOut alternate (1.9s per leg), 300ms settle between cycles
  (`SamayDurations.motionCycleRest`), periodic Timer restart, `isAnimating`
  guard. Alpha floor `glowFloor` 0.35 → peak `glowPeak` 0.7 over
  `AppGradients.glowShadows(alpha: breath)`; `soft` (default true) → tight
  2-layer stack (blur 32), `soft: false` → full 3-layer aura (blur 48).
- Once-only shimmer sweep: 900ms alignment-driven white band (α0.45) gliding
  diagonally across the glyphs (`GradientTranslation`-free — begin/end
  Alignment interpolation), clipped to the text box, off-screen at t=1,
  never restarts (`_shimmerStarted` flag).
- Reduced motion → static mid-α halo (0.525), no pulse ticker, no shimmer.
- Idle-safe: `pumpAndSettle` lands in the 300ms rest; after settle
  `transientCallbackCount == 0` (pinned by test).
- Durations as widget consts (pulsePeriod 3800ms / shimmerDuration 900ms) —
  XL-04 owns the LUXE motion tokens; documented.

### C. `lib/shared/widgets/v_input.dart` (REDESIGN, API-identical)
`StatefulWidget` now (focus tracking), same 8 params — every call site
(32 across lib/) compiles untouched:
- Double-container glass: outer `AnimatedContainer` (200ms, key
  `vInputGlassShell`) = 1px gradient ring (default white α0.25; focused →
  white α0.8 → α0.25 diagonal; error → glowPink α0.8) + focus glow
  (white α0.12 blur 24); inner (key `vInputGlassFill`) = `surfaceAlt` α0.5
  fill radius 15 + neumorphic top highlight (white α0.04 gradient via
  `foregroundDecoration`). Radius 16. NO underline (`border: InputBorder.none`).
- Label always above (`floatingLabelBehavior.always`, `labelSmall` voice):
  mutedStrong → white on focus → glowPink on error. Hint muted, text white
  bodyLarge, cursor white, error glowPink.
- Semantics unchanged (label rides `InputDecoration.labelText` as before).

### D. `lib/core/theme/app_theme.dart`
- `inputDecorationTheme` — underline → glass: `filled: true`,
  `fillColor: surfaceAlt α0.5`, `OutlineInputBorder` radius 16 (white α0.25 →
  focused white α0.8 1.5px → error/focusedError glowPink α0.8),
  `floatingLabelBehavior.always`, label mutedStrong, hint muted, error
  glowPink. Block dropped `const` (withValues is not const).
- `pageTransitionsTheme` — `CupertinoPageTransitionsBuilder` on ALL SIX
  `TargetPlatform.values` (fuchsia included — without it, routes on that
  platform fall back to the Zoom builder per Flutter docs). Const builders
  keep `SamayTheme.dark == SamayTheme.dark` (const canonicalization; the
  equality/hashCode pins stay green). iOS edge-swipe back on pushed routes;
  router/shell untouched (NoTransitionPage tabs stay as-is).

## Web research (cited)

1. **Cupertino swipe-back / PageTransitionsTheme** — Flutter API docs,
   `PageTransitionsTheme` (api.flutter.dev/.../PageTransitionsTheme-class.html):
   MaterialPageRoute looks up `Theme.of(context).pageTransitionsTheme`;
   missing platform → `ZoomPageTransitionsBuilder` fallback (→ added fuchsia).
   `CupertinoPageTransitionsBuilder` lives in `package:flutter/cupertino.dart`
   (verified in the local SDK source — NOT re-exported by material.dart, both
   app_theme.dart and app_theme_test.dart import cupertino).
2. **Gradient text** — Flutter `ShaderMask` docs
   (api.flutter.dev/.../ShaderMask-class.html): `shaderCallback(Rect bounds)`
   → `Shader`; canonical gradient-text = white Text + `BlendMode.srcIn`.
   pub.dev `gradient_text` 1.0.2 evaluated: published 7 years ago, Dart 3
   incompatible, unverified publisher, ~66 downloads → REJECTED. Decision:
   built-in `ShaderMask` + `LinearGradient` — no new package.
3. **Glassmorphism / liquid glass** — NN/g "Glassmorphism: Definition and Best
   Practices" (nngroup.com/articles/glassmorphism/): translucent fill +
   gradient strokes create depth on simple backgrounds; text contrast is the
   top accessibility risk. Applied: α0.5 fill over black, 1px gradient ring,
   white α0.04 rim light, white α0.12 focus glow, mutedStrong/white text
   (7.37:1/21:1).
4. **Input trends / liquid glass** — ORCHESTRATION-LUXE.md itself (campaign
   research): underline inputs "outdated" (directive #7), liquid-glass fields
   with fill + gradient border + focus glow, radius 16–18, labels always above.
   Apple HIG materials page was JS-blocked; the campaign doc + NN/g carry the
   requirements.

## Decisions

- **No new package** for gradient text (see #2 above) — `ShaderMask` +
  `AppGradients.textShader`.
- **Swipe-back via theme only** — `PageTransitionsTheme` in `SamayTheme.dark`;
  zero router changes (go_router pushed routes get the Cupertino transition
  automatically; shell tabs use NoTransitionPage and stay as-is).
- **Pulse durations as widget consts** (3800ms/900ms per brief) — mirrored the
  VBreathingGlow engine mechanics exactly (Timer.periodic + settle + guard);
  `SamayDurations.motionCycleRest` reused for the settle (it IS the 300ms
  token).
- **6 platform entries**, not 5 — `TargetPlatform.values` has fuchsia; without
  it the exhaustive test failed (Zoom fallback per docs).
- `soft` mapped to the VBreathingGlow semantics: 2-layer tight stack vs the
  full 3-layer aura.

## MISTAKE blocks (searchable)

**MISTAKE-1:** `MediaQuery.disableAnimationsOf(context)` called in
`initState` — Flutter forbids inherited-widget access there ("dependOnInherited
... was called before initState completed"). FIX: shimmer start moved to
`didChangeDependencies` behind a `_shimmerStarted` once-only flag.

**MISTAKE-2:** `SingleTickerProviderStateMixin` with two AnimationControllers
(pulse + shimmer) → "multiple tickers were created". FIX:
`TickerProviderStateMixin`.

**MISTAKE-3:** test predicate `w.decoration is BoxDecoration &&
(w.decoration as BoxDecoration).boxShadow?.isNotEmpty ?? false` — precedence
makes the whole `&&` chain `bool?` (the `??` binds looser than `&&`). FIX:
parenthesize the null-aware chain.

**MISTAKE-4:** `_shell(tester).padding` read `BoxDecoration.padding` (paint
padding, EdgeInsets.zero) instead of the AnimatedContainer's `padding` field.
FIX: read the widget directly.

**MISTAKE-5:** asserting `transientCallbackCount == 0` right at
`pump(shellDuration)` — the animation's completion frame was still scheduled.
FIX: `pump(shellDuration + 10ms)` + one extra `pump()`.

## Validation

```
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
flutter test test/widgets/v_input_test.dart \
             test/widgets/v_display_text_test.dart \
             test/theme/                          # 74/74 PASS (incl. theme_persistence + equality pins)
dart analyze lib/core/design_tokens/app_typography.dart \
            lib/core/theme/app_theme.dart \
            lib/shared/widgets/v_input.dart \
            lib/shared/widgets/v_display_text.dart \
            test/widgets/v_input_test.dart \
            test/widgets/v_display_text_test.dart \
            test/theme/                           # No issues found!
```

Also verified: `test/features/groups/restyle_test.dart:762` pins only
`decoration.border == null` (still true — the theme-owned field), so the
underline→glass theme swap does not break it. Full suite NOT run (per brief).
No commits, no print, no other files touched.

## Lock evidence

- `agent_lock.sh run lib/core/design_tokens/app_typography.dart --owner XL-03`
  → ACQUIRED, released after edit (3 held locks released at 21:0x; `list` empty).
- Same for `lib/shared/widgets/v_input.dart` and `lib/core/theme/app_theme.dart`.
- `v_display_text.dart` + tests are new files (no concurrent owner risk).
