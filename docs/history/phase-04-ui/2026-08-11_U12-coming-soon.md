# U-12 — Coming-soon route polish: the §5.7 per-feature icon map + route audit (2026-08-11)

**Agent:** U-12 | **Phase:** 04-ui (4.4) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §5.7 + §3.2/§3.3 (read in full
— THE CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md`
+ `docs/process/DEVELOPMENT-WORKFLOW.md` (read in full), U-05/U-06 daily logs + their
handoffs, AGENTS.md. Baseline before edits: `dart analyze` **0 issues**; full
`flutter test` **1833/0** (U-08 checkpoint); target-file baseline
`test/widgets/v_coming_soon_test.dart` + `test/router/app_router_test.dart` +
`test/core/feature_flags_test.dart` = **98/98**.

## What was built

The route-level polish on top of U-05/U-06's already-§5.7-clean
`v_coming_soon.dart` (verified: icon `xxl 48` `border #333333`, headline
Playfair italic 32 glow-soft via `VGlowText`, description `bodyMedium`
`mutedStrong`, black AppBar — **zero widget changes needed**):

### 1. The per-feature icon map (§5.7) — the tasteful moment

`v_coming_soon.dart` already took an `icon:` param (default
`Icons.construction`); the work was assigning the right glyph per feature at
every instantiation. Full map in the report table. Highlights:

- **Party Finder** gets the §5.7 hero-topic treatment:
  `Icons.celebration` in **faint `glowPink` α0.5** (the only non-`border`
  icon — the one brand-allowance the §5.7 spec names by example).
- **Cosméticos** → `Icons.checkroom` (the wardrobe — matches the ES copy
  "Tu armario de cosméticos…").
- **Crear evento** → `Icons.event_note` (calendar-entry glyph). **MISTAKE
  avoided:** the mission suggested `Icons.add_event`, which does NOT exist in
  this SDK (3.44.1 — checked `material/icons.dart`); the RED compile error
  caught it before it shipped.
- All other routes per the mission's suggested map: events→`event`,
  chat→`chat`, qr→`qr_code`, scanner→`qr_code_scanner`,
  subscriptions→`subscriptions`, photos→`photo`, collage→`grid_view`,
  invite→`mail`, minigames→`sports_esports`, notifications→`notifications`.

### 2. Copy audit (FlagGate fallbacks + per-route titles/descriptions) — 0 fixes

Every gated route's fallback title/description matches its feature naming
(Eventos / Invitar / Fotos / Collage / Crear evento / Juegos / Chat / QR /
Escáner / Suscripciones / Party Finder / Cosméticos / Notificaciones — all
the I-69-wired l10n keys, `_defaultFallback` + router both). No copy changes
needed; the l10n keys were already consistent.

### 3. AppBar title treatment — decided, verified, pinned

Decision: coming-soon AppBar titles are **feature-name utility titles** —
clean Inter via the theme (default AppBar resolution of `titleLarge`), NOT
the Playfair `displaySmall` fancy treatment. The FANCY moment belongs to the
"Próximamente" headline only (done, U-05/U-06). This matches the app-wide
convention (all 42 `AppBar(title: Text(...))` sites — theme-styled, no
inline title styles). No widget change needed; pinned by a new test
(no inline style on the AppBar title + the theme's `titleLarge` is not
Playfair and has no glow).

### 4. Live-route verification (mission item) — no leftovers, one briefing fix

- `mainNotifications` → `NotificationCenterScreen` — LIVE ✓ (no coming-soon).
- `chat` → `ChatScreen` — LIVE ✓; kill-switch fallback correctly wired (new
  test pins the dark-flag fallback: 'Chat' + `Icons.chat`).
- `mainEvents` → `VComingSoonScreen` — **dark-first, correct**: the `events`
  flag defaults `false` (I-49 contract, pinned by `kDefaultFlagStates`);
  ECRT/EDET screens exist but the tab stays gated. Not a leftover.
- `qr`/`scanner` → gated on `AppFeatureFlag.qr` which defaults **false** —
  the coming-soon fallbacks are the correct dark-first state, NOT leftovers
  (the briefing's "qr/scanner live" is inaccurate: the flag is dark by
  default per the I-49 contract; flag-on → real screens, pinned by existing
  tests + `integration_test/qr_flow_test.dart` 2/2).

