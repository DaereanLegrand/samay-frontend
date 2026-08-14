# U-10 — Friends screens restyle: §5 avatar tiles, cyan presence dot, hairline rows, theme-owned actions + completed state views (2026-08-11)

**Agent:** U-10 | **Phase:** 04-ui (4.4) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §2.1/§2.4/§5.1/§5.5/§5.8/§5.9
(read in full — THE CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` +
`docs/process/FILE-OWNERSHIP.md` + `docs/process/DEVELOPMENT-WORKFLOW.md` (read in
full), U-01..U-09 daily logs + the U-01/U-04/U-05/U-09 handoffs (presence
dot → `statusOnline` alias; `VButton.outlined`/U-04 textButtonTheme;
`ProfileAvatar` for tiles; `VStateView` from I-74), the I-45/I-74 logs
(friends tests, state views), AGENTS.md. Baseline before edits: `dart analyze`
0 issues; full `flutter test` **1798/0** (U-09 checkpoint);
`test/features/friends_screens_test.dart` **15/15**.

## What was built

The 4 friends screens' disco restyle, exactly per the mission's handoffs.
**The FLOW is byte-identical**: every route, provider, l10n string, tap
target, debounce, accept/decline/unblock pipeline and snackbar path is
untouched — this pass changes *rendering* only (U-16 owns flow alignment).
TDD: `test/features/friends/restyle_test.dart` (17 ledger tests) written
first — RED against the pre-restyle tree (12 failed for exactly the missing
treatments; the 5 green pin the I-74 `VStateView`/`VEmptyView`/`VLoadingView`
states and the U-04 TabBar theme already in place), then GREEN.

### The visual-change ledger (screen → §5 ref → change → test update)

| Screen | §5 ref | Change (visual) | Test update |
|---|---|---|---|
| `friends_list_screen.dart` | §2.1/§4.2 (handoff 1) | Green presence dot → **`AppColors.statusOnline` (discoCyan)** — U-01's semantic alias; keeps the §5.5 8px size; dot is a non-text indicator, the username label is the nearby text signal (1.4.1/7.6) | `restyle_test` +1 (dot color == statusOnline, size 8) |
| `friends_list_screen.dart` | §2.1/§4.2 | Tile `CircleAvatar(grey[800])` → **`ProfileAvatar(size: AppSpacing.avatar 40)`** with 1-char initials + `avatar_url` pass-through (surfaceAlt fill + `border #333333` ring, U-09's widget) | `restyle_test` +1 (ProfileAvatar ×2, initials font == size×0.25 = 10, ring surfaceAlt/circle) |
| `friends_list_screen.dart` | §5 (name rows) | `ListView.builder` → **`ListView.separated`** with 1px hairline `Divider` separators (U-04 dividerTheme paints `#1A1A1A`) | `restyle_test` +1 (N−1 dividers, color via dividerTheme) |
| `friends_list_screen.dart` | §5.9 (verify + complete) | Empty + loading were already `VEmptyView`/`VLoadingView` (I-74); **filter-no-results `Center(Text)` → `VEmptyView(icon: search_off)`** (the one gap) | `restyle_test` +2 (VEmptyView for no-friends; +1 NEW filter-empty) |
| `search_screen.dart` | §2.1/§4.2 (handoff 2) | Result tile `CircleAvatar(grey[800])` → **`ProfileAvatar(size: 40)`** initials + `avatar_url` pass-through | `restyle_test` +1 (ProfileAvatar ×2 + 'A' initial) |
| `search_screen.dart` | §5.1 (handoff 2) | 'Agregar' `TextButton` → **compact `SizedBox(width: 104)` + `VButton.outlined`** (§5.1 white 1px border treatment, kept inside the tile trailing; status labels 'Amigos'/'Solicitado'/'Bloqueado' stay disabled `TextButton`s → U-04 theme `muted` label) | `restyle_test` +1 (VButton present, variant outlined, 104 wrapper, inside ListTile; 'Solicitado' TextButton survives) |
| `search_screen.dart` | §5 (name rows) | Results → **`ListView.separated`** hairline dividers | `restyle_test` +1 (divider count + hairline color) |
| `search_screen.dart` | §5.8/§5.9 (handoff 5) | Loading `Center(CircularProgressIndicator)` → **`VLoadingView`**; no-results `Padding(Text)` → **`VEmptyView(icon: person_search)`** (I-74 never covered search) | `restyle_test` +2 (VLoadingView pending; VEmptyView 'No se encontraron usuarios') |
| `requests_screen.dart` | §5.4 (handoff 3, verify-only) | The 3 TabBar tabs **already theme-owned** (U-04 `tabBarTheme`: white indicator + white label) — zero code change | `restyle_test` +1 (pins tabBarTheme indicator/label white) |
| `requests_screen.dart` | §5.1 (handoff 3, verify-only) | Accept/decline/cancel **already plain `TextButton`s** → render via the U-04 textButtonTheme (white label, sharp, α0.1 overlay) — zero code change | `restyle_test` +1 (pins resolved foregroundColor == white) |
| `requests_screen.dart` | §5 (name rows) | Requests + invites lists → **`ListView.separated`** hairline dividers | `restyle_test` +1 (2 received → 1 hairline divider) |
| `requests_screen.dart` | §5.9 (verify + complete) | Loading already `VLoadingView` (I-74); the three tab **empty `Center(Text)` → `VEmptyView`** (received `inbox_outlined` / sent `send_outlined` / invites `group_outlined` — §5.9 icon-in-`#333333` treatment) | `restyle_test` +2 (VEmptyView ×3 tabs; VLoadingView pending) |
| `blocked_users_screen.dart` | §5.1 (handoff 4, verify-only) | Unblock action **already a plain `TextButton`** → U-04 textButtonTheme — zero code change | `restyle_test` +1 (pins resolved foregroundColor == white) |
| `blocked_users_screen.dart` | §2.1/§4.2/§5 | Tile `CircleAvatar(grey[800])` → **`ProfileAvatar(size: 40)`**; list → **`ListView.separated`** hairline | `restyle_test` +1 (avatars ×2, divider, theme TextButton) |
| `blocked_users_screen.dart` | §5.9 (verify-only) | Full `VStateView` **already in place** (I-74) — no change | `restyle_test` +1 (VStateView + VEmptyView present) |
| `profile_avatar.dart` (U-09's file, coordinated) | §4.2 | Initials font hardcoded 24 → **`size × 0.25`** — profile-header 96px keeps 24px (byte-identical), tile 40px renders 10px (one widget serves both slots) | `restyle_test` +1 (10px on the 40px tile avatar; U-09's 96px → 24px assertion unchanged) |

**Zero-change contract:** all l10n strings, all routes, the search debounce
+ sanitizer, the accept/decline/cancel/unblock service calls + provider
invalidations, the `friendship_status` button-state matrix and every tap
target are byte-identical — pinned by the untouched
`test/features/friends_screens_test.dart` (15/15 green, zero diff). U-16 owns
flow alignment — nothing here alters flow.

## Files created / modified (lock evidence)

All 9 locks via `tools/agent_lock.sh acquire <path> --owner U-10`
(acquired 06:59Z, held for the whole edit, released after):

| File | Action | Lock evidence |
|---|---|---|
| `lib/features/friends/screens/friends_list_screen.dart` | modified (dot/avatar/separators/filter-empty) | acquire 9dd49eacc1ad2a69e2e1c631 → release |
| `lib/features/friends/screens/search_screen.dart` | modified (avatar/VButton/separators/state views) | acquire 1197bb06979b612401e962d1 → release |
| `lib/features/friends/screens/requests_screen.dart` | modified (separators/empties) | acquire 6915525e60108bd8fb4a38a4 → release |
| `lib/features/friends/screens/blocked_users_screen.dart` | modified (avatar/separators) | acquire 23585b58f04247e0ae1245f6 → release |
| `lib/features/profile/widgets/profile_avatar.dart` | modified (initial font scaling — **U-09's file**, lock coordinated, see report) | acquire 3d7e1092cd2da8109b9ec91a → release |
| `test/features/friends/restyle_test.dart` | **created** (17 ledger tests) | acquire e97f7273dcbed7b830ec69ad → release |
| `test/features/friends_screens_test.dart` | locked, **unmodified** (verification only — every existing assertion stayed green) | acquire dbe2c9c8d64c0252774cfe4e → release |
| `docs/to-fix/TODO.md` | modified (U-10 workstream block) | acquire b802f899fb97030c6d655fd5 → release |
| `docs/history/phase-04-ui/2026-08-11_U10-friends-restyle.md` | created (this log) | acquire d1852b1f6911cb629f474bd2 → release |

## Commands run (reproducibility)

```bash
export AGENT_NAME="U-10"
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
flutter test test/features/friends_screens_test.dart       # baseline 15/15
tools/agent_lock.sh acquire <9 files> --owner U-10         # all held (see table)
# RED: restyle_test.dart (17 tests against the pre-restyle tree)
flutter test test/features/friends/restyle_test.dart       # 5 pass / 12 fail = RED
#   (the 5 green pin I-74's VStateView/VEmptyView/VLoadingView + U-04's
#    tabBarTheme — the already-done parts of the handoff; the 12 fail for
#    exactly the missing treatments: avatar tiles, cyan dot, separators,
#    VButton action, completed state views, initial scaling)
# GREEN: the 4 screen edits + ProfileAvatar font scaling
flutter test test/features/friends/restyle_test.dart       # 17/17
flutter test test/features/friends_screens_test.dart \
  test/features/profile/restyle_test.dart                  # 30/30 (zero regressions)
dart analyze                                               # 6 infos → fixed
#   (unnecessary_underscores (_, __) → (_, _) ×5; local _requestsOverrides
#    → requestsOverrides)
dart analyze                                               # 0 issues
flutter test test/features/friends/ test/features/friends_screens_test.dart \
  test/features/profile/ test/widgets/                     # 220/220
flutter test                                               # FULL 1815/0 (baseline 1798 → +17)
git diff -w test/features/friends_screens_test.dart        # 0 lines — untouched
tools/agent_lock.sh release <path> --owner U-10            # all 9 released
```

## Test results

- `test/features/friends/restyle_test.dart` — **17/17** (new; RED-proven:
  the 12 failing assertions were exactly the missing treatments; the 5 green
  pin the pre-existing I-74 state views + U-04 TabBar theme).
- `test/features/friends_screens_test.dart` — **15/15 unchanged** (zero diff
  — flow/behavior byte-identical).
- `test/features/profile/restyle_test.dart` — **15/15 unchanged** (the
  ProfileAvatar scaling keeps the 96px → 24px assertion green).
- `flutter test test/features/friends/ test/features/friends_screens_test.dart
  test/features/profile/ test/widgets/` — **220/220**.
- `flutter test` (full) — **1815 pass / 0 failures** (U-09 baseline 1798/0,
  +17 = the ledger tests; zero regressions).
- `dart analyze` — **0 issues**.

## Decisions made and why

- **Presence dot = `AppColors.statusOnline`, not `discoCyan` directly:** the
  mission hands off the *alias* (U-01 made it exactly for this dot); the
  alias keeps the doc's §2 role → token resolution traceable. Size stays 8
  per §5.5. The dot keeps its icon-only form — the tile's `@username` label
  is the 1.4.1 companion signal, and §2.5 rule 5's "text label nearby" is
  satisfied by the row text.
- **'Agregar' = `VButton.outlined` in a 104px `SizedBox`, not a styled
  TextButton:** the mission offers both ("VButton.outlined small OR textButton
  theme — keep compact"). `VButton` is full-width by §5.1 spec, so the
  compact width is enforced by the wrapper (the design-system button keeps
  its §5.1 border/disabled/loading behavior). Status labels stay disabled
  TextButtons — U-04's theme renders them `muted` (exempt as inactive
  components), preserving the existing state matrix text exactly.
- **Avatar ring/border resolved by U-09's `ProfileAvatar` unchanged:** the
  mission's "ProfileAvatar initials" handoff points at U-09's widget as-is
  (surfaceAlt fill + `border #333333` ring + white initials — the §2.1
  avatar-ring token); only the initial *size* needed to differ per slot, so
  the font is now `size × 0.25` (96 → 24 byte-identical, 40 → 10) instead of
  adding call-site overrides.
- **Filter-empty is a `VEmptyView`, not text:** §5.9's empty treatment (xxl
  icon in `#333333` + headlineSmall title) is the system's voice; I-74 had
  already applied it to the no-friends case — the no-results case was the
  gap, now closed with `Icons.search_off`.
- **Search/requests empties keep their l10n titles:** `VEmptyView(title:)`
  renders the same pre-existing ARB strings ('No se encontraron usuarios',
  'Sin solicitudes recibidas', …) — zero text change, only the §5.9 chrome.
- **TabBar + action buttons verified, not re-written:** U-04's
  `tabBarTheme` (white indicator/label) and `textButtonTheme` (white
  labelLarge, sharp, α0.1 overlay) already produce the §5 treatment; the
  screens are now pinned to that ownership by tests rather than restyled
  inline.

## MISTAKE

- **No behavioral mistakes this pass** (the RED/GREEN delta was clean and
  both side-suites stayed green on the first full run). Two lint nits
  self-caught before the final run: `(_, __)` wildcards → `(_, _)` (the
  analyzer's `unnecessary_underscores` — Dart 3.7 wildcard syntax) and a
  local helper named `_requestsOverrides` (leading underscore on a local —
  `no_leading_underscores_for_local_identifiers`).
- Lesson repeated from U-09 (not a mistake here, but worth logging): M3
  `Divider` resolves `widget.color ?? dividerTheme.color` — asserted via the
  theme, never `ThemeData.dividerColor` (M2 fallback = white).

## Issues found / handoffs

- **U-30 (doc finalization):** `ProfileAvatar` is a *profile-feature* widget
  now consumed by the friends feature (cross-feature import
  `features/profile/widgets/profile_avatar.dart`) — §5 has no avatar
  component section beyond the §2.1 ring token; consider promoting
  `ProfileAvatar` to `lib/shared/widgets/` (and its §4.2 font-scaling rule
  `size × 0.25`) in the finalization pass.
- **U-16/U-15 (flow alignment):** nothing to align — rendering only, every
  route/label/tap byte-identical (pinned by the untouched
  `friends_screens_test`). The friends entry buttons in `my_groups_screen`
  were NOT touched (U-11 owns that file).
- **U-19/U-26 (responsive + a11y):** the tile `ProfileAvatar` initials at
  10px white w600 on `surfaceAlt` = 21:1 (AA); the cyan dot 13.65:1
  (non-text ≫ 3:1); hairline dividers are decorative (§7.2 — tile text
  carries the boundary); the fixed `SizedBox(width: 104)` action could
  ellipsize 'Agregar' at extreme text scales — `VButton` labels are
  `maxLines: 1` + ellipsis so it degrades safely.
- **U-18 (animations):** §6.3's live-dot pulse (1.5s α 0.6→1.0, disabled
  under reduced motion) is not applied to the friends-list presence dot —
  static dot per U-18's animation scope; it is a one-line wrap
  (`FadeTransition`/`AnimatedOpacity`) when U-18 lands.
- **U-29 (integration smoke):** there is no `friends_flow_test.dart`
  (ghost entries removed by I-78); consider a friends smoke case asserting
  the cyan dot + avatar tiles in the U-29 pass.
- **Pre-existing, not touched:** the friends/blocked tile subtitle
  duplicates the title (`@username` twice) — pre-existing content, U-16's
  flow scope; the search 'Agregar' tap and requests accept/decline still
  route through the seeded PostgREST harness exactly as before.

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §2.1/§2.4/§2.5/§4.2/§5.1/§5.4/§5.5/
  §5.8/§5.9/§7.2 (read in full — the contract).
- U-01 (semantic aliases — `statusOnline`), U-04 (tabBarTheme/textButtonTheme/
  dividerTheme), U-05 (VButton §5.1 spec), U-08 (hairline Divider + theme
  resolution lessons), U-09 (ProfileAvatar + M3 Divider MISTAKE), I-45
  (friends test harness), I-74 (state_views) daily logs.
- Flutter SDK source (read-only, 3.44.1): `material/divider.dart` M3 color
  precedence (from U-09's log), `material/tab_bar.dart` theme resolution
  (indicatorColor/labelColor fall back to tabBarTheme when null).
- WCAG 2.2 contrast pairs via the doc's §2 tables (cyan 13.65:1, initials
  21:1 on surfaceAlt).

## TODO.md workstream block

Added the U-10 block to `docs/to-fix/TODO.md` (locked, 2026-08-11) — the
friends restyle summary above, verification numbers (analyze 0, friends+profile
30/30, widgets 220/220, full 1815/0), locked-file list, and handoffs (U-30
ProfileAvatar promotion + font-scaling rule, U-16 nothing-to-align, U-18
live-dot pulse, U-19/U-26 10px-initials + 104px-action notes, U-29 friends
smoke suggestion).
