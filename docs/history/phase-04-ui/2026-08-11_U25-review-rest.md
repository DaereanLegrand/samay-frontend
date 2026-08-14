# U-25 — UI review pass: feed/shell/coming-soon + the remaining feature screens (DISCO §2/§3/§5/§6/§7 conformance checklist + fixes + flags) (2026-08-11)

**Agent:** U-25 | **Phase:** 04-ui (4.4) — review passes (U-23..U-25) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §2/§3/§4/§5/§6/§7 (read in full — THE
CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md` (read in
full), the U-08/U-12/U-17/U-18/U-21/U-22/U-23/U-24 daily logs + their handoff
tables (U-22's remaining `VLoadingView` sites in shards/cosmetics/photos/
party_finder/minigames; U-24's `VCountBadge` sharp check; U-21's qr_scanner
`_cameraError` review note; U-23's review-pass pattern), AGENTS.md,
`docs/to-fix/TODO.md`. Baseline before edits: `dart analyze` **0 issues**; full
`flutter test` **1993/1993** (U-24 checkpoint).

## The per-screen checklist (fresh-eyes walk, doc §2/§3/§4/§5/§6/§7)

Method: every screen in scope read against the doc — colors/tokens (no raw
hues, §2), typography roles (§3.2/§3.3), spacing/radius/elevation (§4), glow
discipline (≤1 breathing element, ≤1 glow CTA, accent budget §2.5), state
views (§5.8/§5.9), reduced motion (§6.2/§7.5), responsive/scroll-safety (§7.3).

| # | Screen | Checklist verdict | Notes |
|---|--------|-------------------|-------|
| S1 | `main_shell.dart` | **PASS** (verify-only) | R18 pending badge (VCountBadge — **sharp since U-24 FIX 5, now pinned** FIX 6); R19 `VTabFade` (150ms, reduced-motion static); activeIcon filled/outlined pair; tab order pinned. |
| S2 | `feed_screen.dart` | **PASS** | U-08/U-18/U-22 state verified: breathing `displaySmall` hero, 2 `VDiscoDivider` slivers, featured glowPink border + `VBadge.accent`, event cards `VCard` + `VBadge`, `VSkeletonDetail` first load with `skipLoadingOnRefresh`. |
| S3 | `v_coming_soon.dart` + 12 route instantiations | **PASS** | U-12 state verified: icon `xxl` `border` (Party Finder faint-pink hero), Playfair italic 32 glow-soft breathing "Próximamente", mutedStrong description, outlined back CTA, AppBar title theme-styled. |
| E1 | `create_event_screen` | **PASS after FIXES 2+3` | **FIX 2:** the U-21-flagged cover slot `Colors.grey[900]`/`grey[700]`/`grey` — the last raw-grey surface in the feature screens — → the create_group token treatment (`surfaceAlt` + `border` ring + `muted` icon + `mutedStrong` label). **FIX 3:** the date-row + group-selector inline `labelStyle` `AppColors.muted` → `mutedStrong` (§5.2 label rule; the dropdown hint stays `muted` — §2.4 placeholder exemption). **FLAGS F2/F6/F7:** CTA is `VButton.emphasized` (white) vs group-create's glowAccent-filled; camera icon 40px off-scale; type/join labels uppercase via l10n. |
| E2 | `event_detail_screen` | **PASS after FIX 1** | **FIX 1:** loading → `VSkeletonDetail(rows: 1)` (U-22 handoff; three stacked fetches — the heaviest events screen; mirrors U-24's group_detail call). Title `headlineLarge` — the §3.2 28px Playfair event-title role, glow-soft **baked into the theme role** (verified `app_typography.dart:231` — no gap). Status/type badges are hand-rolled but color-legal (§2.5 rule 5: labels carry the state). **FLAGS F1/F3/F5:** hand-rolled badge twins vs §5.5 VBadge; 18px `_InfoRow`/`TextButton.icon` icons off the §4.4 scale; `substring(0,1)` empty-string edge. |
| E3 | `event_edit_screen` | **PASS** (1 decision) | Loading keeps `VLoadingView`: a form pre-check (seeds the controllers from one fetch) — skeleton geometry is card/list shaped, not form. `DropdownButtonFormField` labelStyle already `mutedStrong`. |
| E4 | `event_invite_route` | **PASS** (1 decision) | Resolution gate keeps `VLoadingView`: a single light fetch that resolves to a redirect. |
| C1 | `chat_screen` | **PASS after FIX 5` | **FIX 5:** `_MessageBubble` `BorderRadius.circular(16)` → sharp (§4.2's radius-0 list is exhaustive; the bubble was the pre-disco Material default — the white border + left/right alignment carry the bubble signal §7.2); same screen, the undecryptable-message text `muted` → `mutedStrong` (§2.4). Loading keeps `VLoadingView` (thread bubbles don't map to row skeletons). Composer `VInput` + emphasized send. |
| Q1 | `qr_scanner_screen` | **PASS after FIX 4` | **FIX 4 (U-21 handoff):** the mobile_scanner `errorBuilder` hand-rolled title+button column → the canonical §5.9 `VEmptyView` (identical panel to the unavailable/denied faces), exposed as `@visibleForTesting static QrScannerScreen.cameraErrorPanel` (the plugin's errorBuilder only fires on a device — the widget test mounts the panel directly). Permission flow + retryable scan errors unchanged. |
| Q2 | `attendance_qr_screen` | **PASS** (1 flag) | `_MessageState` is a pixel-identical §5.9 twin (icon 48 `border`, headlineSmall, mutedStrong caption, outlined CTA) — **FLAG F4:** VEmptyView can't replace it (action is a passed-in widget that can be disabled mid-rotation; VEmptyView's CTA is label+callback only). Countdown ring hairline + glowPink arc, sharp. |
| P1 | `photo_gallery_screen` | **PASS** (1 decision) | Loading keeps `VLoadingView`: square photo tiles have no close-fit skeleton without a new widget (VSkeletonGrid's cover+lines cards would mislead). Upload spinner allowlisted (unchanged). |
| N1 | `notification_center_screen` | **PASS** | U-22 skeleton verified; tile unread = surface fill + glowPink icon + dot + w600 title (multiple signals, §2.5 rule 5); hairline separators; mark-all-read action. |
| L1 | `shard_ledger_screen` | **PASS after FIX 1` | **FIX 1:** loading → `VSkeletonList()` + `skipLoadingOnRefresh` (list-y first load; U-22 handoff named it). Gold `VShardIcon` delta chips, hairline rows, `border` balance card — all token-clean. |
| K1 | `cosmetics_shop_screen` | **PASS after FIX 1` | **FIX 1:** loading → `VSkeletonGrid(rows: 2, columns: 2)` — **deliberate deviation from U-22's "VSkeletonList" suggestion:** the shop renders a 2-column card grid, and VSkeletonGrid is the §5.3-card shape. Locked cards surfaceAlt, equipped white border, VBadge 'ADQUIRIDO'. |
| M1 | `minigames_screen` | **PASS** (1 decision) | Loading keeps `VLoadingView`: the game picker is already on screen when the sessions list loads — U-22's "skeleton only when there is nothing on screen" contract fails by design. |
| F1 | `party_finder_screen` | **PASS after FIX 1` | **FIX 1:** matches loading → `VSkeletonList()` (avatar + @username + count lines = exact VSkeletonList geometry). Opt-in gate keeps `VLoadingView` (quick local pre-check, not a heavy frame). |
| Y1 | `paywall_screen` | **PASS** | app_config gate keeps `VLoadingView` (light config fetch); tier cards `surface` + hairline with `discoViolet` VIP top/bottom border (§2.3 usage, always paired with text); 'ACTUAL' VBadge; disabled purchase buttons drop to `muted` (§5.1). |

**Cross-cutting (scope-wide):** colors — the only raw `Colors.*` sites in the
scope were create_event's cover slot (FIX 2) — zero remain; typography — every
Playfair site is a sanctioned §3.2 role (event_detail title verified as the
theme-baked glow-soft `headlineLarge`); glow — ≤1 breathing element (feed,
coming-soon) and ≤1 glow CTA per screen; radius — the chat bubble was the
scope's only non-sharp box (FIX 5); state views — every screen-level loading
state is either a named skeleton or the §5.8 standard `VLoadingView`, and the
raw-grey cover slot is gone; reduced motion — unchanged surfaces all gate via
VShimmer/VBreathingGlow/VTabFade.

## Fixes applied (small + safe, TDD-pinned)

### FIX 1 — U-22's remaining VLoadingView sites: evaluated per screen (4 skeletons + 8 kept)

The mission's "skeleton vs spinner" call, per §5.8 (skeletons upgrade the
heavy nothing-on-screen frames; the white spinner remains the standard):

| Site | Verdict | Why |
|---|---|---|
| `event_detail` gate | **skeleton** — `VSkeletonDetail(rows: 1)` | U-22's handoff named `event_detail → VSkeletonDetail`; three stacked fetches (detail + promotores + invite) = the heaviest events screen; `rows: 1` cover card matches the hero geometry (same call U-24 made on group_detail). |
| `shard_ledger` gate | **skeleton** — `VSkeletonList()` | List-y rows, nothing on screen; U-22's handoff named it. `skipLoadingOnRefresh: true` added — pull-to-refresh keeps the list visible (the U-22 contract; the screen had a plain `when` before). |
| `cosmetics` catalog gate | **skeleton** — `VSkeletonGrid(rows: 2, columns: 2)` | Grid shop, nothing on screen; deviation from U-22's "VSkeletonList" suggestion documented (card grid ≠ rows). |
| `party_finder` matches gate | **skeleton** — `VSkeletonList()` | Avatar + 2-line rows = exact VSkeletonList geometry; U-22's handoff named it. |
| `party_finder` opt-in gate | **kept `VLoadingView`** | Quick local pre-check (toggle state), not a heavy frame. |
| `minigames` sessions | **kept `VLoadingView`** | The game picker is already rendered above — the screen is never a blank first frame (U-22's "nothing on screen" contract). |
| `photo_gallery` | **kept `VLoadingView`** | Square photo tiles have no close-fit skeleton; VSkeletonGrid's card-with-lines would mislead; a square-tile skeleton is a new widget (U-22's scope). |
| `chat`, `event_edit`, `event_invite_route`, `attendance_qr`, `paywall`, `qr_scanner` | **kept `VLoadingView`** | Bubbles/form/pre-check/gate/quick-fetch states — no heavy list geometry to mirror. |

### FIX 2 — create_event cover slot: raw greys → tokens (1 screen, 4 sites)

The U-21-flagged pre-existing (`create_event_screen.dart:338-359` —
"cover-picker placeholders use inline icon+text … still `Colors.grey[900]`/
`muted` mixes"). The create_group precedent (U-11, G6-verified) is the
canonical treatment, now applied byte-identically: fill `AppColors.surfaceAlt`
(§5.8 skeleton-base), ring `AppColors.border` (§2.1 interactive outline),
camera icon `AppColors.muted`, label `AppColors.mutedStrong` (§2.4). This was
the **last raw-grey surface in the feature screens**.

### FIX 3 — create_event inline label colors: `muted` → `mutedStrong` (1 screen, 2 sites)

§5.2: "Labels `labelStyle`: `mutedStrong #999999` (fix from `#666666` — the
current label fails 1.4.3 at normal size)". The date-row (`Inicio`/`Fin`) and
group-selector InputDecorators passed `labelStyle: AppColors.muted` inline —
now `mutedStrong`, matching the theme's `inputDecorationTheme` and the edit
screen's DropdownButtonFormField. The dropdown **hint** stays `muted`
(§2.4 placeholder exemption — re-declared by the field label).

### FIX 4 — U-21's qr_scanner camera-error handoff (1 screen)

U-21's handoff: "`qr_scanner_screen.dart` `_cameraError` path (mobile_scanner
`errorBuilder`) predates the sweep's permission panels — consistent enough,
flagged for U-25 review." Review verdict: inconsistent — the runtime camera
failure rendered a hand-rolled `Center(Column(title + VButton))` while the
permission failures render the canonical §5.9 `VEmptyView`. Now the
errorBuilder renders the same `VEmptyView` (icon `no_photography_outlined`,
title + body + outlined retry) the `unavailable` face uses — three camera-
failure faces, one canonical widget. Exposed as `@visibleForTesting static
QrScannerScreen.cameraErrorPanel(l10n, onRetry)` because the plugin's
errorBuilder only fires on a device; the widget test mounts the panel
directly.

### FIX 5 — chat bubble radius + §2.4 text (1 screen, 2 sites)

§4.2: "Every UI component radius = 0 … Exceptions (only these): avatars,
dots, spinners." `_MessageBubble` shipped `BorderRadius.circular(16)` (the
I-56 Material default — chat's visual restyle was U-12's "later pass" that
never came). Now sharp; the white 1px border + left/right alignment carry the
bubble signal (§7.2 boundary rule). Same screen: the undecryptable-message
text used `AppColors.muted` (#666, 3.66:1) for informational text — §2.4
violation → `mutedStrong` (7.37:1). The U-24 VCountBadge-radius precedent
applies ("geometry-only, no behavior change").

### FIX 6 — verify-only pin: the shell VCountBadge sharpness (1 test)

U-24's handoff asked the shell review to "confirm the counts UI still reads
well at radius-0". Verified: `VCountBadge` is `AppRadius.sharp` since U-24
FIX 5 and the shell badge (R18) inherits it. Pinned with a
`BorderRadius.zero` assertion on the badge container inside the existing R18
test — **green-at-RED by design** (a no-change pin, U-17's R21 precedent).

## Flags (need product input — not fixed)

- **F1** — `event_detail` hand-rolls `_TypeBadge`/`_StatusBadge` instead of
  the §5.5 VBadge vocabulary. The rendering is color-legal (statuses: white
  fill live, glowPink cancelled, surfaceAlt ended/draft — all with label
  text, §2.5 rule 5) and the feed already migrated its twins (U-08). A
  migration would change borders (#333333 fill vs white border) + uppercase —
  a component-reuse decision for U-30, not a review-pass fix.
- **F2** — `create_event`'s primary CTA is `VButton.emphasized` (white) while
  `create_group` (U-11) uses glowAccent-filled — the create-family
  inconsistency (same family as U-23's F1 on signup). Product call.
- **F3** — `event_detail` `_InfoRow` + the 'Ver grupo' `TextButton.icon` use
  `size: 18` icons — off the §4.4 scale (between `sm 16` and `md 20`; the
  U-24 F5 camera-40px family). U-30 to decide whether the scale grows an
  18px token.
- **F4** — `attendance_qr` `_MessageState` is a pixel-identical §5.9 twin
  that VEmptyView cannot replace: its `action` is a passed-in widget (a
  `VButton` that renders disabled while `_rotating`), while VEmptyView's CTA
  is label+callback only. Component-reuse call for U-30 (an
  action-as-widget variant or a disabled-CTA option).
- **F5** — `_PromotorAvatar` (event_detail) and `_MatchAvatar`
  (party_finder) do `username.substring(0, 1)` with only a null guard —
  an empty (non-null) string would `RangeError`. Same latent edge as U-24's
  F3; unreachable today (providers produce non-empty usernames). U-26
  robustness note.
- **F6** — `create_event` cover camera icon `size: 40` is off the §4.4 scale
  (same as create_group's — U-24 F5; keep the pair consistent either way).
- **F7** — event type/join-mode labels render uppercase ('JUERGA', 'TONO',
  'CASUAL') because the l10n keys are uppercase (feed migrated to VBadge
  uppercase in U-08). Content/copy-pass call, not a UI-review fix.

## Files modified (lock evidence — 17 locks, all U-25, all released)

| File | Change | Lock |
|---|---|---|
| `lib/features/events/screens/event_detail_screen.dart` | FIX 1 (skeleton) | acquire → release (U-25) |
| `lib/features/shards/screens/shard_ledger_screen.dart` | FIX 1 (skeleton + skipLoadingOnRefresh) | acquire → release (U-25) |
| `lib/features/cosmetics/screens/cosmetics_shop_screen.dart` | FIX 1 (grid skeleton) | acquire → release (U-25) |
| `lib/features/party_finder/screens/party_finder_screen.dart` | FIX 1 (matches skeleton) | acquire → release (U-25) |
| `lib/features/events/screens/create_event_screen.dart` | FIX 2 (grey→tokens) + FIX 3 (labels) | acquire → release (U-25) |
| `lib/features/qr/screens/qr_scanner_screen.dart` | FIX 4 (cameraErrorPanel) | acquire → release (U-25) |
| `lib/features/chat/screens/chat_screen.dart` | FIX 5 (bubble radius + §2.4 text) | acquire → release (U-25) |
| `test/features/events/event_detail_test.dart` | +1 skeleton first-frame pin | acquire → release (U-25) |
| `test/features/events/create_event_test.dart` | +2 pins (cover tokens, label colors) | acquire → release (U-25) |
| `test/features/shards/shard_ledger_screen_test.dart` | +1 skeleton pin (gated fake) | acquire → release (U-25) |
| `test/features/cosmetics/cosmetics_shop_screen_test.dart` | +1 skeleton pin (gated fake) | acquire → release (U-25) |
| `test/features/party_finder/party_finder_screen_test.dart` | +1 skeleton pin (gated notifier) | acquire → release (U-25) |
| `test/features/qr/qr_scanner_screen_test.dart` | +1 cameraErrorPanel pin | acquire → release (U-25) |
| `test/features/chat/chat_screen_test.dart` | +2 pins (bubble sharp, §2.4 text) | acquire → release (U-25) |
| `test/router/main_shell_test.dart` | FIX 6 (badge radius pin in R18) | acquire → release (U-25) |
| `test/meta/conventions_test.dart` | U-21 spinner allowlist `qr_scanner_screen.dart:373 → :379` (line drift from FIX 4; I-48/U-21's file — lock-coordinated) | acquire → release (U-25) |
| `docs/to-fix/TODO.md` | U-25 workstream block | acquire → release (U-25) |
| `docs/history/phase-04-ui/2026-08-11_U25-review-rest.md` | this log | created under its lock → release |

## Commands run (reproducibility)

```bash
export AGENT_NAME=U-25
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
tools/agent_lock.sh acquire <17 paths> --owner U-25        # all held (see table)
# RED: new pins written against the pre-fix tree — 9 failures
#   (event_detail + shard_ledger + cosmetics + party_finder skeletons,
#    create_event grey+labels, qr cameraErrorPanel, chat bubble+text)
flutter test <8 touched test files>                        # 9 RED
# GREEN: the 7 lib edits
flutter test <8 touched test files>                        # iterate:
#   MISTAKE: 3 gated tests hung on pumpAndSettle (shimmer never settles) →
#     bounded pumps (the U-22 feed-test pattern);
#   MISTAKE: 'Agregar portada' literal wrong → 'Agregar foto de portada'
#     (l10n groupsAddCover); MISTAKE: label Text style is null (applied via
#     AnimatedDefaultTextStyle) → assert InputDecorator.decoration.labelStyle;
#   MISTAKE: cameraErrorPanel landed in the private state class →
#     moved to the public QrScannerScreen; the qr test's literal → ARB copy
#   → 124/124 GREEN
dart analyze                                               # 1 unused import → fixed
flutter test test/features/ test/router/ test/widgets/ \
  test/features/responsive_test.dart                       # 928/928
flutter test                                               # 2001/2001 (1993 + 8 pins;
#   the one regression — the U-21 spinner-allowlist line drift
#   qr_scanner_screen.dart:373→379 from FIX 4 — was caught by the
#   conventions guard itself, fixed, suite re-run)
flutter test test/meta/conventions_test.dart               # 27/27
tools/agent_lock.sh release <path> --owner U-25            # all 17 released
```

## Test results

- New pins: **+8** — `event_detail_test` +1 (first frame shows
  `VSkeletonDetail(rows: 1)` + no `VLoadingView`, skeleton gone after the
  gate resolves); `shard_ledger_screen_test` +1 (`VSkeletonList` first
  frame, gone after the gate); `cosmetics_shop_screen_test` +1
  (`VSkeletonGrid` first frame); `party_finder_screen_test` +1
  (`VSkeletonList` first frame while the matches fetch); `create_event_test`
  +2 (cover slot = `surfaceAlt`/`border`/`muted`/`mutedStrong`, never raw
  greys; date-row labels resolve `mutedStrong` through the
  InputDecorator's `labelStyle`); `qr_scanner_screen_test` +1
  (`cameraErrorPanel` renders the §5.9 `VEmptyView` with icon/title/body +
  working retry — pins the U-21 handoff directly since the plugin's
  errorBuilder is device-only); `chat_screen_test` +2 (both bubble
  decorations `BorderRadius.zero` with a border present; undecryptable text
  `mutedStrong`). Plus `main_shell_test` R18 gained the badge sharpness
  assertion (FIX 6, green-at-RED).
- Scope run (features + router + widgets + responsive) — **928/928**.
- `test/features/responsive_test.dart` — **18/18** unchanged (the §7.3 smoke
  must stay green — it did; the skeleton sites settle past their frames).
- `flutter test` (full) — **2001 pass / 0 failures** (U-24 baseline 1993,
  +8 = the new pins, zero regressions — the one suite RED, the U-21
  spinner-allowlist line drift `qr_scanner_screen.dart:373→379` from the
  FIX 4 panel insertion, was caught by the conventions guard itself and
  fixed).
- `dart analyze` — **0 issues**.

## MISTAKE blocks

- **MISTAKE (3 tests hung on pumpAndSettle, U-22's lesson repeated):** the
  gated first-frame tests (shard_ledger, cosmetics, party_finder) used the
  shared `_pumpLedger`/`_pumpShop`/`_pumpScreen` helpers whose
  `pumpAndSettle` never settles while the shimmer sweep runs behind the
  gate. Fixed with bounded pumps (`pumpWidget` + `pump()`) — the exact
  U-22 feed-test pattern I should have copied first.
- **MISTAKE (test literal wrong):** the create_event cover pin asserted
  'Agregar portada' — the real l10n key is 'Agregar **foto de** portada'
  (`groupsAddCover`). The no-element failure surfaced it.
- **MISTAKE (test seam wrong):** the date-row label pin read the label
  `Text`'s own `style` — null, because InputDecorator applies the label
  style through an `AnimatedDefaultTextStyle` parent. Asserted
  `InputDecorator.decoration.labelStyle` instead (the InputDecoration we
  pass).
- **MISTAKE (static landed in the wrong class):** `cameraErrorPanel` was
  inserted into `_QrScannerScreenState` (the private state class) — the
  test's `QrScannerScreen.cameraErrorPanel` failed to compile. Moved to the
  public widget class; the state method calls
  `QrScannerScreen.cameraErrorPanel(...)`.
- **MISTAKE (allowlist line drift, caught by the campaign's own guard):**
  the FIX 4 insertion moved the qr scanner scan-chip spinner
  `:373 → :379` — the U-21 conventions guard RED-flagged it in the FULL
  suite. Same class of slip as U-23/U-24; fixed the allowlist entry,
  re-ran — 27/27.

## Decisions made and why

- **Skeletons exactly where U-22's "nothing on screen" contract holds,**
  with the shape matching the screen's real geometry: event_detail →
  `VSkeletonDetail(rows: 1)` (hero card), shard_ledger → `VSkeletonList`
  (rows), party_finder → `VSkeletonList` (avatar rows), cosmetics →
  `VSkeletonGrid` (2-column card grid — the one deviation from U-22's
  suggestion, because the shop is a grid, not rows). Everything else keeps
  the §5.8 standard spinner with a documented reason. `skipLoadingOnRefresh:
  true` added on shard_ledger so pull-to-refresh keeps the list visible
  (the U-22 contract the screen was missing).
- **Raw greys are gone from the feature screens.** The create_event cover
  slot mirrored create_group's already-approved token treatment (FIX 2)
  instead of inventing new values — §8 rule 5 ("screens must not hardcode
  design values").
- **The camera-error panel is the same widget as the unavailable panel.**
  Three camera-failure faces (permission-denied, permission-unavailable,
  runtime-error) now render one canonical §5.9 view; the static
  `@visibleForTesting` seam exists because mobile_scanner's `errorBuilder`
  is unreachable in widget tests.
- **Chat bubble sharpness is the doc, not a taste call:** §4.2's exception
  list is exhaustive and chat was never disco-restyled (its "U-12 later
  restyle" never happened — U-12 handled coming-soon routes only). The U-24
  VCountBadge precedent ("geometry-only, no behavior change") applies; the
  bubble signal survives via border + alignment (§7.2).
- **NOT fixed — the flags (F1..F7).** Each is a component-reuse/product
  call (F1, F2, F4, F7), an off-scale literal family (F3, F6), or a latent
  defensive-coding edge (F5). Review-pass discipline: flag, don't drift.

## Issues found / handoffs

- **U-26 (a11y audit):** all four new skeleton sites are gray `surfaceAlt`
  blocks (the already-audited class); the chat bubble text + create_event
  labels now resolve `mutedStrong` (7.37:1 AA — legal, previously §2.4
  violations); F5 (the `substring(0,1)` empty-string edges on
  event_detail's `_PromotorAvatar` + party_finder's `_MatchAvatar`) is the
  same latent edge as U-24's F3 — a robustness note.
- **U-30 (doc finalization):** (1) F1 — decide the event-detail badge
  vocabulary (hand-rolled twins vs VBadge migration); (2) F2 — the
  create-family CTA voice (create_group glowAccent vs create_event
  emphasized, and U-23 F1's signup variant); (3) F3/F6 — the 18px icon
  scale and the 40px camera icon (token or allowlist); (4) F4 — an
  action-as-widget or disabled-CTA variant for §5.9's VEmptyView (the
  attendance_qr `_MessageState` conversion); (5) §5.8 already has the
  skeleton lines — consider naming the four new consumer screens in it.
- **U-29 (integration smoke):** no flow-asserted text changed (the skeleton
  pins are first-frame only; all screens settle past them); the chat bubble
  shape and cover-slot tokens are not asserted by any flow.
- **U-27/U-28:** the new pins live in the per-feature test files
  (event_detail/create_event/shard_ledger/cosmetics/party_finder/qr/chat +
  the shell R18 test) — extend there.
- **Pre-existing, reported (not touched):** the F3/F5/F6 literal edges; the
  `_MessageState` twin (F4); `_getMemberLimit` '14' hardcode (I-46, still
  open); the feed 13px metadata pattern (U-08's U-19/U-26 handoff, still
  open).

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §2/§3/§4/§5/§6/§7 (read in full —
  the contract).
- U-08/U-12/U-17/U-18/U-21/U-22/U-23/U-24 daily logs + handoff tables (the
  skeleton names, the `_cameraError` review note, the VCountBadge sharp
  handoff, the create_group cover precedent, the pumpAndSettle + format-
  churn + allowlist-drift MISTAKE lessons).
- Flutter SDK (read-only, 3.44.1): `InputDecorator` label-style resolution
  (the test-seam lesson), `flutter_test` `pumpAndSettle` semantics.
- WCAG 2.2 contrast pairs via the doc's §2 tables (all contrast decisions
  in this pass reuse already-verified ratios).

## Change log

| Date | Change |
|---|---|
| 2026-08-11 | v1.0 authored by U-25 (review pass feed/shell/coming-soon + 14 feature screens; 18-screen checklist; FIX 1 skeleton handoff ×4 + FIX 2 grey→tokens + FIX 3 labels + FIX 4 camera-error + FIX 5 chat radius/text + FIX 6 verify pin; 7 product flags; 2001/2001 full suite). |