## Files created / modified (lock evidence)

All 8 locks via `tools/agent_lock.sh acquire <path> --owner U-12`
(acquired 07:36Z, released after — final release transcript in Commands):

| File | Action | Lock evidence |
|---|---|---|
| `lib/core/router/app_router.dart` | modified (icons at all 12 instantiation sites) | acquire 4fa1adae1da4e07e21097640 → release |
| `lib/core/config/feature_flags.dart` | modified (`_defaultFallback` icons + Party Finder hero color; imports material/app_colors) | acquire 8890a525cc57828bf6227fec → release |
| `test/router/app_router_test.dart` | modified (icon pins in the coming-soon table + mainEvents; +1 chat dark-flag test) | acquire b8475ef740cd24d12852ab03 → release |
| `test/core/feature_flags_test.dart` | modified (fallback icon pins, +1 Party Finder hero-color test, kill-switch icon) | acquire 1164c690a8da586bcfec5d84 → release |
| `test/widgets/v_coming_soon_test.dart` | modified (+3: AppBar-title pin, custom-icon, hero iconColor) | acquire e4aa90eec287b1b4683f4d21 → release |
| `integration_test/subscriptions_flow_test.dart` | modified (+icon pin in flag-off case; `Actual`→`ACTUAL` pre-existing fix — see Issues) | acquire 5866d3410849da626979a89f → release |
| `docs/to-fix/TODO.md` | modified (this workstream block) | acquire b802f899fb97030c6d655fd5 → release |
| `docs/history/phase-04-ui/2026-08-11_U12-coming-soon.md` | created (this log) | acquire f7c3f1d905e999f709e59946 → release |

`lib/shared/widgets/v_coming_soon.dart` was **verified only** (locked for
read, unmodified — U-05/U-06's §5.7 state is clean; no widget change was
needed).

## Commands run (reproducibility)

```bash
export AGENT_NAME="U-12"
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0
flutter test test/widgets/v_coming_soon_test.dart test/router/app_router_test.dart test/core/feature_flags_test.dart   # 98/98 baseline
tools/agent_lock.sh acquire <8 files> --owner U-12        # all held (see table)
# RED: +3 widget tests, icon pins in router + feature_flags tests, chat-dark test
flutter test test/router/app_router_test.dart test/core/feature_flags_test.dart
#   → 14 failures = RED (every missing icon) + compile error Icons.add_event (does not exist in this SDK)
# GREEN: icons wired in app_router.dart (12 sites) + feature_flags.dart (5 flags)
flutter test test/widgets/v_coming_soon_test.dart test/router/app_router_test.dart test/core/feature_flags_test.dart
#   → iterate: isNullOrEmpty → isNull; notifications dropped from the dark-fallback loop
#     (it's LIVE by default — the loop's flag semantics were wrong, its kill-switch
#     test already pins the icon); mainEvents icon scoped under VComingSoonScreen
#     (the bottom-nav Icons.event collides otherwise) → 103/103 GREEN
dart analyze                                               # 0 issues
flutter test                                               # FULL 1838/0 (baseline 1833 → +5)
flutter test integration_test/subscriptions_flow_test.dart -d iphone   # 2/2 (after the pre-existing 'Actual' fix)
flutter test integration_test/qr_flow_test.dart -d iphone              # 2/2
git diff -w == git diff (line counts equal)                # zero whitespace-only churn
tools/agent_lock.sh release <path> --owner U-12            # all 8 released
```

## Test results

- `dart analyze` — **0 issues** (pre- and post-edit).
- `test/widgets/v_coming_soon_test.dart` + `test/router/app_router_test.dart`
  + `test/core/feature_flags_test.dart` — **103/103** (98 baseline → +5:
  AppBar-title pin, custom-icon render, hero iconColor, chat kill-switch,
  Party Finder hero color; the coming-soon route table gained icon pins).
- `flutter test` (full) — **1838 pass / 0 failures** (baseline 1833 → +5,
  zero regressions).
