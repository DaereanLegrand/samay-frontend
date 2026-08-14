# U-05 — Shared-widgets §5 restyle: the 15-widget disco pass + palette guard (2026-08-11)

**Agent:** U-05 | **Phase:** 04-ui (4.4) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §5.1–§5.9 (read in full — THE
CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md` +
`docs/process/DEVELOPMENT-WORKFLOW.md` (read in full), U-01..U-04 daily logs +
U-01's handoffs, AGENTS.md. Baseline before edits: `dart analyze` 0 issues;
full `flutter test` **1707/0** (U-04 checkpoint).

## What was built

The §5 component contract applied widget-by-widget across **all 15 files** in
`lib/shared/widgets/` (the brief's "14" + `rank_bracket.dart` (pure logic —
audited, no visual content)). Every color now comes from `AppColors`/semantic
aliases; spacing/radius/typography come from the tokens; shapes are sharp;
raw Material greys/reds and the last stray hex (`v_input` `#444444`) are
gone. **Deliberate visual corrections per §5** (the point of this phase) —
each with its test update, in the ledger below.

### The visual-change ledger (widget → §5 ref → change → test update)

| Widget | §5 ref | Change (visual) | Test update |
|---|---|---|---|
| `v_input.dart` | §5.2 | hint `#444444` → `AppColors.muted #666666` (U-01's handoff; §5.2 "Hints: #666666 allowed") | `v_input_test` +hint `muted` assertion |
| `v_input.dart` | §5.2 | label `muted #666666` → `mutedStrong #999999` (the doc's own "fix from #666666 — fails 1.4.3", §2.4) | +label `mutedStrong` assertion |
| `v_input.dart` | §5.2 | text style → white `bodyLarge` (was white, default size) | +style assertions |
| `v_input.dart` | §5.2 | NEW `errorText` param, `errorStyle: AppColors.error` (glowPink — never raw red) | +error test |
| `v_card.dart` | §5.3 | fill `discoBlack` → `surface #0A0A0A`; border `border #333333` → **hairline `#1A1A1A`** (was 2 sides, same) | `v_card_test`: fill `surface`, border color `hairline` width 1, +padding |
| `v_button.dart` | §5.1 | NEW `VButton.glowAccent` (pink 1px border or pink fill via `filled:`, black/pink text, glow-hairline shadow on the label; pressed = `glowPinkDeep` fill + white text) | +5 tests (border/fill/pressed/disabled/loading) |
| `v_button.dart` | §5.1 | loading spinner now in the **foreground color** (was theme-white → invisible on the white emphasized fill) | +spinner color test |
| `v_button.dart` | §5.1 | disabled now drops **outline AND text** to `muted #666666` (was white text + white border) | +disabled test |
| `v_button.dart` | §5.1 | press overlay now variant-aware: white α0.1 on outlined/glow-border, black α0.1 on emphasized/glow-filled | covered by style resolution |
| `v_chip.dart` | §5.4 | label → `labelMedium` typography (was theme-default; size 12/w600/ls0.8 now explicit) | +typography assertions |
| `v_chip.dart` | §5.4 | NEW `VChip.accent` (glowPink border+label, pink fill selected) | +2 accent tests |
| `v_badge.dart` | §5.5 | default fill white→`border #333333` + white text (**fixes the invisible white-on-white badge**); label → `labelSmall` 10px **uppercase** (§3.3) | +default/emphasized/accent tests |
| `v_badge.dart` | §5.5 | NEW `VBadge.emphasized` (white fill + black text) and `VBadge.accent(color:)` (accent border + same-color text, black fill) | +2 tests |
| `v_shard_icon.dart` | §5.6 | diamond white → **`discoGold`** (default 16px); white-only mode via `color:` | NEW `v_shard_icon_test.dart` (4 tests) |
| `rank_badge.dart` | §5.5 | grey[900]/grey[700] → `border #333333` fill + white label (U-01's handoff) | +fill/border assertion |
| `rank_badge.dart` | §5.5 | NEW podium `rank:` 1–3 → `discoGold`/`discoSilver`/`discoBronze` border + label; non-top rows stay white | +3 tier tests |
| `v_coming_soon.dart` | §5.7 | icon 56px grey[800] → **`xxl 48` `border #333333`** (+`iconColor` for the faint-pink hero option) | +icon test |
| `v_coming_soon.dart` | §5.7 | "Próximamente" 24px Inter bold → **Playfair Display italic 32 `glow-soft`** (§3.2) | +style test |
| `v_coming_soon.dart` | §5.7 | description grey[500] → `bodyMedium` `mutedStrong` | +style test |
| `route_error_screen.dart` | §5.7/§5.9 | icon 56px `Colors.grey` → `xxl 48` `border #333333` | (no dedicated test file — covered by analyze + suite) |
| `state_views.dart` | §5.8 | loading caption → `bodyMedium` + `mutedStrong` (was 14px raw) | existing assertions hold |
| `state_views.dart` | §5.9 | empty-state description → `bodyMedium` + `mutedStrong`; icon→title gap lg→`sectionGap` | +fontSize/icon-size assertions |
| `v_network_image.dart` | §5.8 | placeholder grey[900] → `surfaceAlt #111111` (skeleton base); error grey[800] → `border #333333`; icon white24 → `muted` | `v_network_image_test` assertions → token values |
| `error_banner.dart` / `error_view.dart` | §5.9 | message → `bodyMedium` + `mutedStrong` (was 14px raw) | tests repointed to `AppColors` refs (same values) |
| `show_app_error.dart` | §5.2/§5.9 | dialog content + snackbar text → `bodyMedium` + white/`mutedStrong` | (no color assertions — unchanged) |
| `connectivity_banner.dart` | §5.2/§2.3 | offline icon `colorScheme.error` (M3 #FFB4AB red) → **`AppColors.error` (glowPink)** — never red on black | +icon color test |

### Conventions guard (`test/meta/conventions_test.dart`)

New group **"shared-widget palette guard (U-05)"**, RED-proven against the
pre-restyle tree (it flagged exactly the 10 grey/red sites + 1 hex):
1. **No raw hue `Colors.*`** in `lib/shared/widgets` — regex bans
   red/green/grey/gray/blue/amber/orange/purple/pink/teal/cyan/indigo/brown/
   lime/yellow/deepOrange/deepPurple/lightBlue/lightGreen/blueGrey + the
   alpha variants (white24…black87). `Colors.white`/`Colors.black`/
   `Colors.transparent` stay legal (the doc's own P2 primitives).
2. **No ad-hoc `Color(0x…)` hex literals** in `lib/shared/widgets` (§8.1
   "extending the system" — tokens only).
Also updated the U-03 guard's allowlists: `edgeInsetsAllowlist` line refs
(`v_button.dart:165`, `error_banner.dart:35/62` — the format pass wrapped the
banner paddings multi-line, which the line-based regex can't see; documented
in a comment); `iconSizeAllowlist` is now **empty** — the last two 56px icons
(coming-soon, route-error) moved to `AppIconSizes.xxl`.

### Feature-test fallout (expected, documented)

`VBadge` labels now render uppercase (§3.3 `labelSmall`), so two feature
tests were updated to the §3.3-correct rendering (handled + documented, per
the mission):
- `test/features/cosmetics/cosmetics_shop_screen_test.dart` — 3× `Adquirido`
  → `ADQUIRIDO`.
- `test/features/subscriptions/paywall_test.dart` — 2× `Actual` → `ACTUAL`.

## Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire <path> --owner U-05` (all held
03:58Z–04:0xZ, released after). 15 widgets + 13 test files + conventions
guard + TODO + this log:

| File | Action |
|---|---|
| `lib/shared/widgets/v_button.dart` | modified (§5.1 full pass + glowAccent) |
| `lib/shared/widgets/v_input.dart` | modified (§5.2) |
| `lib/shared/widgets/v_card.dart` | modified (§5.3) |
| `lib/shared/widgets/v_chip.dart` | modified (§5.4 + accent) |
| `lib/shared/widgets/v_badge.dart` | modified (§5.5 + variants) |
| `lib/shared/widgets/v_shard_icon.dart` | modified (§5.6 gold) |
| `lib/shared/widgets/rank_badge.dart` | modified (§5.5 tokens + podium) |
| `lib/shared/widgets/v_coming_soon.dart` | modified (§5.7) |
| `lib/shared/widgets/state_views.dart` | modified (§5.8/§5.9) |
| `lib/shared/widgets/v_network_image.dart` | modified (§5.8 surfaces) |
| `lib/shared/widgets/error_banner.dart` | modified (§5.9 bodyMedium) |
| `lib/shared/widgets/error_view.dart` | modified (§5.9 bodyMedium) |
| `lib/shared/widgets/show_app_error.dart` | modified (§5.2/§5.9 bodyMedium) |
| `lib/shared/widgets/connectivity_banner.dart` | modified (§5.2 error icon) |
| `lib/shared/widgets/route_error_screen.dart` | modified (§5.7/§5.9 icon) |
| `test/widgets/v_button_test.dart` | modified (5→11) |
| `test/widgets/v_input_test.dart` | modified (3→8) |
| `test/widgets/v_card_test.dart` | modified (4→5) |
| `test/widgets/v_chip_test.dart` | modified (3→9) |
| `test/widgets/v_badge_test.dart` | modified (2→5) |
| `test/widgets/v_shard_icon_test.dart` | **created** (4) |
| `test/widgets/rank_badge_test.dart` | modified (7→11) |
| `test/widgets/v_coming_soon_test.dart` | modified (4→7) |
| `test/widgets/state_views_test.dart` | modified |
| `test/widgets/v_network_image_test.dart` | modified (token assertions) |
| `test/widgets/error_banner_test.dart` | modified (AppColors refs) |
| `test/widgets/error_view_test.dart` | modified (AppColors refs) |
| `test/widgets/connectivity_banner_test.dart` | modified (+1) |
| `test/meta/conventions_test.dart` | modified (+2 guard tests, allowlists) |
| `test/features/cosmetics/cosmetics_shop_screen_test.dart` | modified (ADQUIRIDO, ⚙️ I-45's file — lock coordinated) |
| `test/features/subscriptions/paywall_test.dart` | modified (ACTUAL, ⚙️ I-45's file — lock coordinated) |
| `docs/to-fix/TODO.md` | modified (workstream block) |
| `docs/history/phase-04-ui/2026-08-11_U05-widgets-restyle.md` | created (this log) |

## Commands run (reproducibility)

```bash
export AGENT_NAME="U-05"
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0
tools/agent_lock.sh acquire <30 files> --owner U-05        # 30 locks held
# ... 15 widget edits + 14 test-file edits ...
dart analyze lib/shared/widgets/                          # iterated to 0
flutter test test/widgets/ test/meta/                     # 152/152
flutter test test/features/ test/theme/ test/design_tokens/  # 554/554
flutter test                                               # FULL 1740/0
dart format lib/shared/widgets/ test/widgets/ test/meta/  # +2 feature tests
dart analyze                                               # 0 (post-format)
flutter test test/widgets/ test/meta/ test/features/{cosmetics,subscriptions}  # 173/173
flutter test                                               # FULL 1740/0 (2nd)
tools/agent_lock.sh release <path> --owner U-05            # all 32
```

## Test results

- `dart analyze` — **0 issues** (pre- and post-format).
- `flutter test test/widgets/ test/meta/` — **152/152**.
- `flutter test test/features/ test/theme/ test/design_tokens/` — **554/554**.
- `flutter test` (full, ×2) — **1740 pass / 0 failures** (U-04 baseline
  1707/0 → +33: 30 new widget/meta tests + the shard-icon file; two feature
  test bodies updated to the §3.3-uppercase badge rendering, zero
  regressions).

## MISTAKE

- **Lost the emphasized variant (caught by tests, fixed):** removing the
  legacy `outlined` bool from `VButton` orphaned the `emphasized` factory —
  it silently fell back to the outlined variant (white-on-white text
  regressed). The two emphasized tests (white fill + spinner color) caught
  it immediately. Lesson: when deleting a state flag, re-check every factory
  that set it — the resolver switch is the single source, not the factories.
- **`private-named-parameters` experiment:** first tried a private
  `_variant` named field — the SDK (3.44.1-era, pre-3.12) rejects private
  named params; switched to the public `VButtonVariant` enum + public field.

## Decisions made and why

- **`VButtonVariant` public enum + public field:** needed for
  `library_private_types_in_public_api`-clean state without the private-
  named-parameter language feature. It is internal-by-convention: the
  factories remain the only constructors (the primary constructor is
  `VButton._`).
- **VBadge `color:` kept as fill-override** (cosmetics_shop_screen passes
  `color: AppColors.mutedStrong` for unowned items): the param keeps its
  emphasized-style meaning (colored fill + black text); `null` now means the
  §5.5 default `border #333333` fill + white text — which fixes the
  pre-existing invisible white-on-white badge (`paywall` "Actual").
- **Badges uppercase, chips don't:** §3.3 `labelSmall` is explicitly
  "Badges, rank labels, overlines (uppercase)" and §5.5's RankBadge spec
  says "uppercase" — applied to VBadge (2 feature-test updates) and
  RankBadge (already uppercased). §5.4's chip spec says only "white
  `labelMedium`" — chip call sites keep caller casing (flag for U-30).
- **VInput focus-accent variant (§5.2 "U-05 opt-in") not wired:** no
  consumer exists (login password/shard-amount fields come with U-07/U-09);
  the plumbing (`errorText`, tokens) is in place and the theme's
  `inputDecorationTheme` already carries the glowPink error style.
- **ConnectivityBanner icon = `AppColors.error`:** the M3 dark `colorScheme.error`
  (#FFB4AB) is a raw red-family color on black — §5.2 bans red-on-black;
  the semantic alias (glowPink, 6.00:1 AA) is U-01's ready-made swap.

## Issues found / handoffs

- **U-11:** `leaderboard_screen.dart:87` should pass `rank: rank_position`
  to `RankBadge` so the top-3 podium rows get the gold/silver/bronze accent
  (§5.5) — the widget capability ships here; the screen wiring is U-11's
  (leaderboard is its file).
- **U-09/U-11 visual check:** `cosmetics_shop_screen` + `paywall` badges
  now render `#333333`/uppercase (`ADQUIRIDO`, `ACTUAL`) — intended §5.5/
  §3.3 rendering, tests updated.
- **U-08/U-10:** chips in feed/friends/events keep caller casing; the
  `VChip.accent` variant is available for brand moments.
- **U-30 (doc finalization):** (1) §5.4/§3.3 — decide once whether chip
  labels are uppercase like badges (currently caller-cased); (2) §5.5 —
  promote the VBadge.emphasized/accent + RankBadge rank 1–3 podium accents
  (they're mission-brief + widget-file only today); (3) the U-03 spacing
  guard's line-based regex misses multi-line `EdgeInsets` — consider a
  whole-file scanner.
- **U-07/U-09:** `VInput.errorText` + `VButton.glowAccent` are ready for the
  auth/profile restyles (login password field, shard-amount inputs).
- **U-26 (a11y):** VBadge default white-on-`#333333` = 21:1 text; accent
  badge text = accent color ≥4.96:1; rank podium label ≥6.68:1; connectivity
  icon glowPink 6.00:1 — all AA.

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §2–§5 (read in full — the contract).
- Flutter SDK (read-only, 3.44.1): `ButtonStyle`/`WidgetStateProperty`
  resolution semantics; `TextButton.styleFrom` overlayColor base-color
  behavior (documented by U-04).
- U-01 daily log + handoff table (hint/rank greys), U-03 audit table
  (14px/10px keepers, 56px icon restyle targets), U-04 theme log.
- WCAG 2.2 SC 1.4.3/1.4.11 (via the doc's §2 ratio tables).
