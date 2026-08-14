# 2026-08-09 — D-11: Disco Design System Spec (docs/design/DISCO-DESIGN-SYSTEM.md)

**Agent:** D-11 (Phase 4.1 — Documentation) · **Role:** Design-system spec author
**Owner map:** `docs/design/DISCO-DESIGN-SYSTEM.md` (per `docs/process/FILE-OWNERSHIP.md`)
**Campaign:** Samay 180-agent orchestration, started 2026-08-09 · Branch: `fixes`

## What was built

1. **`docs/design/DISCO-DESIGN-SYSTEM.md`** (new, ~300 lines) — the authoritative
   design contract for the disco identity that U-01..U-30 implement:
   - **§1 Brand pillars:** black always, minimalist, disco glow accents, premium
     editorial, white-only mode fallback.
   - **§2 Color palette:** neutrals, signature `glowPink #FF2E88`, soft disco accents
     (violet/cyan/gold/silver/bronze) with **self-computed WCAG contrast ratios** and
     contrast-first usage rules (black text on pink fills, never white-on-pink, etc.).
   - **§3 Typography:** Playfair Display (italic 700) for display titles ONLY with an
     exhaustive usage list; Inter everywhere else; full Flutter TextTheme table; the
     glow text-shadow spec (3 canonical stacks: strong/soft/hairline).
   - **§4 Tokens:** spacing (8-step + semantic), radius (**sharp** — MVP "no rounded
     pastel"), flat elevation + glow shadow stacks, icon sizes, durations referencing
     `lib/core/theme/samay_durations.dart`.
   - **§5 Components:** VButton (outlined/emphasized + new glowAccent), VInput
     (underline, muted-text fix), VCard (hairline), VChip, VBadge, VShardIcon (gold
     diamond), RankBadge (podium accents), coming-soon, loading, empty states.
   - **§6 Motion:** subtle/fast principles, disco-glow breathing animation spec
     (3000ms easeInOut alternate, α0.75→1.0 floor, `disableAnimations` gate),
     micro-interaction table.
   - **§7 Accessibility:** contrast minimums (4.5/3.0), hairline-boundary 1.4.11
     exception rule, text scaling, glow-legibility contract (halo ok / blur-only not),
     reduced motion, color-blindness.
   - **§8 Mapping table U-01..U-30** (per FILE-OWNERSHIP) + extension/refactorability
     guide for future features.
   - **§9-10 Sources + change log.**

2. **Daily log** — this file.

## Decisions

- **Signature pink = `#FF2E88`** (not `#E91E63` Material pink, 4.83:1; not lighter
  `#FF4D9E`). Rationale: computed relative luminance L=0.250 → **6.00:1 on black**
  (WCAG AA normal text, near-AAA), hottest pink that legally glows; canonical hot
  pink range per user's `--pink` CSS.
- **Muted `#666666` (3.66:1) demoted** to placeholder/disabled/large-text-only; new
  `mutedStrong #999999` (7.37:1) for real secondary text — fixes the existing
  `v_input.dart` label color (fails 1.4.3 at normal size) without a visual revolution.
- **Radius = 0 everywhere** — MVP spec is explicit: "No rounded pastel". Avatars/dots
  keep circular shape (exceptions listed in §4.2).
- **Shard icon becomes gold** (`discoGold #FFC94D`, 13.71:1) — currency semantics,
  matches leaderboard economy; white in white-only mode.
- **Glow is a *background* halo only** — glyph fill stays 100% opaque; breathing
  amplitude floor α0.75 keeps effective contrast ≥ 4.75:1 (computed: 0.75×0.250
  luminance → 4.75:1). Blur-only text banned (§7.4).
- **Hairline `#1A1A1A` borders (1.21:1) documented as decoration-only** — the one
  deliberate 1.4.11 exception, conditioned on every tappable surface also carrying a
  ≥4.5:1 text/icon signal (§7.2).
- Accent budget ≤10% of screen; **white when in doubt** — keeps minimalism pillar.

## Verification

- **Contrast math (computed by hand-equation, Python-verified; WCAG formula**
  `L = 0.2126R+0.7152G+0.0722B` on linearized sRGB, ratio `(L1+0.05)/(L2+0.05)`):
  `glowPink` 6.00 · `glowPinkBright` 7.35 · `glowPinkDeep` 3.58 (AA-large only) ·
  `violet #8B5CF6` 4.96 · `cyan #00E5FF` 13.65 · `gold #FFC94D` 13.71 ·
  `silver #C0C0C0` 11.54 · `bronze #CD7F32` 6.68 · `muted #666666` 3.66 ·
  `mutedStrong #999999` 7.37 · white 21.0 — all vs `#000000`. White-on-pink = 3.50
  (banned); black-on-pink = 6.00 (required).
- **Repo files referenced in spec — all verified to exist:** `lib/core/theme/app_theme.dart`,
  `lib/core/theme/samay_durations.dart`, all 8 `lib/shared/widgets/*` components,
  `docs/specs/product/samay_mvp_spec.md` (§1 design language), `docs/specs/steps/.../DSNG-design-system-theme.md`,
  `docs/to-fix/categories/07-UI-DESIGN.md`, `docs/to-fix/LESSONS_FROM_JUEGA.md`,
  `docs/process/FILE-OWNERSHIP.md`, `docs/specs/steps/cross-references.md` (row D-11).
- **Juega studied (read-only) — structural borrow, no color copy:**
  `lib/core/theme/app_colors.dart`, `app_theme.dart`, `app_theme_extension.dart`,
  `app_typography.dart`, `lib/core/design_tokens/app_{spacing,radius,elevation,icons,durations}.dart`,
  `lib/shared/widgets/juega_loading_overlay.dart`, `pubspec.yaml` (google_fonts/flutter_animate).
  - **Took (structure):** token-file layout (spacing/radius/elevation/icons/durations
    split), `ThemeExtension` pattern (copyWith+lerp, `extensions:` registration),
    semantic alias naming, theme-builder function style, google_fonts dependency
    approach.
  - **Unique to Samay:** the entire disco palette (Juega = blood-red/gold fitness,
    Samay = pink glow + violet/cyan/gold accents), Playfair Display serif display
    voice (Juega = Space Grotesk), sharp-zero radius (Juega rounds), glow/breathe
    motion system, white-only mode, glow legibility floor.

## Files (lock acquire/release evidence)

| File | Lock | Notes |
|---|---|---|
| `docs/design/DISCO-DESIGN-SYSTEM.md` | ✅ acquired + released by D-11 | new file (dir `docs/design/` created) |
| `docs/history/phase-00-foundation/2026-08-09_D11-disco-design-system.md` | ✅ acquired + released by D-11 | this log |

No commits. No Juega modifications. No secrets.

## Sources consulted

- W3C WCAG 2.2 SC 1.4.3 (contrast math, 4.5/3:1, halo note): https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- Flutter ThemeExtension: https://api.flutter.dev/flutter/material/ThemeExtension-class.html
- Flutter MediaQueryData.disableAnimations: https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html
- MDN text-shadow: https://developer.mozilla.org/en-US/docs/Web/CSS/text-shadow
- Google Fonts Playfair Display: https://fonts.google.com/specimen/Playfair+Display
- Material 3 color system: https://m3.material.io/styles/color/system/overview

## Issues found (reported, not fixed)

- `lib/shared/widgets/v_input.dart` labelStyle `#666666` fails WCAG 1.4.3 at normal
  text size (3.66:1) — spec §5.2 mandates `mutedStrong #999999` (U-05 fix).
- `lib/core/theme/app_theme.dart` declares `fontFamily: 'Inter'` with no bundled font
  (finding UI-08) — spec §3.1 defers to I-18/U-02 bundling.
- Welcome screen still brands `'VIVE'` (`welcome_screen.dart`) while the app is
  Samay — spec §3.2 defines the wordmark slot; naming decision belongs to product.
