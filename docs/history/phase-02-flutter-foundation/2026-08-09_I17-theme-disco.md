# I-17 — Disco theme phase 1: `SamayTheme.dark` rework (2026-08-09)

**Agent:** I-17-theme-disco | **Phase:** 02-flutter-foundation | **Status:** DONE

## What was built

Phase 1 of the disco palette on `SamayTheme.dark` (getter name unchanged —
`lib/app.dart:15` keeps working). Contract: `docs/design/DISCO-DESIGN-SYSTEM.md`
(D-11, read in full) + `docs/to-fix/categories/07-UI-DESIGN.md` findings UI-05/06/08.

1. **`lib/core/theme/app_theme.dart`** — reworked theme:
   - **Palette:** new `DiscoPalette` (abstract final const class) mirroring
     design doc §2 tokens verbatim: neutrals `black/surface/surfaceAlt/hairline/
     border/muted/mutedStrong/white`, signature `glowPink #FF2E88` +
     `glowPinkBright #FF5CA8` + `glowPinkDeep #C2185B`, and the §2.3 soft
     accents `discoViolet/discoCyan/discoGold/discoSilver/discoBronze`.
     **I-16 did not land `lib/core/design_tokens/app_colors.dart` yet** (checked
     before editing) → colors defined locally here, documented for I-16/U-01
     adoption.
   - **ThemeExtension (temporary):** `AppThemeExtension` (glow pinks + soft
     accents, `copyWith` + `lerp`) registered in `ThemeData.extensions` —
     closes the L-17 "no ThemeExtension" gap at phase-1 level. U-04 finalizes
     it as `SamayThemeExtension` (design doc §8 U-04 row); named
     `AppThemeExtension` deliberately so U-04's planned name stays free.
   - **Color roles (minimalist):** `brightness dark`, scaffold black,
     `colorScheme.surface` black, `primary`/`secondary` WHITE, `onPrimary`
     black (white fills carry black text). No accents in the core scheme —
     accents enter via the extension only (P2 white-only fallback).
   - **Typography (§3.3 exact):** display family now Playfair Display italic:
     `displayLarge` 64/w700/-1.9/1.0, `displayMedium` 40/w700/-1.2/1.0,
     `displaySmall` 32/w700/-1.0/1.05, `headlineLarge` 28/w600/-0.8/1.1.
     Body/UI stay Inter: `headlineMedium` 24/w700, `headlineSmall` 20/w600,
     `titleLarge` 18/w600, `titleMedium` 16/w500, `bodyLarge` 16/w300,
     `bodyMedium` 14/w300, `bodySmall` 12/w400, `labelLarge` 14/w700 +1.2,
     `labelMedium` 12/w600 +0.8, `labelSmall` 10/w500 +1.2. Global
     `fontFamily: 'Inter'` default kept (I-18 wires the actual font files;
     family names referenced as planned).
   - **Glow helper:** `SamayTheme.glowTitleStyle(TextStyle, {soft})` — the
     design-doc §3.4 shadow stacks with blur radii computed from the style's
     fontSize (glow-strong 3 layers `α0.9@0.35em / α0.5@0.7em / α0.25@1em`;
     glow-soft 2 layers `α0.6@0.3em / α0.25@0.6em`). Baked into the four
     Playfair styles (strong ≥32px, soft 28px). Glyph fill untouched
     (full-opacity) — halo strictly behind text (§7.4 legibility contract).
   - **AppBar:** black bg, white fg, elevation 0, plus `scrolledUnderElevation:
     0` (M3 tint would gray the bar when the page scrolls under it).
   - **BottomNav:** black bg, selected WHITE, unselected `#666666`
     (design doc §2.4 explicitly pins `muted #666666` for unselected nav
     icons — 3.66:1 passes the non-text 3:1 rule), icons-only, `fixed`.

2. **`test/theme/app_theme_test.dart`** — rewritten TDD-first (25 tests):
   - Kept/adapted old assertions: dark brightness, black scaffold, white
     primary, black surface, Inter body weights, bold button label, AppBar
     elevation, BottomNav fixed/icons-only, black/white/gray-only scheme.
   - **Changed:** `displayLarge.fontFamily` Inter → 'Playfair Display'.
   - **New:** full Playfair display family (family/italic/weight/size per §3.3),
     glow-strong stack on displayLarge (3 layers, exact α + `64×0.35/0.7/1.0`
     blur radii), glow-soft on headlineLarge (2 layers), body styles carry NO
     glow, `glowTitleStyle` computes stacks from any fontSize (strong + soft
     variants, fill stays opaque), AppBar black + scrolledUnderElevation 0,
     bottom-nav selected white / unselected `#666666` + no labels, and
     `AppThemeExtension` registration + `copyWith`/`lerp` behavior.

3. **`docs/history/phase-02-flutter-foundation/2026-08-09_I17-theme-disco.md`**
   — this daily log.

4. **`docs/to-fix/TODO.md`** — L-16/L-17 statuses updated (see below).

## Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire <path> --owner I-17-theme-disco`
(held 13:16Z, released after edits):

