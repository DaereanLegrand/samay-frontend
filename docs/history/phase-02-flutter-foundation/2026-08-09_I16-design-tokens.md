# I-16 — Design tokens + ThemeExtension + widget token migration (2026-08-09) — RESUME RUN

**Agent:** I-16-design-tokens | **Phase:** 02-flutter-foundation | **Status:** DONE

> **Resume note:** this is the final version of the log. The original run was
> interrupted; a fresh I-16 run re-read the repo in full, re-verified every
> deliverable against `docs/design/DISCO-DESIGN-SYSTEM.md`, completed the
> missing context-extension getters, re-ran the full verification matrix, and
> updated M-25 in TODO.md. History of the original run is preserved below.

## What was built

Design-token foundation for the disco design system (contract:
`docs/design/DISCO-DESIGN-SYSTEM.md` D-11, read in full; findings UI-01/M-25):

1. **`lib/core/design_tokens/app_colors.dart`** (NEW) — `abstract final class
   AppColors` with the complete §2 palette: neutrals `discoBlack #000000` /
   `surface #0A0A0A` / `surfaceAlt #111111` / `hairline #1A1A1A` / `border
   #333333` / `muted #666666` / `mutedStrong #999999` / `white #FFFFFF`;
   signature `glowPink #FF2E88` + `glowPinkBright #FF5CA8` + `glowPinkDeep
   #C2185B`; accents `discoViolet #8B5CF6` / `discoCyan #00E5FF` / `discoGold
   #FFC94D` / `discoSilver #C0C0C0` / `discoBronze #CD7F32` — each with usage
   comment + contrast note (values from the doc's §2 tables). Also:
   - `AppColors.all` name→color map (tests/tooling).
   - `AppColors.contrastRatio(foreground, background)` — pure WCAG 2.2
     relative-luminance helper (reusable by the U-26 a11y audit).
   - **`SamayThemeExtension`** (ThemeExtension subclass) exposing the full
     palette with `copyWith`/`lerp` + `static const dark` default — the
     design-doc §8 U-04 shape, provided now so
     `Theme.of(context).extension<SamayThemeExtension>()` works.
2. **`lib/core/extensions/context_extensions.dart`** (NEW) — finding UI-07
   convenience getters on `BuildContext`:
   - `samayColors` — the registered `SamayThemeExtension`, falling back to
     `SamayThemeExtension.dark` when unregistered (test-harness safe).
   - `textTheme` / `colorScheme` / `isDark` — Theme shorthands
     (**completed in the resume run**).
3. **`lib/core/design_tokens/app_spacing.dart`** (NEW) — 8-step scale
   `none 0 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48` +
   semantic aliases per §4.1 (`screenHorizontal/screenVertical = xl`,
   `cardPadding/buttonPadding/inputPadding = lg`, `listGap = sm`,
   `sectionGap = xl`, `avatar 40`, `avatarLarge 80`) + `scale(context, v)`
   responsive helper (§7.3).
4. **`lib/core/design_tokens/app_radius.dart`** (NEW) — **sharp everywhere**:
   `none/radiusZero = 0` (+ unused xs/sm/md/lg per the doc's `(unused)` marks),
   `full = 999` for the only exceptions (avatars, live dots), `sharp =
   BorderRadius.zero` convenience.
5. **`lib/core/design_tokens/app_elevation.dart`** (NEW) — flat: `none = []`,
   `card = []` (hairline border instead), `glowPink` + `glowCyan` brand glow
   stacks exactly per §4.3 (α0.45/24 + α0.2/48).
6. **`lib/core/design_tokens/app_icon_sizes.dart`** (NEW) — §4.4 scale
   `xs 12 · sm 16 · md 20 · lg 24 · xl 32 · xxl 48` + `avatar 40` /
   `avatarLarge 80`.
7. **Durations:** kept `lib/core/theme/samay_durations.dart` as the single
   source (I-05/U-18 own it — `fast/standard/slow` + `easeOutCubic`); NO
   app_durations.dart was created and tokens do not redefine durations.
8. **Widget/theme migration (no visual change):** replaced hardcoded
   colors/spacing with token references in `app_theme.dart` and all shared
   widgets (`v_button`, `v_card`, `v_input`, `v_chip`, `v_badge`,
   `v_shard_icon`, `error_banner`, `error_view`, `show_app_error`,
   `route_error_screen`, `v_coming_soon`). Values are bit-identical to the
   previous literals (verified by the widget test suite asserting exact
   colors). `rank_badge.dart` keeps legacy greys (no §2 token equals
   `grey[900]/grey[700]`) — flagged for U-05's §5.5 restyle.
9. **I-17 coordination:** their completed `app_theme.dart` disco rework
   (DiscoPalette/AppThemeExtension/glowTitleStyle) was rebuilt on top of the
   I-16 tokens (exactly as I-17's log pre-planned: "U-01 should move the
   consts… U-04 should fold AppThemeExtension into the planned
   SamayThemeExtension") — the ThemeData now composes `AppColors` +
   `SamayThemeExtension.dark`, keeps `SamayTheme.glowTitleStyle` (strong/soft
   stacks per §3.4) and the Playfair Display display scale (§3.3). No stale
   `AppThemeExtension`/`DiscoPalette` references remain anywhere in `lib/`
   or `test/` (grep-verified in the resume run).

## Resume-run completion (what the interrupted run left unfinished)

- **`context_extensions.dart` only had `samayColors`.** The mission's four
  getters are now all present (`samayColors`, `textTheme`, `colorScheme`,
  `isDark`), each covered by a widget test.
- **M-25 TODO.md status was still ❌.** Now ✅ (see below).
- **Verification matrix re-run green** (see Commands run).

## Files created / modified (lock evidence)

Locks via `tools/agent_lock.sh acquire <path> --owner I-16-design-tokens`
(released after edits):

| File | Action | Lock evidence |
|---|---|---|
| `lib/core/design_tokens/app_colors.dart` | created | acquire 959cdcec01658a8cb69fcff9 → release |
| `lib/core/design_tokens/app_spacing.dart` | created | acquire a3b0820e10627b2410952fa6 → release |
| `lib/core/design_tokens/app_radius.dart` | created | acquire 1a7ff6282d1340febfaf6511 → release |
| `lib/core/design_tokens/app_elevation.dart` | created | acquire e4400b84be293529192d9549 → release |
| `lib/core/design_tokens/app_icon_sizes.dart` | created | acquire 689ce1c1d8dd86b05be3bbe4 → release |
| `lib/core/extensions/context_extensions.dart` | created + **completed (resume)** | acquire 9b4241afbc5b1baf00860b09 → release (resume: 9b4241afbc5b1baf00860b09 re-acquired) |
| `lib/core/theme/app_theme.dart` | modified | acquire 5012349ec44717814afddeb2 → release |
| `lib/shared/widgets/v_button.dart` | modified | acquire 77b5f0c07a60ec6e7479f407 → release |
| `lib/shared/widgets/v_card.dart` | modified | acquire 0bbc383a16dec87368797fe8 → release |
| `lib/shared/widgets/v_input.dart` | modified | acquire 49f26a31dc425a78e83014a1 → release |
| `lib/shared/widgets/v_chip.dart` | modified | acquire b443f43e7bf801b7a76ff9ca → release |
| `lib/shared/widgets/v_badge.dart` | modified | acquire 1b897f697779f193a1b19035 → release |
| `lib/shared/widgets/v_shard_icon.dart` | modified | acquire b3ccd2861349137d607ea673 → release |
| `lib/shared/widgets/error_banner.dart` | modified | acquire 4df1b93feeb2dcf21840df13 → release |
| `lib/shared/widgets/error_view.dart` | modified | acquire f7e08c07ae26ea9ac7f3b1fc → release |
| `lib/shared/widgets/show_app_error.dart` | modified | acquire 940e3c274ff0c5c3c2fd4b6e → release |
| `lib/shared/widgets/route_error_screen.dart` | modified | acquire aaa77ebf8c818083d7fd18a7 → release |
| `lib/shared/widgets/v_coming_soon.dart` | modified | acquire 6a4a71094adc35e05dc469b6 → release |
| `lib/shared/widgets/rank_badge.dart` | modified (comments only) | acquire bdf52acde97d97a74463a34c → release |
| `test/design_tokens/app_colors_test.dart` | created | acquire 075ae119636c964952111ab0 → release |
| `test/design_tokens/app_spacing_test.dart` | created | acquire b75e3cec293b60c9aebddd6c → release |
| `test/theme/theme_extension_test.dart` | created + **extended (resume: 4 getter tests)** | acquire 48f660056c7ad3888b537026 → release (resume: re-acquired) |
| `test/theme/app_theme_test.dart` | modified (I-17's file: `DiscoPalette`→`AppColors`, `AppThemeExtension`→`SamayThemeExtension`) | acquire 0df1a90c7bf3f192538baf73 → release |
| `docs/history/phase-02-flutter-foundation/2026-08-09_I16-design-tokens.md` | created + overwritten (this log) | acquire 7d65a9357e601780aabec036 → release (resume: re-acquired) |
| `docs/to-fix/TODO.md` | M-25 status updated | acquire (waited for I-15, see below) → release |

## Commands run (reproducibility)

```bash
export AGENT_NAME="I-16-design-tokens"
tools/agent_lock.sh list                          # I-15 held TODO.md; waited (background acquire)
tools/agent_lock.sh acquire <file> --owner "$AGENT_NAME"   # all paths, ACQUIRED
flutter test test/design_tokens/ test/theme/ test/widgets/   # GREEN: 114/114 (resume re-run)
flutter test test/router/                                     # GREEN: 116/116 (resume re-run)
dart analyze                                                  # 0 errors, 1 pre-existing warning
                                                              # (unused_import in shards_service.dart, I-11's)
tools/agent_lock.sh release <file> --owner "$AGENT_NAME"
```

## Test results

- `test/design_tokens/app_colors_test.dart` — 17/17: every §2 hex exact,
  palette completeness vs `AppColors.all`, text-safe colors ≥4.5:1 on black,
  `muted`/`glowPinkDeep` large-text-only bands, depth-only surfaces <3:1,
  documented ratios (glowPink 6.00, cyan 13.65, gold 13.71 …) within 0.05,
  contrast helper pure/symmetric.
- `test/design_tokens/app_spacing_test.dart` — 6/6: scale values + monotonic,
  aliases map to scale + exact px, `scale()` honors the textScaler.
- `test/theme/theme_extension_test.dart` — 12/12: full palette exposure,
  copyWith/lerp, resolution via `Theme.of(context).extension<…>()`,
  `context.samayColors` + unregistered fallback, and (resume) the four
  `context.textTheme` / `context.colorScheme` / `context.isDark` getters
  under dark and light themes.
- `test/theme/app_theme_test.dart` (I-17's 25) — adapted to final token
  names; all pass on the rebuilt theme.
- `flutter test test/design_tokens/ test/theme/ test/widgets/` — **114/114**.
- `flutter test test/router/` — **116/116**.
- `dart analyze` — **0 errors / 0 warnings in I-16 files**; 1 pre-existing
  warning elsewhere (`shards_service.dart` unused import, I-11's file — left
  for its owner) + 14 pre-existing `use_build_context_synchronously` infos.

## Decisions made and why

- **Spacing scale follows the design doc (§4.1), not Juega's**: `none 0 ·
  xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48`. `AppSpacing` is
  the token single source; UI-01's "9 semantic aliases" are the §4.1 table.
- **Radius = sharp everywhere** (§4.2): no small radii were "allowed" for
  chips in the doc — it explicitly marks xs/sm/md/lg as `(unused)` and says
  "Every UI component radius = 0". Only avatars/dots get `full`.
- **Elevation = flat**: only the two brand glow stacks exist; `card` is `[]`
  with a comment that the hairline border carries the geometry.
- **`muted #666666` stays** for the bottom-nav unselected icon (3.66:1 ≥ 3:1
  non-text; design doc §2.4 is explicit) — I-17's decision, kept.
- **`v_input` label keeps `#666666` (muted)** for visual parity; the design
  doc §5.2 wants `mutedStrong #999999` — that restyle belongs to U-05.
- **`rank_badge.dart` grey[900]/grey[700] kept** — no §2 token has those
  exact values; U-05's §5.5 restyle specifies `border #333333` fill.
- **VShardIcon stays white** — the doc's gold (§5.6) is U-05's restyle;
  migration must not change visuals.
- **ThemeExtension placed in `app_colors.dart`** next to the palette (single
  file of truth), registered in `app_theme.dart` `extensions:`.
- **No app_durations.dart** — `samay_durations.dart` remains the source
  (owned by I-05/U-18; design doc §4.5 U-18 row). Tokens do not duplicate it.

## MISTAKE (original run)

- **Nearly clobbered I-17's uncommitted work in `app_theme.dart`.** I-17's
  lock had been released and my mission listed the theme file, so I rewrote
  it from the pre-I-17 state — destroying I-17's disco rework. Recovery:
  I-17's daily log described the work precisely (DiscoPalette/
  AppThemeExtension/glowTitleStyle/Playfair scale/`scrolledUnderElevation`),
  and their 25-test file pinned the API, so the theme was faithfully
  rebuilt — this time on top of the I-16 tokens as I-17's log had planned.
  Lesson: when a peer agent's log shows DONE for a file in your lock list,
  diff the working tree (or their test file) before rewriting; prefer
  composing over replacing.

## Issues found / coordination notes

- **I-15 (in progress at resume):** held `docs/to-fix/TODO.md` (14:13Z) while
  extracting auth strings to ARB. I waited per semaphore semantics; M-25 was
  updated only after their lock was released.
- **I-18:** `test/assets/fonts_test.dart` + pubspec font declarations landed
  (locks released by resume); fonts registered under exactly the family names
  the theme references.
- **I-19:** `v_network_image.dart` + 13 widget tests landed and pass
  (114-test widgets/theme/design_tokens batch green) — no overlap with the
  token migration.
- **structure_test.dart** failures remain — documented baseline, I-48's.
- **U-05/U-12/U-27:** the remaining literal colors in shared widgets
  (`rank_badge` greys, `v_input` hint `#444444`, `v_coming_soon` greys +
  56px icon, `route_error_screen` grey, red error texts in features) are
  deliberately left for the disco restyle, which the token system now makes
  a pure tokens swap.
- **U-03:** `app_spacing.dart`/`app_radius.dart`/`app_elevation.dart`/
  `app_icon_sizes.dart` already live in `lib/core/design_tokens/` — extend
  them instead of re-creating.
- **Pre-existing (not mine, reported per AGENT-RULES):** `unused_import` in
  `lib/core/services/shards_service.dart:1` (I-11's decomposition file).

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` (the spec, read in full) — §2 palette
  + contrast tables, §4 tokens, §7 accessibility, §8 extension rules.
- WCAG 2.2 SC 1.4.3 contrast formula: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- Flutter `ThemeExtension` API: https://api.flutter.dev/flutter/material/ThemeExtension-class.html
- Juega reference (read-only): `lib/core/design_tokens/app_spacing.dart` +
  `app_radius.dart` + `app_elevation.dart` + `lib/core/theme/app_colors.dart`
  + `app_theme_extension.dart` (structure mirrored; values are Samay's own).
