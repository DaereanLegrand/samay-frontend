# U-11 — Groups screens restyle: §5 rank badges, leaderboard podium, Playfair hero, glowAccent CTAs, hairline rows (2026-08-11)

**Agent:** U-11 | **Phase:** 04-ui (4.4) | **Status:** DONE

Contract: `docs/design/DISCO-DESIGN-SYSTEM.md` §2.1/§2.4/§3.2/§3.3/§4.2/§5.1/
§5.2/§5.4/§5.5/§5.6/§7.2 (read in full — THE CONTRACT), `docs/process/
AGENT-RULES.md` + `docs/process/FILE-OWNERSHIP.md` + `docs/process/
ORCHESTRATION.md` + `docs/process/DEVELOPMENT-WORKFLOW.md` (read in full),
U-01..U-10 daily logs + the handoffs (U-05: leaderboard → `RankBadge(rank:
rank_position)` for the §5.5 podium; U-02: leaderboard podium top-3 +
group-detail hero name → `headlineLarge`; U-01: `group_detail` red[900]
banner → `AppColors.error`/`errorFill`), I-46's `_getMemberLimit` hardcoded
'14' (report-only), AGENTS.md. Baseline before edits: `dart analyze` **0
issues**; `flutter test test/features/groups_screens_test.dart` **28/28**;
full `flutter test` **1815/0** (U-10 checkpoint).

## What was built

The 7 groups screens' disco restyle, exactly per the mission's handoffs.
**The FLOW is byte-identical**: every route, provider, l10n string, tap
target, debounce, donate/invite/leave/create pipeline, snackbar and dialog
action is untouched — this pass changes *rendering* only (U-16 owns flow
alignment). TDD: `test/features/groups/restyle_test.dart` (18 ledger tests)
written first — RED against the pre-restyle tree (15 failed for exactly the
missing treatments; the 3 green pin the already-theme-owned pieces: the
outlined Crear grupo/Ranking VButtons + Amigos/Solicitudes TextButtons, the
leaderboard tier VChips, and one wrong-reason green fixed by scoping — see
MISTAKE), then GREEN.

### The visual-change ledger (screen → §5 ref → change → test update)

