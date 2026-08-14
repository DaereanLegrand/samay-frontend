# U-24 — UI review pass: friends → groups (DISCO §2/§3/§5/§6/§7 conformance checklist + fixes + flags) (2026-08-11)

**Agent:** U-24 | **Phase:** 04-ui (4.4) — review passes (U-23..U-25) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §2/§3/§5/§6/§7 (read in full — THE
CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md` (read
in full), the U-10/U-11/U-16/U-19/U-21/U-22/U-23 daily logs + their handoff
tables (U-22's remaining `VLoadingView` sites in group_detail + the
`my_groups` `g['my_role'] as String` null-guard crash; U-19's `Wrap` fixes;
U-16's member-sheet surfaces; U-23's review-pass pattern), AGENTS.md,
`docs/to-fix/TODO.md`. Baseline before edits: `dart analyze` **0 issues**;
full `flutter test` **1988/0** (U-23 checkpoint); scoped friends+groups+
responsive run **84/84**.

## The per-screen checklist (fresh-eyes walk, doc §2/§3/§5/§6/§7)

Method: every screen in scope read against the doc — colors/tokens (no raw
hues, §2), typography roles (§3.2/§3.3), spacing/radius/elevation (§4), glow
discipline (≤1 breathing element, ≤1 glow CTA, accent budget §2.5), state
views (§5.8/§5.9), reduced motion (§6.2/§7.5), responsive/scroll-safety (§7.3).

| # | Screen | Checklist verdict | Notes |
|---|--------|-------------------|-------|
| F1 | `friends_list_screen` | **PASS after FIX 2** | `ProfileAvatar` + cyan 8px `VStatusDot` (U-18 pulse, reduced-motion static); hairline rows; `VRefreshable` empties (R13). **FIX 2:** the tile subtitle duplicated the title (`@username` twice — U-16's flagged double render) → removed; the row is now name-only (Juega's row voice). Loading `VLoadingView` kept (§5.8 standard — not a named skeleton site). |
| F2 | `search_screen` | **PASS** | §5.1 compact `VButton.outlined` action; R14 autofocus + min-chars hint; R15 mutual dialog; hairline rows. Fixed `SizedBox(width: 104)` degrades safely (U-10 note — `VButton` maxLines 1 + ellipsis). |
| F3 | `requests_screen` | **PASS** | R11 per-row spinners (allowlisted 16px white), R12 tab badges, R13 refresh incl. empties; `VCountBadge` **now sharp** (FIX 5). |
| F4 | `blocked_users_screen` | **PASS after FIX 2** | Same double-render as F1 → subtitle removed (U-16 flagged it on both surfaces); `VStateView` + unblock TextButton theme-owned; `VRefreshable` empty. |
| G1 | `my_groups_screen` | **PASS after FIX 1** | U-22 skeleton on first load; gold shards + RankBadge + role `VBadge`; U-19 `Wrap`s; R12 Solicitudes badge. **FIX 1:** the U-22-reported `g['my_role'] as String` null-cast crash — rows missing `my_role` now render the member default (no badge) instead of a `TypeError`. |
| G2 | `group_detail_screen` | **PASS after FIXES 3+4** | §3.2 Playfair hero + glow-soft; frozen banner `errorFill` (5.87:1); inline leave `AppColors.error` (R16); glowAccent-filled Donar + 2 outlined (≤1 glow CTA); U-19 bounded-scroll header + `Wrap`s. **FIX 3:** the three stacked `VLoadingView` gates (the feature's heaviest screen) → `VSkeletonDetail(rows: 1)` (U-22 handoff). **FIX 4:** members-tab `_MemberTile`/`_ContributorTile` initials now `.toUpperCase()` — the standalone members screen + the sheet header already did; the tab was the outlier. |
| G3 | `group_members_screen` | **PASS** | Admin-gated rows + R17 sheet wiring consistent with the detail tab (`_canAct` = `isAdmin && != self && != promotor` on both surfaces); hairline rows; `VLoadingView` kept (single light fetch — not a named skeleton site). |
| G4 | `invite_screen` | **PASS after FIX 3** | Members gate `VLoadingView` kept (light pre-check — §5.8 standard). **FIX 3:** the search-results loading was a raw Material `LinearProgressIndicator` — not a sanctioned loading shape (§5.8 lists the white 24px spinner) → `VLoadingView`. |
| G5 | `donate_shards_screen` | **PASS** | No loading-state site exists (verified — the mission's "donate" list entry has nothing to swap): the CTA uses the §5.1 `VButton.loading` spinner; glowAccent-filled primary; `VInput` token label. |
| G6 | `create_group_screen` | **PASS** (1 flag) | Cover slot `surfaceAlt` + `border` ring (§5.8 base + §2.1); glowAccent-filled create; token `VInput`s. **FLAG F6:** the camera icon is `size: 40` — between the `xl 32` and `xxl 48` icon tokens (§4.4); deliberate-looking proportion, but it is an off-scale literal. |
| G7 | `leaderboard_screen` | **PASS** | U-22 skeleton; §3.2 podium Playfair + gold/silver/bronze RankBadge (U-05); §5.4 `VChip` tiers; hairline rows. |

**Cross-cutting (scope-wide):** colors — zero raw `Colors.*`/ad-hoc hexes in
scope; typography — every Playfair site is a sanctioned §3.2 role, Inter
elsewhere; glow — exactly one breathing element (friends-list dot) and ≤1 glow
CTA per screen; reduced motion — `VStatusDot`/`VShimmer` gate on
`MediaQuery.disableAnimationsOf`; responsive — all 11 screens pattern A/Wrap or
naturally scrolling, `test/features/responsive_test.dart` stays green; state
views — the only Material raw progress indicator in scope (invite's
`LinearProgressIndicator`) is gone; **radius — the one non-sharp element in the
scope's widget set, the `VCountBadge` pill (radius 9), is now sharp (FIX 5)**;
the `my_groups` tile subtitle hardcodes `fontSize: 12` (a micro-scale, same
voice as `RankBadge`'s 11px) — flagged, not changed (no visual delta).

## Fixes applied (small + safe, TDD-pinned)

### FIX 1 — the U-22 my_groups `my_role` null-cast crash (1 screen)

U-22's report: `my_groups_screen.dart:161` renders `g['my_role'] as String` for
non-`member` rows with no null guard — a row missing the key crashes the tile
with a `TypeError`. Now `final myRole = g['my_role'] as String?;` and the role
`VBadge` renders only when `myRole != null && myRole != 'member'` — the member
default renders no badge. Behavior for rows that DO carry the key is
byte-identical (the pinned U-11 ledger + U-22 skeleton tests stay green).

### FIX 2 — the friends `@username` double render (2 screens)

U-16 flagged (and U-10 confirmed) that the friends AND blocked tiles rendered
the handle twice — `title` and `subtitle` were both `@username`. The duplicate
subtitle is gone on both surfaces (the row is now the name-only voice Juega
uses). Test fallout: `friends_screens_test.dart` had two pins *asserting the
bug* (`findsNWidgets(2)` for `@ana`/`@lucas`) → flipped to `findsOneWidget`
with a reason comment; +2 new restyle pins assert the handle renders exactly
once on each surface.

### FIX 3 — U-22's remaining VLoadingView sites: evaluated per screen (3 screens)

The mission's "evaluate skeleton vs spinner" call, per §5.8 (skeletons are an
upgrade for heavy nothing-on-screen frames; the white spinner remains the
standard full-screen load):

| Site | Verdict | Why |
|---|---|---|
| `group_detail` × 3 gates | **skeleton** — `VSkeletonDetail(rows: 1)` | The heaviest screen in the feature (three stacked fetches: group + members + contributions); U-22's own handoff named `group_detail → VSkeletonDetail`. The `rows: 1` card (cover block + title/meta lines) is the closest existing skeleton to the hero geometry. All three gates swapped for consistency (each blanks the whole body today). |
| `invite` members gate | **kept `VLoadingView`** | A light pre-check ahead of search — nothing heavy on screen. |
| `invite` search results | **`VLoadingView` (was `LinearProgressIndicator`)** | Not a skeleton question: the Material linear bar is not a sanctioned loading shape at all (§5.8 = white 24px spinner); the same screen's other gates already used `VLoadingView`. |
| `donate` | **no site exists** | Verified — the CTA's in-button spinner is the §5.1 `VButton.loading` behavior. |

### FIX 4 — member-surface consistency: initials case on the detail tab (1 screen)

Both member surfaces (standalone `group_members_screen` + the detail members
tab) render admin-gated rows and open the same `showMemberActionsSheet`; the
standalone uppercased the avatar initials while the detail tab's
`_MemberTile`/`_ContributorTile` passed them raw — the sheet header and every
other avatar in the app uppercase. `.toUpperCase()` added (1-line each,
rendering-identical for the commonly-lowercase usernames' first letter is
exactly the point).

### FIX 5 — the VCountBadge pill radius — token drift (1 shared widget)

§4.2's radius-0 list names **badges** explicitly ("no rounded pastel" is the
brand's core ban) — but U-16's `VCountBadge` shipped with
`BorderRadius.circular(9)`, the only non-sharp badge in the app (U-05's
`VBadge`/`RankBadge` are sharp; `v_badge_test.dart` pins `BorderRadius.zero`).
→ `AppRadius.sharp`. Used by the requests tabs + my-groups Solicitudes entry
(R12) and the shell tab badge (U-17 R18) — zero behavior change, geometry-only.
Justification for touching a shared widget: FILE-OWNERSHIP lists no owner for
`v_count_badge.dart`, and the mission's "any token/style drift" item names it.

## Flags (need product input — not fixed)

- **F1** — `group_detail._getMemberLimit` hardcodes `'14'` (I-46's report,
  re-flagged by U-13/U-16/U-23): any group > 14 members renders `N / 14
  miembros` incorrectly. Data/economy scope — not a UI review fix.
- **F2** — the fixed `SizedBox(width: 104)` around the search 'Agregar'
  action (U-10 flagged): at extreme text scales the label ellipsizes safely
  (`VButton` maxLines 1) — acceptable, documenting rather than changing.
- **F3** — `_initials` helpers (friends list, search, blocked): a
  `username == ''` (empty string, non-null) crashes `substring(0, 1)` — only
  null is guarded. The providers always produce non-empty usernames (the
  blocked list even fabricates uid-based fallbacks), so it is a latent
  defensive-coding edge, not reachable today. U-26 may want a robustness note.
- **F4** — `my_groups` tile shard count renders `TextStyle(fontSize: 12)` — a
  hardcoded micro-scale (the same family as `RankBadge`'s 11px). No visual
  delta; U-30 may normalize the micro-scale voice.
- **F5** — `create_group` cover camera icon `size: 40` is off the §4.4 icon
  scale (between `xl 32` and `xxl 48`). Proportion is intentional-looking;
  U-30 to decide whether the scale grows a 40px token.
- **F6** — invites-tab role subtitle is plain lowercase text ('member') while
  every other role surface (badges, sheet header) is uppercase — left as
  U-11's byte-identical content (the flow ledgers pin it); a copy/voice
  decision for the content pass, not the UI review.

## Files modified (lock evidence — 12 locks, all U-24, all released)

| File | Change | Lock |
|---|---|---|
| `lib/features/groups/screens/my_groups_screen.dart` | FIX 1 (my_role null-guard) | acquire 240f544f1d85db856626cf61 → release |
| `lib/features/friends/screens/friends_list_screen.dart` | FIX 2 (subtitle removed) | acquire 9dd49eacc1ad2a69e2e1c631 → release |
| `lib/features/friends/screens/blocked_users_screen.dart` | FIX 2 (subtitle removed) | acquire 23585b58f04247e0ae1245f6 → release |
| `lib/features/groups/screens/group_detail_screen.dart` | FIX 3 (skeleton × 3 gates) + FIX 4 (initials case) | acquire 0394880233b04f0342d666a2 → release |
| `lib/features/groups/screens/invite_screen.dart` | FIX 3 (search loading → VLoadingView) | acquire 8b6d29305fe8f03424f8d43e → release |
| `lib/shared/widgets/v_count_badge.dart` | FIX 5 (sharp radius) | acquire e03c6090219a036ca15acc21 → release |
| `test/features/friends_screens_test.dart` | 2 pins flipped (`findsNWidgets(2)` → `findsOneWidget`, the old pins asserted the bug) | acquire dbe2c9c8d64c0252774cfe4e → release |
| `test/features/friends/restyle_test.dart` | +2 pins (de-dup on both surfaces) | acquire e97f7273dcbed7b830ec69ad → release |
| `test/features/groups/restyle_test.dart` | +3 pins (my_role fallback, detail first-frame skeleton, invite search loading) | acquire 6dcc44e1c68e9749cf88b135 → release |
| `test/meta/conventions_test.dart` | U-21 spinner allowlist `invite_screen.dart:105 → :108` (I-48/U-21's file — lock-coordinated; line drift from `dart format` expanding the allowlisted SizedBox) | acquire → release |
| `docs/to-fix/TODO.md` | U-24 workstream block | acquire b802f899fb97030c6d655fd5 → release |
| `docs/history/phase-04-ui/2026-08-11_U24-review-friends-groups.md` | this log | acquire 102061c0071d20b396f7e40f → release |

## Commands run (reproducibility)

```bash
export AGENT_NAME=U-24
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
flutter test test/features/friends/ test/features/groups/ \
  test/features/responsive_test.dart                       # 84/84 baseline
tools/agent_lock.sh acquire <11 paths> --owner U-24        # all held
# (test edits + lib edits per fix)
dart format <9 changed files>                              # 7 changed
flutter test test/features/friends/ test/features/groups/ \
  test/features/friends_screens_test.dart \
  test/features/groups_screens_test.dart \
  test/features/responsive_test.dart                       # 134/134
dart analyze                                               # 0 issues
flutter test                                               # 1993/1993
flutter test test/meta/conventions_test.dart               # 27/27 (after the
#   allowlist line-drift fix; the guard RED-flagged invite_screen.dart:105→108)
tools/agent_lock.sh release <path> --owner U-24            # all 12 released
```

## Test results

- New pins: **+5** — `test/features/friends/restyle_test.dart` +2 (the handle
  renders exactly once on the friends list and the blocked list), `test/
  features/groups/restyle_test.dart` +3 (my_groups row **without** `my_role`
  renders with no crash/no badge (the guard's pre-fix crash is independently
  documented in U-22's MISTAKE block — the same `TypeError` the U-22 loading
  fixture hit); group_detail first frame shows `VSkeletonDetail` + no
  `VLoadingView`, skeleton gone after the gate resolves; invite search loading
  shows `VLoadingView` and no `LinearProgressIndicator`).
- Updated pins: `test/features/friends_screens_test.dart` ×2 — the old
  `findsNWidgets(2)` assertions *pinned the bug*; flipped to `findsOneWidget`.
- Scope run (friends + groups + friends_screens + groups_screens +
  responsive) — **134/134** (baseline 84 + 16 + 34; +5 new).
- `test/features/responsive_test.dart` — **18/18** unchanged (the §7.3 smoke
  must stay green — it did; the group_detail fixture settles past the
  skeleton frame).
- `flutter test` (full) — **1993 pass / 0 failures** (U-23 baseline 1988,
  +5 = the new pins, zero regressions — the one suite RED, the U-21
  spinner-allowlist line drift `invite_screen.dart:105→108` from `dart
  format`, was caught by the conventions guard itself and fixed).
- `dart analyze` — **0 issues**.

## MISTAKE blocks

- **MISTAKE (allowlist line drift, caught by the campaign's own guard):** the
  first full-suite run RED-flagged `invite_screen.dart:108` — `dart format`
  expanded the allowlisted 20px AppBar send spinner's `SizedBox` onto five
  lines, drifting the pin `:105 → :108`. Same class of slip as U-23's
  (`edit_profile_screen.dart:200→202`); the guard proved its worth again.
  Fixed the allowlist entry with a comment, re-ran — 27/27.
- **MISTAKE (compile-RED at first scoped run):** the new group-detail skeleton
  pin referenced `VSkeletonDetail`/`VLoadingView` without importing
  `skeletons.dart`/`state_views.dart` in `test/features/groups/restyle_test
  .dart` (the friends file's compile failure was the shared-compiler cascade).
  Added the imports, re-ran.
- **MISTAKE (edit target wrong file, self-caught):** the invites-row role-case
  micro-edit was aimed at `invite_screen.dart` but the invites list lives in
  `requests_screen.dart` (the requests screen's invites tab) — the edit failed
  cleanly (oldString not found) and the change was DROPPED, not relocated:
  after re-checking, the lowercase role subtitle is U-11's byte-identical
  content under the flow ledgers — flagged (F6) instead of changed.

## Decisions made and why

- **Skeleton only where the screen is genuinely heavy, per U-22's own
  contract** ("skeletons only when there is nothing on screen"): group_detail
  (three stacked fetches) is the only remaining skeleton candidate in the
  named sites; invite's members gate and friends/blocked/group_members keep
  the §5.8 standard spinner. `VSkeletonDetail(rows: 1)` over a new
  group-hero-specific skeleton — no new widget without a new-screen need
  (skeletons.dart is U-22's; the mission's lock list excludes it).
- **Name-only friend rows**: the double-render fix removes the redundant
  subtitle rather than inventing new copy — Juega's own row is name-only
  (U-13 report), so this is the flow-aligned voice, and no l10n key churn.
- **Sharp VCountBadge**: §4.2 is unambiguous ("badges — all sharp"); the pill
  was the scope's only non-sharp box. Geometry-only change; the shell badge
  (U-17) and the R12 badges inherit it.
- **NOT fixed — the flags (F1..F6).** Each is either a data/economy call
  (F1), an acknowledged safe degradation (F2), a latent edge (F3), a
  zero-delta micro-scale (F4/F5), or a byte-identical content voice (F6).
  Review-pass discipline: flag, don't drift.

## Issues found / handoffs

- **U-25 (feed/shell review):** `VCountBadge` is now sharp — the shell tab
  badge (U-17 R18) renders the new geometry; the shell review should confirm
  the counts UI still reads well at radius-0. The invites-tab role lowercase
  (F6) and the search `SizedBox(width: 104)` (F2) live in the friends/groups
  boundary — content-pass decisions.
- **U-26 (a11y audit):** (1) the group-detail skeleton is gray `surfaceAlt`
  blocks (no color-contrast surface — already-audited class); (2) F3 — the
  `_initials` empty-string edge (latent `RangeError`) is defensive-coding
  territory; (3) the shard-count 12px micro-text on the my_groups tiles
  resolves the subtitle `mutedStrong` color (7.37:1 AA) — already legal.
- **U-30 (doc finalization):** (1) §4.2's sharp-badge list is now fully
  honored — `VCountBadge` was the last pill; (2) the 12px/11px micro-scale
  voice (shard counts, RankBadge labels) could be tokenized; (3) the
  `VSkeletonDetail(rows: 1)` single-card usage is worth a §5.8 line for
  detail-hero screens.
- **U-29 (integration smoke):** no screen-level behavior changed that the
  flows assert (skeletons settle past their first frame; texts byte-identical
  apart from the de-dup, which no flow pins).
- **Pre-existing, reported (not touched):** `_getMemberLimit` '14' hardcode
  (F1/I-46); the `LinearProgressIndicator` is gone but `chat_screen`'s
  pagination spinner etc. remain allowlisted per U-21 (out of scope).

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §2/§3/§4/§5/§6/§7 (read in full — the
  contract).
- U-10/U-11/U-16/U-19/U-21/U-22/U-23 daily logs + handoff tables (the
  double-render flag, the my_role crash report, the skeleton handoff names,
  the Wrap/scroll-safety lessons, the review-pass pattern).
- Flutter SDK (read-only, 3.44.1): `MediaQuery.disableAnimationsOf` (the
  reduced-motion gate the in-scope animations honor).
- WCAG 2.2 contrast pairs via the doc's §2 tables (all contrast decisions in
  this pass reuse already-verified ratios).

## Change log

| Date | Change |
|---|---|
| 2026-08-11 | v1.0 authored by U-24 (review pass friends→groups; 11-screen checklist; FIX 1 my_role null-guard + FIX 2 double render + FIX 3 VLoadingView evaluation + FIX 4 sheet-surface consistency + FIX 5 VCountBadge sharp; 6 product flags; 1993/1993 full suite). |