- `flutter test integration_test/subscriptions_flow_test.dart -d iphone` —
  **2/2**; `qr_flow_test.dart` — **2/2** (device: iPhone wireless iOS 26.5.2).

## Decisions made and why

- **AppBar titles = theme default, not Playfair:** the titles are feature
  names ('Evento', 'QR', 'Fotos'…) — utility titles per the briefing; the
  brand fancy treatment is spent on 'Próximamente' (done). Matches the
  app-wide convention (42/42 AppBars are theme-styled).
- **Party Finder is the only faint-pink hero icon:** §5.7 names it as the
  hero-topic example; everything else stays `border #333333` (P2 minimalism,
  accent budget §2.5). One §5.7 moment, not twelve.
- **Icons live at both call sites (router + `_defaultFallback`), not a shared
  catalog:** the title/description duplication between the two files is
  pre-existing I-69 wiring; icons follow the same pattern and both sides are
  test-pinned (the router table pins the no-explicit-fallback flags'
  `_defaultFallback` icons too — subscriptions/partyFinder — keeping the
  copies in sync by test).
- **`Icons.event_note` over `Icons.add_event`:** `add_event` does not exist
  in the SDK's icon set (RED compile error); `event_note` (calendar entry)
  is the closest "create event" metaphor.
- **`notifications` excluded from the dark-fallback icon loop:** the flag is
  LIVE by default → the loop's gate renders the child, not the fallback; its
  fallback copy+icon are pinned by the kill-switch test instead.

## MISTAKE

- **`Icons.add_event` compile failure (caught by RED):** mission-suggested
  icon doesn't exist in this SDK's `material/icons.dart`. Verified the icon
  surface with a grep over the SDK before choosing `event_note`. Lesson:
  grep the SDK icons before pinning a glyph in a test.
- **`isNullOrEmpty` matcher undefined:** `package:matcher`'s matcher isn't
  re-exported by `flutter_test` in this SDK — switched to `isNull` (the
  AppBar title Text has no inline style, which is the actual contract).
- **Test-loop flag semantics error (self-caught):** adding `notifications`
  (LIVE default) to the dark-fallback title/icon loop failed with "Found 0
  widgets with text Notificaciones" — the gate renders the child when the
  flag is on. The kill-switch test (flag flipped dark) is the correct home
  for the notifications fallback pins.

## Issues found / handoffs

- **Pre-existing (fixed, coordinated):** `integration_test/subscriptions_flow_test.dart`
  still asserted `find.text('Actual')` — U-05's §3.3 uppercase badge
  rendering ('ACTUAL') landed in `test/features/subscriptions/paywall_test.dart`
  but the integration mirror was missed; the on-device run failed red on
  that line before my icon pin was ever reached. Fixed (1 string) since I
  held the lock and the file must stay green for the icon pin to validate.
  Reported for U-25's review + the U-05 log's fallout list.
- **Briefing discrepancy (reported, not changed):** the mission brief says
  qr/scanner are "live — verify no VComingSoonScreen remains". Actual state:
  `AppFeatureFlag.qr` defaults **false** (I-49 contract + `kDefaultFlagStates`
  pin) so /qr and /scanner correctly show the coming-soon fallback in the
  default build — NOT leftovers. Flipping the flag live is I-57/I-78 release
  territory, out of scope for a restyle agent.
- **U-27/U-28:** the icon-map assertions live in `test/router/` +
  `test/core/` + `test/widgets/` — extend in the review passes if a route is
  added (e.g. the real EventsScreen swap on `mainEvents` must keep its icon).
- **U-30 (doc finalization):** §5.7's "faint glowPink α0.5 hero-topic"
  example is now implemented exactly (Party Finder) — the doc wording
  matches reality, no change needed.

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §2.4/§2.5/§3.2/§3.3/§5.7 (read in
  full — the contract).
- Flutter SDK (read-only, 3.44.1): `packages/flutter/lib/src/material/icons.dart`
  (icon existence check — `add_event` absent), `AppBar`/`DefaultTextStyle`
  title-resolution semantics.
- U-05/U-06 daily logs + handoffs (§5.7 widget state, VGlowText wiring),
  I-49/I-69 logs (flag contract + gating), U-08 log (the format-churn MISTAKE
  precedent — `git diff -w` verification).