| Screen | §5 ref | Change (visual) | Test update |
|---|---|---|---|
| `my_groups_screen.dart` | §5 (handoff 1) | Tile leading `VNetworkImage(40px circle)`/`CircleAvatar(grey[800])` → **`ProfileAvatar(size: 40)`** with cover `imageUrl` pass-through + name-initial fallback (U-09's widget — the §2.1 surfaceAlt + `border #333333` ring treatment) | `restyle_test` +1 (ProfileAvatar ×2) |
| `my_groups_screen.dart` | §3.3/§5 | Tile name → **`bodyLarge` white** (the §5 list voice; was ListTile default titleMedium) | `restyle_test` +1 (bodyLarge size + white) |
| `my_groups_screen.dart` | §5.5 (handoff 1) | Inline `'PROMOTOR · '` text → **`VBadge(label: role)`** (uppercase `labelSmall`, `border #333333` fill — the §5.5 role badge) | `groups_screens_test` `'PROMOTOR · '` → `'PROMOTOR'` (ledger); `restyle_test` +1 (VBadge + gold shards + RankBadge) |
| `my_groups_screen.dart` | §5.6 (verify) | Gold `VShardIcon(size: 12)` + count **already §5.6** (U-05) | `restyle_test` +1 (gold + xs) |
| `my_groups_screen.dart` | §2.1 rows | `ListView.builder` → **`ListView.separated`** with 1px hairline `Divider` separators (U-04 dividerTheme paints `#1A1A1A`) | `restyle_test` +1 (scoped N−1 + hairline) |
| `my_groups_screen.dart` | §5.1 (verify) | Crear grupo/Ranking `VButton` outlined + Amigos/Solicitudes `TextButton.icon` **already §5.1/U-04 theme-owned** — zero code change | `restyle_test` +1 (pins outlined variant + TextButtons) |
| `group_detail_screen.dart` | §3.2 (handoff U-02) | AppBar hero name → **`headlineLarge`** (Playfair Display italic 28 + glow-soft baked into the theme role — the doc's fancy moment) | `restyle_test` +1 (family/italic/28/glow-soft shadows) |
| `group_detail_screen.dart` | §5.5 (handoff 1) | Private `_Badge` (grey[900]/grey[700]) **deleted** → `VBadge(label: size_tier)` (§5.5 default: `border #333333` + white uppercase label — same text, token chrome) | `restyle_test` +1 ('MICRO' + VBadge + RankBadge + gold shard) |
| `group_detail_screen.dart` | §5.1 (handoff 2) | Donar → **`VButton.glowAccent(filled: true)`** (pink fill + black text 6.00:1 — the detail screen's one brand moment); Crear evento/Invitar stay outlined white | `restyle_test` +1 (glow + filled; secondaries outlined) |
| `group_detail_screen.dart` | §5.2 (handoff U-01) | Frozen banner `Colors.red[900]` → **`AppColors.errorFill` (glowPinkDeep)** fill + white text (5.87:1 AA — never raw red on black) | `restyle_test` +1 (container fill + white text) |
| `group_detail_screen.dart` | §5/§5.5 (handoff 2) | Members tab `_ContributorTile`/`_MemberTile` `CircleAvatar(grey[800])` → **`ProfileAvatar(size: 40)`**; role subtitle text → **`VBadge`** beside the name; each row closes with a 1px **hairline** `Divider` | `restyle_test` +1 (avatars + badges + hairline rows); `perf/list_view_builder_test.dart` `'promotor'`/`'member'` → `'PROMOTOR'`/`'MEMBER'` (I-20's file, lock coordinated) |
| `group_detail_screen.dart` | §5.4/U-04 (verify) | TabBar (3 tabs) + leave dialog **already theme-owned** (U-04 tabBarTheme black dialogTheme) — zero code change | pinned by `groups_screens_test` (unchanged) |
| `leaderboard_screen.dart` | §5.5 (handoff U-05) | Podium wiring: `RankBadge(bracket:, rank: rank_position)` — top-3 rows get the **gold/silver/bronze** border+label accent; non-top rows stay `rank: null` (white) | `restyle_test` +1 (rank 1/2/3 + border colors; rank 4 null) |
| `leaderboard_screen.dart` | §3.2 (handoff U-02) | Top-3 names → **`headlineLarge`** (Playfair italic 28 + glow-soft); the rest stay Inter list titles | `restyle_test` +1 (Playfair top-3, Inter rest) |
| `leaderboard_screen.dart` | §5.4 (verify) | Tier chips **already `VChip`** (U-05) — zero code change | `restyle_test` +1 (4 VChips, verify-only) |
| `create_group_screen.dart` | §5.8/§2.1 (handoff 4) | Cover picker grey[900]/grey[700]/`Colors.grey` → **`surfaceAlt` fill + `border #333333`** + camera icon `muted` (3:1 non-text OK) + label `mutedStrong` (§2.4 — informational text must be AA) | `restyle_test` +1 (fill/border/icon/label) |
| `create_group_screen.dart` | §5.1 (handoff 4) | CTA `VButton.emphasized` → **`VButton.glowAccent(filled: true)`** | `restyle_test` +1 (glow + filled) |
| `donate_shards_screen.dart` | §5.2 (handoff U-05, verify) | Amount field **already the token `VInput`** (mutedStrong label + `errorText` seam ready) — verify-only; header keeps Inter `headlineMedium` per U-02 (not a §3.2 Playfair site) | `restyle_test` +1 (label token + CTA) |
| `donate_shards_screen.dart` | §5.1 (handoff 5) | CTA `VButton.emphasized` → **`VButton.glowAccent(filled: true)`** | `restyle_test` +1 (glow + filled) |
| `invite_screen.dart` | §5.2 (handoff 6) | Search `OutlineInputBorder` **removed** → the U-04 `inputDecorationTheme` underline owns the field (hint/prefix unchanged) | `restyle_test` +1 (decoration border null) |
| `invite_screen.dart` | §5/§5.5 (handoff 6) | Result rows `CircleAvatar(grey[800])` → **`ProfileAvatar(size: 40)`** (initials + `avatar_url` pass-through); `ListView.builder` → **`ListView.separated`** hairline; Checkbox stays (U-04 sharp theme) | `restyle_test` +2 (avatars + checkbox + hairline; theme field) |
| `group_members_screen.dart` | §5/§5.5 (handoff 7) | Rows `CircleAvatar(grey[800])` → **`ProfileAvatar(size: 40)`**; role subtitle text → **`VBadge`** beside the name; `ListView.builder` → **`ListView.separated`** hairline | `restyle_test` +1 (avatars + PROMOTOR/MEMBER badges + hairline) |

**Zero-change contract:** all l10n strings, all routes (create → detail →
donate/invite/members/leaderboard chain, the leave-group dialog flow, the
invite debounce + member-exclusion), the donate snackbar error path, the
create-group limit dialog and every tap target are byte-identical — pinned
by the untouched `groups_screens_test` assertions (single ledger exception
below) and the untouched integration flows.

## Files created / modified (lock evidence)

All locks via `tools/agent_lock.sh acquire <path> --owner U-11` (acquired
07:13Z, held for the whole edit, released after):

| File | Action | Lock evidence |
|---|---|---|
| `lib/features/groups/screens/my_groups_screen.dart` | modified (avatar tiles/name/badge/separators) | acquire 240f544f1d85db856626cf61 → release |
| `lib/features/groups/screens/group_detail_screen.dart` | modified (hero/CTA/banner/members tab) | acquire 0394880233b04f0342d666a2 → release |
| `lib/features/groups/screens/group_members_screen.dart` | modified (avatar rows/badges/separators) | acquire 55152400a6c146a69b6ead90 → release |
| `lib/features/groups/screens/create_group_screen.dart` | modified (cover picker/CTA) | acquire add036da6c74020364f0e6bb → release |
| `lib/features/groups/screens/donate_shards_screen.dart` | modified (CTA) | acquire b91b3f5809438d354cfb3609 → release |
| `lib/features/groups/screens/invite_screen.dart` | modified (search field/rows/separators) | acquire 8b6d29305fe8f03424f8d43e → release |
| `lib/features/groups/screens/leaderboard_screen.dart` | modified (podium rank + Playfair names) | acquire bc13e14df77c3015b452f3d6 → release |
| `test/features/groups/restyle_test.dart` | **created** (18 ledger tests) | acquire 6dcc44e1c68e9749cf88b135 → release |
| `test/features/groups_screens_test.dart` | modified (`'PROMOTOR · '` → `'PROMOTOR'` — the single ledger text update) | acquire 9ea1ffdaa35c892f05693294 → release |
| `test/perf/list_view_builder_test.dart` | modified (`'promotor'`/`'member'` → `'PROMOTOR'`/`'MEMBER'` — **I-20's file**, restyle fallout, lock coordinated) | acquire (post-hoc, see commands) → release |
| `docs/to-fix/TODO.md` | modified (U-11 workstream block) | acquire b802f899fb97030c6d655fd5 → release |
| `docs/history/phase-04-ui/2026-08-11_U11-groups-restyle.md` | created (this log) | acquire 67ccfe8164eb02941a5a6f35 → release |

## Commands run (reproducibility)

```bash
export AGENT_NAME="U-11"
tools/agent_lock.sh list                                   # no locks before
dart analyze                                               # baseline 0 issues
flutter test test/features/groups_screens_test.dart        # baseline 28/28
tools/agent_lock.sh acquire <11 files> --owner U-11        # all held (07:13Z)
# RED: restyle_test.dart (18 tests against the pre-restyle tree)
flutter test test/features/groups/restyle_test.dart        # 3 pass / 15 fail = RED
#   (1 compile fix: SearchResultsNotifier lives in friends_providers;
#    wrong-reason green in my_groups hairline → scoped to the ListView)
# GREEN: the 7 screen edits
flutter test test/features/groups/restyle_test.dart        # 18/18 (after 3 test-side
#   fixes: members-tab divider count scoped to the ListView (the hero section
#    Divider also exists); banner Container(color:) has no widget decoration
#    (Container folds color: in build) → assert container.color; _badgeBorderColor
#    searched ANCESTORS of RankBadge → descendants (the badge Container is
#    inside the badge subtree))
dart analyze                                               # 4 issues → fixed
#   (unused_parameter on the never-parameterized contributions stub; 2×
#    prefer_single_quotes; unused app_spacing import)
dart analyze                                               # 0 issues
flutter test test/features/groups_screens_test.dart \
  test/features/groups/restyle_test.dart                   # 46/46 (1 ledger text update)
flutter test test/features/groups/ test/features/profile/ \
  test/features/friends/ test/widgets/ ...                 # 251/251 (neighbors)
flutter test                                               # FULL: 1 fail → fixed
#   (test/perf/list_view_builder_test.dart pinned the raw 'promotor'/'member'
#    subtitles — the §5.5 badge restyle's documented fallout; I-20's file,
#    lock acquired + assertion updated to the uppercase badge rendering)
flutter test                                               # FULL 1833/0
dart analyze                                               # 0 (post-doc)
tools/agent_lock.sh release <path> --owner U-11            # all 12 released
```

## Test results

- `test/features/groups/restyle_test.dart` — **18/18** (new; RED-proven: the
  15 failing assertions were exactly the missing treatments; the 3 green pin
  the pre-existing theme-owned pieces + the wrong-reason green fixed).
- `test/features/groups_screens_test.dart` — **28/28** (1 ledger text update:
  `'PROMOTOR · '` → `'PROMOTOR'`, the §5.5 VBadge rendering).
- `test/perf/list_view_builder_test.dart` — **2/2** (members-tab assertions
  repointed to the badge rendering).
- Neighbor suites (groups + profile + friends + widgets) — **251/251**.
- `flutter test` (full) — **1833 pass / 0 failures** (U-10 baseline 1815/0,
  +18 = the ledger tests; zero regressions).
- `dart analyze` — **0 issues**.

## Decisions made and why

- **Role text → VBadge (the one text change in this pass):** the mission's
  handoff says "role badge uppercase" — the §5.5 badge IS uppercase text, so
  `'PROMOTOR · '` (inline, with the manual separator dot) became the VBadge
  `'PROMOTOR'` and the gap is now real spacing. The row still carries the
  gold shard icon + count + RankBadge, so the dot was pure chrome.
- **Detail hero name lives in the AppBar title (U-02's handoff):** the
  handoff table names `group_detail_screen.dart` AppBar title as the §3.2
  site — applied `headlineLarge` there. The theme role bakes the glow-soft
  stack (`fancyTitle(headlineLarge, soft: true)`), so the fancy moment is
  zero extra code and byte-identical to `VGlowText` output (U-06 parity).
- **Donar = the ONE glowAccent CTA on the detail screen** (mission "maybe
  the primary donar → glowAccent"): §5.1 says ≤1 glow per screen — Donar is
  the money action; Crear evento/Invitar stay outlined white (their
  hierarchy preserved). Same call as U-07/U-09's canonical-primary rule.
- **Frozen banner = `errorFill` fill (glowPinkDeep) + white text, NOT
  `error` text on black:** it's a banner *surface*, so the fill treatment;
  white-on-glowPinkDeep = 5.87:1 ≥ 4.5:1 (AA) per §5.1's pressed-state
  pairing. U-01's handoff offered error/errorFill — the fill semantic fits
  the banner's role.
- **Members-tab hairline = per-tile closing `Divider(height: 1)`, not
  `ListView.separated`:** the tab's list mixes descriptor rows (headers +
  spacers + tiles, PERF-01); `separated` would draw hairlines after headers
  too. The tile-internal close keeps the §5 list treatment without touching
  the descriptor architecture (the PERF evidence test needed only its text
  assertions repointed).
- **Invite search field: removed the raw `OutlineInputBorder` entirely**
  instead of re-theming it — the U-04 `inputDecorationTheme` (white 1px/2px
  underline, mutedStrong label) IS the §5.2 field treatment; an explicit
  decoration would mask the theme (same reasoning as U-04's inert-theme
  table). Hint/prefix icons unchanged.
- **`_getMemberLimit` NOT fixed (I-46, report-only):** the member-limit
  display is hardcoded `'14'` in `group_detail_screen.dart` and the SQL
  `app_config` limit value is untracked here — a *data* fix, not a render
  fix; U-16/flow or I-46 owns it. Reported, untouched (the `'2 / 14
  miembros'` assertion is byte-identical).
- **GroupMembersScreen badge placement matches the detail members tab**
  (VBadge beside the name in a title Row, `Expanded` username) — one
  treatment across both member lists.

## MISTAKE

- **Wrong-reason green in the my_groups hairline test:** `my_groups_screen`
  carries a pre-existing section `Divider()` above the list — my first
  assertion (`find.byType(Divider) == 1`) passed against the *pre-restyle*
  tree for the wrong reason (the section divider, not a list separator) and
  would have failed GREEN (section divider + 1 separator = 2). Fixed by
  scoping to `find.descendant(of: find.byType(ListView))`. Lesson: when a
  screen already contains the widget you're counting, scope the finder to
  the region you changed.
- **`Container(color:)` has no widget-level `decoration`:** the frozen-
  banner test cast `container.decoration as BoxDecoration` and got `Null` —
  Container folds `color:` into the effective decoration at build time, the
  widget field stays null. Asserted `container.color` instead (same lesson
  as U-09's M3-Divider theme resolution: assert what the framework actually
  stores).
- **`_badgeBorderColor` searched ancestors instead of descendants:** the
  RankBadge's own `Container` is *inside* the badge subtree, not a parent —
  the first ancestor lookup found nothing. Switched to
  `find.descendant(of: badge, matching: find.byType(Container))`.
- **Test compile fix:** `SearchResultsNotifier`/`searchResultsProvider`
  live in `features/friends/providers/friends_providers.dart` (the invite
  screen imports them) — not in the groups providers. Added the import.

## Issues found / handoffs

- **I-46 (report-only, NOT fixed):** `group_detail_screen.dart`'s
  `_getMemberLimit` hardcodes `'14'` — the member-limit display ignores the
  `app_config` economy value (and any group > 14 members renders
  `N / 14 miembros` incorrectly). Data/flow scope; the restyle kept it
  byte-identical. Flag for the flow/data owners (U-16/I-46).
- **U-30 (doc finalization):** (1) the §5.5 role-badge + podium wiring is
  now concretized in 7 screens — worth promoting the RankBadge `rank:`
  podium + VBadge-role patterns into §5.5; (2) `ProfileAvatar` (promotion
  from U-10's handoff) is now consumed by the groups feature too — 3
  features cross-import it; (3) the invite search field's theme-underline
  treatment (no explicit border) could be noted in §5.2.
- **U-16 (flow alignment):** nothing to align — rendering only, every
  route/label/tap byte-identical (pinned by the untouched
  `groups_screens_test` assertions except the single ledger text update).
- **U-19/U-26 (responsive + a11y):** the AppBar hero name at 28px
  Playfair italic keeps the §3.3 metrics (glow halo legal §7.4); the
  `Expanded` usernames ellipsize safely at extreme text scales; contrast
  recap: badges white-on-`#333333` 21:1, podium labels ≥6.68:1, banner
  white-on-glowPinkDeep 5.87:1, gold shard 13.71:1 (non-text), mutedStrong
  label 7.37:1.
- **U-29 (integration smoke):** there is no `groups_flow_test.dart` in
  `integration_test/` (the I-78 sweep removed ghost flows; groups wasn't
  re-added) — consider a groups smoke case (podium badges + hero Playfair)
  in the U-29 pass.
- **Pre-existing, not touched:** the invite rows' `'@username'` title and
  the `member-count` hardcode above; the leaderboard tier chips keep caller
  casing (`micro` lowercase — the §5.4 chip-casing question is U-30's).

## Sources consulted

- `docs/design/DISCO-DESIGN-SYSTEM.md` §2.1/§2.4/§2.5/§3.2/§3.3/§3.4/§4.2/
  §5.1/§5.2/§5.4/§5.5/§5.6/§5.8/§5.9/§7.2/§7.4 (read in full — the contract).
- U-01 (semantic aliases + raw-red handoffs), U-02 (fancy-title application
  map incl. the group-detail hero + leaderboard podium), U-04 (component
  themes), U-05 (RankBadge podium capability + VBadge variants + glowAccent),
  U-09/U-10 (ProfileAvatar + restyle-test harness + M3 Divider lesson)
  daily logs.
- Flutter SDK (read-only, 3.44.1): `Container.build` effective-decoration
  folding (`color:` → BoxDecoration at build), M3 Divider theme resolution
  (from U-09's log).
- WCAG 2.2 contrast pairs via the doc's §2 tables (glowPinkDeep fill
  pairing 5.87:1, podium label ratios ≥6.68:1).

## TODO.md workstream block

Added the U-11 block to `docs/to-fix/TODO.md` (locked, 2026-08-11) — the
groups restyle summary above, verification numbers (analyze 0, groups 46/46,
neighbors 251/251, perf 2/2, full 1833/0), locked-file list, and handoffs
(I-46 `_getMemberLimit` '14' report-only, U-30 doc notes, U-16 nothing-to-
align, U-19/U-26 contrast recap, U-29 no groups flow test).
