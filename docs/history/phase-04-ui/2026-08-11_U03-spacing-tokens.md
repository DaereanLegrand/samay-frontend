# U-03 — Spacing/radius/elevation/icon tokens: doc parity + shared-widget literal audit (2026-08-11)

**Agent:** U-03 | **Phase:** 04-ui (4.4) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §4 (read in full — THE
CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md`
(read in full), I-16/U-01/U-02 logs. Baseline before edits: `dart analyze`
0 issues; `flutter test test/design_tokens/ test/widgets/ test/meta/`
170/170; full `flutter test` 1679/0 (U-02 checkpoint).

## 1. Doc-parity verification (the 4 token files vs §4)

Re-verified hex/value-by-value after U-01/U-02 (tokens are the single
source). **All four files are doc-exact — zero token values changed:**

| File | §4 contract | Verified |
|---|---|---|
| `app_spacing.dart` | scale `none 0 · xs 4 · sm 8 · md 12 · lg 16 · xl 24 · xxl 32 · xxxl 48` + aliases (`screenHorizontal/Vertical = xl 24`, `cardPadding/buttonPadding/inputPadding = lg 16`, `listGap = sm 8`, `sectionGap = xl 24`, `avatar 40`, `avatarLarge 80`) + `scale(context, v)` | ✓ exact |
| `app_radius.dart` | sharp: `none 0`, `xs 2/sm 4/md 8/lg 12` (unused), every component 0, `full` circles only (avatars/live dots), `sharp = BorderRadius.zero` | ✓ exact |
| `app_elevation.dart` | flat: `none []` / `card []`; glow stacks α0.45/blur24 + α0.2/blur48 over `glowPink`/`discoCyan` (`0x73`=115/255≈0.45, `0x33`=51/255=0.2 exact) | ✓ exact |
| `app_icon_sizes.dart` | `xs 12 · sm 16 · md 20 · lg 24 · xl 32 · xxl 48` + `avatar 40`/`avatarLarge 80` | ✓ exact |

## 2. Raw-literal audit of `lib/shared/widgets/` (zero visual change)

Guard philosophy: migrate ONLY where a token equals the current value 1:1;
keep + document everything else (14, 56, 10, 6, 3, 2, 18, 14-icon have no
token). `AppElevation`/`AppRadius` have zero consumers in `lib/` today —
wiring them is U-05/U-06's restyle scope (featured-card glow, QR ring).

### Migrated → tokens (16 sites, value-identical)

| Site | Was | Token |
|---|---|---|
| `v_button.dart` shape | `RoundedRectangleBorder()` | `RoundedRectangleBorder(borderRadius: AppRadius.sharp)` |
| `v_chip.dart` shape | `RoundedRectangleBorder()` | `RoundedRectangleBorder(borderRadius: AppRadius.sharp)` |
| `error_banner.dart:33` padding h | 12 | `AppSpacing.md` |
| `error_banner.dart:46` gap | 12 | `AppSpacing.md` |
| `error_banner.dart:54` gap | 8 | `AppSpacing.sm` |
| `error_banner.dart:56` retry padding v | 4 | `AppSpacing.xs` |
| `error_banner.dart:63` close icon | 16 | `AppIconSizes.sm` |
| `error_banner.dart:68` gap | 4 | `AppSpacing.xs` |
| `show_app_error.dart:48` gap | 12 | `AppSpacing.md` |
| `connectivity_banner.dart:30` padding h | 12 | `AppSpacing.md` |
| `connectivity_banner.dart:45` gap | 8 | `AppSpacing.sm` |
| `rank_badge.dart:15` padding h | 8 | `AppSpacing.sm` |
| `v_network_image.dart:69` placeholder icon | 20 | `AppIconSizes.md` |

### Kept with reason (guard-allowlisted: 14 / 10 / 56; rest unguarded)

| Site | Value | Reason (no token equals it) |
|---|---|---|
| `v_button.dart:82` padding | 14/14 | Doc §5.1 pins 14px vertical padding; 14 ∉ scale. **Guard-allowlisted.** |
| `error_banner.dart:33/56` | 10 | Compact banner paddings; no token between sm 8 / md 12. **Guard-allowlisted.** |
| `v_coming_soon.dart:32` icon | 56 | No icon-size token (max xxl 48); §5.7 restyle target = U-12. **Guard-allowlisted.** |
| `route_error_screen.dart:32` icon | 56 | Same — §5.9 empty-state target xxl 48, U-12. **Guard-allowlisted.** |
| `v_badge.dart` vertical | 2 | No token (xs = 4). Mini-badge geometry. |
| `rank_badge.dart` vertical | 3 | No token. Mini-badge geometry. |
| `connectivity_banner.dart` vertical | 6 | No token. Slim-strip geometry. |
| `error_banner`/`show_app_error` icons | 18 | No token (between sm 16 / md 20). |
| `connectivity_banner` icon | 14 | No token (between xs 12 / sm 16). |
| `v_button`/`state_views` spinners | 20/24 | Spinner dims are not icons; §5.8 pins 24px; `AppIconSizes` is icon-scoped. |
| 4× CTA widths | 200 | Component width, not a spacing step. |
| `fontSize` 14/11/24, `letterSpacing` 0.5 | — | Typography = U-02/U-05 scope (not spacing/radius/icon). |

### Already tokenized (audited, no change)

`v_card.dart` (`cardPadding`), `v_shard_icon.dart` (`AppIconSizes.sm`
default), `v_input.dart` (no spacing/radius/icon literals — only a border
`width: 2`), `state_views.dart`/`error_view.dart`/`route_error_screen.dart`
spacing (`AppSpacing.xl/lg/sm`, `AppIconSizes.xxl`).

## 3. withValues evaluation (U-01 handoff) — DOCUMENTED, NOT APPLIED

`AppColors.glowPink.withValues(alpha: 0.45)` vs the composited
`Color(0x73FF2E88)`:

- **Rendered output:** identical within 8-bit alpha quantization —
  `0x73` = 115/255 = 0.45098 and `0.45` → 114.75/255 both quantize to the
  same paint alpha; `0x33` = 51/255 = 0.2 is exact.
- **Const-ness:** `Color.withValues` is a **non-const instance method**, so
  the glow lists would drop from `static const` (→ `static final`).
  Const-ness is a token-contract property (§4.3 lists are const; the
  `glowPink`/`glowCyan` const-canonicalization test now locks it).
- **Verdict:** criterion "render-identical **+ keeps const-ness**" fails →
  composited const hexes kept, with an expanded rationale comment in
  `app_elevation.dart` (the new const-canonicalization test in
  `test/design_tokens/app_elevation_test.dart` prevents a future silent
  const→final downgrade).

## 4. Tests (TDD: guard RED first, then GREEN)

- **RED proof:** the new guard (`EdgeInsets` 10–19 in shared widgets)
  failed against the unmigrated tree with exactly the expected offenders
  (`v_button.dart:81`, `connectivity_banner.dart:29`, `error_banner.dart`
  ×2) — then GREEN after the token migrations.
- `test/design_tokens/app_radius_test.dart` (NEW, 5) — sharp scale,
  `BorderRadius.zero`, unused nominal values, `full` circles.
- `test/design_tokens/app_elevation_test.dart` (NEW, 5) — flat none/card,
  2-layer glow stacks, exact α (closeTo 0.45/0.2) + RGB channels +
  offsets/blurs, **const-canonicalization** of both stacks.
- `test/design_tokens/app_icon_sizes_test.dart` (NEW, 3) — §4.4 values +
  monotonic + avatar scale.
- `test/meta/conventions_test.dart` (I-48's file, +2 guard tests) —
  `EdgeInsets` 10–19 in `lib/shared/widgets/` must be `AppSpacing` or
  allowlisted (14/10 keepers); `Icon size:` 50–59 must be allowlisted
  (56px keepers).

## Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire <path> --owner U-03`, held for
the whole edit, released after:

| File | Action | Lock evidence |
|---|---|---|
| `test/design_tokens/app_radius_test.dart` | created | acquire → release |
| `test/design_tokens/app_elevation_test.dart` | created | acquire → release |
| `test/design_tokens/app_icon_sizes_test.dart` | created | acquire → release |
| `test/meta/conventions_test.dart` | modified (+2 guard tests) | acquire → release |
| `lib/core/design_tokens/app_elevation.dart` | modified (withValues rationale comment only — no value change) | acquire → release |
| `lib/shared/widgets/v_button.dart` | modified (shape token) | acquire → release |
| `lib/shared/widgets/v_chip.dart` | modified (shape token) | acquire → release |
| `lib/shared/widgets/state_views.dart` | audited — no change | n/a |
| `lib/shared/widgets/v_network_image.dart` | modified (icon size token) | acquire → release |
| `lib/shared/widgets/error_banner.dart` | modified (5 sites) | acquire → release |
| `lib/shared/widgets/show_app_error.dart` | modified (gap token) | acquire → release |
| `lib/shared/widgets/connectivity_banner.dart` | modified (2 sites) | acquire → release |
| `lib/shared/widgets/rank_badge.dart` | modified (padding h token) | acquire → release |
| `docs/to-fix/TODO.md` | modified (U-03 workstream block) | acquire → release |
| `docs/history/phase-04-ui/2026-08-11_U03-spacing-tokens.md` | created (this log) | acquire → release |

## Commands run (reproducibility)

```bash
export AGENT_NAME="U-03"
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
flutter test test/design_tokens/ test/widgets/ test/meta/  # baseline 170/170
tools/agent_lock.sh acquire <15 files> --owner U-03        # one per command
# ... write tests (radius/elevation/icon_sizes/guard) ...
flutter test test/design_tokens/app_radius_test.dart test/design_tokens/app_elevation_test.dart \
  test/design_tokens/app_icon_sizes_test.dart test/meta/conventions_test.dart
# RED: guard fails — offenders v_button:81 + connectivity_banner:29 + error_banner ×2
# ... migrate widgets, update allowlist lines ...
flutter test test/design_tokens/ test/meta/                # 85/85
flutter test test/widgets/                                 # 100/100
dart analyze                                               # 0 issues
flutter test                                               # 1694/0 (baseline 1679 → +15)
tools/agent_lock.sh release <path> --owner U-03            # all 15
```

## Test results

- `test/design_tokens/` — **66/66** (spacing 6 + colors 21 + typography 26 +
  radius 5 + elevation 5 + icon sizes 3).
- `test/meta/` (incl. the 2 new guards) — **19/19**.
- `test/widgets/` — **100/100** (unchanged assertions — zero visual change
  proven).
- Full `flutter test` — **1694 pass / 0 failures** (+15 = the new tests).
- `dart analyze` — **0 issues**.

## MISTAKE

- **Multi-line `EdgeInsets` dodge (fixed):** my first error_banner edit
  formatted `EdgeInsets.symmetric(horizontal: md, vertical: 10)` across
  three lines — the line-based guard regex then never saw the `10` (the
  digit sat on a continuation line without the `EdgeInsets.` prefix), so
  the keeper would have escaped the guard silently. Fixed by collapsing
  both kept-10 paddings onto single lines so the guard matches and the
  allowlist documents them. Lesson: a line-based regex guard needs the
  raw value on the same line as the matched constructor, or it
  under-reports.

## Issues found / handoffs

- **U-30 (doc finalization):** §4.1 says `buttonPadding | lg (16) |
  matches v_button.dart`, but `v_button.dart` currently uses **14px**
  (§5.1 pins 14px). One of the two is wrong post-restyle — U-05 will
  decide at the §5.1 restyle; the doc note should be reconciled.
- **U-05:** `v_button` 14px padding → §5.1 keeps 14px (no token needed);
  `rank_badge` greys → `border #333333` fill (§5.5, pre-existing I-16
  handoff); `v_input.dart:40` hint `#444444` → `muted` (pre-existing).
- **U-12:** `v_coming_soon.dart` + `route_error_screen.dart` 56px icons →
  `AppIconSizes.xxl` (§5.7/§5.9 restyle targets — visual change);
  coming-soon greys (pre-existing).
- **U-06/U-05:** `AppElevation.glowPink/glowCyan` + `AppRadius.sharp`
  have zero consumers — wire them in the featured-card glow, QR ring and
  chip/button shapes as the restyle lands.
- **Pre-existing, not touched:** `shards_service.dart` unused import
  (I-11's file, still open per I-16's report — now no longer breaking
  analyze? re-checked: `dart analyze` 0 issues).

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §4 (spacing/radius/elevation/icon
  contracts, read in full), §5.1/§5.7/§5.9.
- Flutter SDK `Color.withValues` API (non-const instance method):
  https://api.flutter.dev/flutter/dart-ui/Color/withValues.html
- I-16 log (token files + widget migration history), U-01 log (the
  withValues handoff), U-02 log (typography checkpoint + test style).
