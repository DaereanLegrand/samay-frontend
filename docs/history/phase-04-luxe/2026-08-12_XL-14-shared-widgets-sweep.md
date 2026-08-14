# 2026-08-12 — XL-14: shared-widget sweep (de-pink + gradient-capable)

**Agent:** XL-14 | **Campaign:** LUXE v2 UI overhaul | **Branch:** `fixes`

## What was built

Every shared widget with a pink default was swept to the LUXE **violet**
default family (or the caller's own `AppGradient`), and the four signature
widgets became **gradient-capable** via a new `AppGradient? gradient`
parameter. Error semantics keep `glowPink` (documented exception).

| File | Change |
|---|---|
| `lib/shared/widgets/v_button.dart` | `AppGradient? gradient` on ALL 4 factories. `glowAccent` now always renders the 1px gradient ring (`VGradientBorder`), default family **violet** (`AppGradients.violet`); text black when `filled` / white when outline; halo = `AppGradients.glowShadows(family, alpha: 0.35)`; pressed = `Color.lerp(family.colors.last, black, 0.35)` overlay + white text (M3 InkHighlight paints the resolved overlay over the full rect — the "darker violet" fill). `emphasized(gradient:)` → gradient fill + black text; `outlined(gradient:)` → pastel gradient ring. Disabled: ring/text → `muted` (flat 2-color ring, no stops). 14px §5.1 padding hoisted into `VButton._padding` (U-03 keeper). |
| `lib/shared/widgets/v_glow_text.dart` | `AppGradient? gradient`; `color` → `Color?` (default null). Halo = `gradient.colors.last` → legacy `color` → **violet** vivid end. `AppColors` import dropped. |
| `lib/shared/widgets/v_breathing_glow.dart` | Same param change; breathing engine byte-identical. |
| `lib/shared/widgets/v_badge.dart` | `VBadge.accent` gains `AppGradient? gradient`; bare accent (no color/gradient) defaults to **violet** family: pale `AppGradients.watered(...)` fill, mid-stop border, black label. Legacy `color:` accent unchanged (private `_accentVariant` flag). |
| `lib/shared/widgets/v_chip.dart` | `VChip.accent` pink → **violet** vivid end (`AppGradients.violet.colors.last`, = `discoViolet`); `gradient:` param to adopt another family. |
| `lib/shared/widgets/v_count_badge.dart` | New `AppGradient? gradient` (default violet) for border + count text (was glowPink). |
| `lib/shared/widgets/v_disco_divider.dart` | Default accent `glowPink` → `AppColors.statusVip` (semantic violet alias; a 1px segment cannot carry a gradient — documented). |
| `error_banner.dart` / `error_view.dart` / `show_app_error.dart` | Pink accent repointed to the semantic `AppColors.error` (still glowPink — the documented error exception). |
| `state_views.dart` / `v_coming_soon.dart` | Doc comments updated to the LUXE language (loading stays neutral white; "Próximamente" breathes violet). |
| Tests | `v_button_test` (glowAccent violet ring/halo/fill/pressed/disabled + gradient overrides + spinner contrast), `v_glow_text_test` + `v_breathing_glow_test` (violet canonical, rose-parity with `fancyTitle`, gradient param), `v_badge_test` (family accent), `v_chip_test`, `v_disco_divider_test` (violet), NEW `v_count_badge_test`, NEW `no_pink_defaults_test` (source-grep guard: no `glowPink` in the 7 swept widgets). |
| `test/meta/conventions_test.dart` | U-03 allowlist: `v_button.dart:165` → `v_button.dart:34` (the `_padding` const; 14px stays the documented §5.1 keeper). |

## Decisions

- **`glowAccent` always gradient-renders.** The violet default is baked into
  `build` (`gradient ?? (glow ? violet : null)`), so no caller can fall back
  to a pink flat border. Flat paths (outlined/emphasized without `gradient`)
  render byte-identically to pre-LUXE — their tests were untouched.
- **Pressed "darker violet" via the M3 `overlayColor` property, not a
  background swap.** The fill is a gradient now, so a solid pressed color
  can't resolve through `backgroundColor`; the InkHighlight paints the
  resolved overlay across the whole rect, giving the uniform darker face +
  white text (5.87:1 — same ratio as the old glowPinkDeep pairing). Derived
  per-family (`Color.lerp(family.colors.last, black, 0.35)`) so a custom
  gradient pressed-state matches its own family — no new token needed.
- **Halo color = family *vivid end*.** The old signature was the vivid pink;
  the vivid violet carries the same signature weight, and `gradient: rose`
  still reproduces `AppTypography.fancyTitle` byte-for-byte (parity pins
  kept via rose, whose vivid end aliases glowPink).
- **`VBadge.accent` needs an `_accentVariant` flag** — the plain `VBadge`
  must stay `border #333333`, so "default violet" applies only to the accent
  variant. Legacy `color:` accents win over the family default but lose to
  an explicit `gradient:`.
- **`VDiscoDivider` stays flat:** a gradient on a 1px segment is invisible;
  the semantic `statusVip` token carries the violet accent.
- **Guard test greps the source** (`no_pink_defaults_test.dart`) — doc
  comments included, so the sweep had to rewrite the widget doc comments
  too, not just the code.

## MISTAKE blocks

- **MISTAKE (compile):** wrote `child ?? Text(...)` into a `return` with a
  trailing comma (copy-paste of the old `child:` argument form) — syntax
  error at the `??` operand. Fix: drop the comma.
- **MISTAKE (runtime):** the disabled ring was `LinearGradient(colors:
  [muted, muted], stops: family.stops)` — "colors and colorStops must have
  equal length" (3 stops vs 2 colors), thrown during paint. Fix:
  `stops: isDisabled ? null : family.stops` (2-color flat rule, no stops).
- **MISTAKE (test):** asserted the glow-hairline text shadow with
  `child: const Text('Glow')` — the shadow only applies to the internal
  `label` path (`child ?? Text(...)`). Fix: pass `label:`.
- **MISTAKE (const):** `const _violetHalo = AppGradients.violet.colors.last`
  is not a constant expression, and `Shadow` has no `copyWith` in this
  Flutter — rebuilt the violet canonical stack as explicit `Shadow(...)`
  constructions and used `AppColors.discoViolet` (the const vivid end).
- **MISTAKE (perl):** a `perl -0pi` reorder for `sort_child_properties_last`
  duplicated `gradient: gradient,` in the factory bodies (regex matched
  inside the argument list). Fix: hand-edited the four call sites.
- **MISTAKE (guard):** the U-03 EdgeInsets guard flagged the two 14px
  paddings at their new lines (allowlist entry was stale at :165). Fix:
  hoisted into `VButton._padding` const + updated the allowlist to :34.

## Sources (web research, 2026-08-12)

- **Gradient buttons:** "Mastering Gradient Design" (DesignRush, 2025-05-14)
  — accessibility/contrast first on gradient surfaces;
  https://designrush.com/home/trends/graphic-design/mastering-gradient-design
  — "UI Gradients: The Complete Guide" (Onething, 2025-08-13);
  https://onething.design/home/blogs/ui-gradients-the-complete-guide
  — "How to Create Modern Gradients in UI" (Softs, 2026-05-28): a third
  stop "adds realism and depth"; keep bold gradients in small areas
  (button/badge), not whole screens — matches AppGradient's 3-stop
  pastel→vivid runs and the button-scoped halo;
  https://softssolutionservice.com/home/blog/how-to-create-modern-gradients-in-ui-best-tips-examples
  — "25 Button UI Design… Best Practices (2026)" (Eleken): a gradient CTA
  framed by a soft pastel card without competing — the violet ring on black
  reads the same way; https://eleken.co/home/blog/product-design/button-ui-design-examples-types-and-best-practices-2026-guide
- **Pastel accents / luxury mobile:** "Best 8 Mobile App Color Scheme
  Trends for 2026" (Envato Elements, 2026-02-24): dark mode + soft-tech
  pastels + bold accents; https://elements.envato.com/learn/color-scheme-trends-in-mobile-app-design
  — GenDesigns (2025-12-12): "muted colors over fully saturated… gradients
  as accents, not everywhere"; https://gendesigns.ai/home/blog/mobile-app-color-schemes-what-works-in-2026
  — Coloruxlab (2026-01-30): the 60-30-10 rule — accents are 10% of the
  screen, which is why the CTA/badge carry the family and nothing else;
  https://coloruxlab.com/guides/mobile-app-color-design
- **Minimal badges:** "Badge UI Design: Best practices…" (Mobbin): don't
  badge every element — keeps the accent scarce; https://mobbin.com/glossary/badge
  — Setproduct (2026-06-08): a badge "rides on a parent and is never
  clickable" (the VBadge/VCountBadge usage); https://setproduct.com/blog/badge-ui-design
  — "Is it good to mix filled and outline badges?" (UX Stack Exchange):
  one styling per theme for consistency; https://ux.stackexchange.com/questions/147109

## Commands run

```bash
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
dart format lib/shared/widgets/... test/widgets/...
flutter test test/widgets/            # 266/266 green
flutter test test/widgets/ test/meta/conventions_test.dart  # 293/293 green
dart analyze lib/shared/widgets/ test/widgets/  # 0 issues (1 pre-existing
    info in test/widgets/v_glow_pulse_test.dart:117 — XL-04's file, untouched)
dart analyze lib/                      # 0 issues (all ~200 call sites compile)
```

## Out-of-scope issues found (report — NOT fixed)

1. `test/widgets/v_glow_pulse_test.dart:117` — pre-existing
   `sort_child_properties_last` info (XL-04's file; left untouched).
2. `test/features/auth/restyle_test.dart` — 2 failures:
   "WelcomeScreen primary CTA is the filled glowAccent (**pink** fill…)" and
   the ForgotPasswordScreen twin (XL-05 owns the auth screens; they still
   assert the pre-LUXE pink fill). The screens now render the violet family;
   XL-05 should repoint these to `AppGradients.violet`/`familyOf` when
   restyling auth.
3. Same pattern pending in feature restyle tests owned by XL-07 (feed:
   `VBadge.accent` glowPink + `VDiscoDivider` glowPink — feed_screen.dart:314
   still passes `color: AppColors.glowPink`; the widget now supports
   `gradient:` for the family accent) and XL-08 (profile: "glowAccent
   outlined pink border" assertion). No widget-side break — the old flat
   accent API still works, only the default hue changed.
4. `v_coming_soon_test.dart` and `feature_flags_test.dart` "faint glowPink
   icon" tests keep passing (caller-supplied `iconColor`, not a default).