| File | Action | Lock evidence |
|---|---|---|
| `lib/core/theme/app_theme.dart` | modified (rewritten) | acquire 5012349ec44717814afddeb2 → release |
| `test/theme/app_theme_test.dart` | modified (rewritten, 25 tests) | acquire 0df1a90c7bf3f192538baf73 → release |
| `docs/to-fix/TODO.md` | modified (L-16/L-17 statuses) | acquire b802f899fb97030c6d655fd5 → release |
| `docs/history/phase-02-flutter-foundation/2026-08-09_I17-theme-disco.md` | created (this log) | acquire af79c58874b68d381123e1a5 → release |

`test/widgets/v_coming_soon_test.dart` — **not touched** (mission point 5):
`v_coming_soon.dart` uses its own inline `TextStyle`s, not `textTheme`, so the
theme change does not affect it (visual strings unchanged).

## Commands run (reproducibility)

```bash
export AGENT_NAME="I-17-theme-disco"
tools/agent_lock.sh list                          # no locks held before
tools/agent_lock.sh acquire <file> --owner "$AGENT_NAME"   # per file
flutter test test/theme/                          # RED: compile errors (API absent)
flutter test test/theme/                          # GREEN: 25/25
flutter test test/theme/ test/widgets/            # 76/76
flutter test test/router/                         # 116/116 (app renders with the theme)
dart analyze                                      # 0 errors, 14 info (all pre-existing,
                                                  #   none in touched files)
tools/agent_lock.sh release <file> --owner "$AGENT_NAME"
```

## Test results

- `flutter test test/theme/` — **25/25 pass** (RED run first: 8 compile errors
  from the not-yet-existing `DiscoPalette`/`glowTitleStyle`/`AppThemeExtension`,
  then GREEN after implementation).
- `flutter test test/theme/ test/widgets/` — **76/76 pass** (all shared-widget
  tests unaffected).
- `flutter test test/router/` — **116/116 pass** (router pumps `SamayApp` with
  the new theme; coming-soon routes, shell, auth redirects all green).
- `dart analyze` — **0 errors / 0 warnings / 14 info**, every info a
  pre-existing `use_build_context_synchronously` in files not touched here.

## Decisions made and why

- **Unselected bottom-nav color = `#666666` (not `#999999`).** The mission
  hint said "unselected #666→#999 per design doc", but the design doc is
  explicit in two places (§2.1 `muted` row; §2.4) that `#666666` is the
  unselected-nav-icon color (3.66:1 ≥ the 3:1 non-text rule; `#999999` is for
  *secondary text*). The doc wins — noted here for U-08/U-27.
- **Glow baked into the TextTheme** (not just a helper): design doc §3.4 says
  display titles carry the glow; baking it in means `Text(…,
  style: textTheme.displayLarge)` gets the signature with zero call-site
  changes. The standalone `glowTitleStyle` helper remains for brand moments
  that compose ad-hoc styles (U-06/U-12).
- **Blur radii computed from fontSize** (`em`-relative like the CSS source),
  not hardcoded px — the doc's canonical stacks are defined as `fontSize×f`.
- **`AppThemeExtension` kept separate from `colorScheme`:** P2 (white-only
  fallback) + §2.5 (accent budget ~10%) mean accents must stay opt-in; the
  core scheme stays black/white/gray so "when in doubt: white" is the default.
- **`scrolledUnderElevation: 0`** — M3 AppBar default tints the bar surface
  when content scrolls beneath it; P1 ("black always") forbids that.

## MISTAKE

- None. The one design judgment call (bottom-nav unselected `#666666` vs the
  mission's "#666→#999" range) was resolved by deferring to the authoritative
  design doc (§2.4) and is documented above instead of guessed.

## Issues found / coordination notes

- **I-16/U-01:** `lib/core/design_tokens/app_colors.dart` still does not
  exist. I-17 defines the §2 palette as `DiscoPalette` + `AppThemeExtension`
  in `app_theme.dart` — U-01 should move the consts (values are identical to
  the doc) and U-04 should fold `AppThemeExtension` into the planned
  `SamayThemeExtension`. Until then, screens may read
  `Theme.of(context).extension<AppThemeExtension>()`.
- **I-18:** theme references `'Playfair Display'` and `'Inter'` family names;
  fonts must be registered under exactly those names in `pubspec.yaml`.
- **U-12/U-27:** `v_coming_soon.dart` still hardcodes its "Próximamente"
  style inline (24px bold) — U-12 restyle should switch it to
  `displaySmall` + `glowTitleStyle` (design doc §5.7: Playfair 32 glow-soft).
- **Pre-existing (not mine, reported per AGENT-RULES):** 14 analyzer infos
  (`use_build_context_synchronously`) across feature screens; `structure_test`
  brittle failures are I-48's; no changes to those files.

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` (the spec, read in full) — §1 pillars,
  §2 palette + contrast table, §3 type scale + glow stacks, §7.4 legibility.
- Flutter `ThemeExtension` API (subclass + `copyWith` + `lerp`, registered via
  `ThemeData.extensions`): https://api.flutter.dev/flutter/material/ThemeExtension-class.html
- MDN `text-shadow` (em-relative blur semantics):
  https://developer.mozilla.org/en-US/docs/Web/CSS/text-shadow
- WCAG 2.2 SC 1.4.3 (halo-as-background note) via the design doc §7.4:
  https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
