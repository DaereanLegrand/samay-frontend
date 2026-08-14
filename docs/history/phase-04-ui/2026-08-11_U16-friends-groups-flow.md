# U-16 — Friends/groups FLOW alignment: per-row spinners + badges + pull-to-refresh + autofocus + mutual dialog + inline leave + member sheet (2026-08-11)

**Agent:** U-16 | **Phase:** 04-ui (4.4) | **Status:** DONE (7/7)

Contract: `docs/history/phase-04-ui/2026-08-11_U13-juega-flow-study.md` §5-U16 (the 7 recommendations — THE CONTRACT), `docs/process/DEVELOPMENT-WORKFLOW.md` (read in full: locks, no commits, no Juega), U-13 §7 disco guard rails, AGENTS.md. Baseline before edits: full `flutter test` **1862 pass / 0 fail** (U-15's total); `dart analyze` **0 issues**. This is the largest flow set (7 recommendations); each was implemented one at a time with RED → GREEN.

**Scope discipline:** flow changes ONLY — the disco look is done (U-01..U-12); no restyling beyond what the flow needs. One data-layer change (R15's mutual-accept) is the report-sanctioned exception (see deviation 1). No Juega code/infra touched. TDD: tests written first (RED proven), then the minimal implementation, suite checks after each step.

## The ledger — 7/7 recommendations

| # | Rec | Juega evidence | Samay change | Test impact | Verdict |
|---|---|---|---|---|---|
| R11 | **Per-row busy spinners on the requests accept/decline buttons** (the tapped row's buttons swap for a 16px white spinner while its action is in flight; every other row stays interactive) | DIRECT — `requests_screen.dart:213-247,370-403`; provider `friends_groups_provider.dart:58-60` | `requests_screen.dart`: local `Set<String> _processing` (per-row state — the report allows "provider or local state"; local keeps the data layer untouched). `_run(id, action)` guards double-taps, clears on completion, surfaces failures as a **transient snackbar** (F7: snackbars for row actions — a small improvement over the previous silent unhandled exception). `_ActionPair` gained `busy:`; a new `_BusyButton` covers the sent-tab cancel; `_RowSpinner` = 16px white `CircularProgressIndicator` (N3: never accent-colored). Received + sent + group-invite rows all wired | `flow_test.dart` +4 (RED-proven): tapped-row spinner + untouched-row button still enabled (accept and decline), sent-tab cancel spinner, invite-row spinner; spinner clears on completion | ✅ 4/4 |
| R12 | **Count badges on the Requests tabs (Received + Invites) and on the Grupos-tab entry rows** | DIRECT — `requests_screen.dart:104-157`, `friends_tab.dart:83,203-218` | NEW shared widget `lib/shared/widgets/v_count_badge.dart` — `VCountBadge(count)` (tiny, `VBadge.accent`-scale per §7.2: black fill, glowPink 1px border + `labelSmall` glowPink text; zero-width at 0; U-17's R18 shell badge will reuse it). Requests tabs: `_TabLabel(text, count)` under each `Tab` (received + invites counts from the already-loaded providers; sent stays bare). `my_groups_screen.dart`: the "Solicitudes" button carries the total pending (received requests + group invites) | `flow_test.dart` +4 (RED-proven): tab badges with data, hidden at zero, my-groups button total, hidden at zero | ✅ 4/4 |
| R13 | **Pull-to-refresh on the friends/requests/blocked/groups lists INCLUDING their empty states** | DIRECT — `friends_tab.dart:43`, `groups_tab.dart:39,84`, `requests_screen.dart:254,327,411`, `blocked_users_screen.dart:69` | NEW shared widget `lib/shared/widgets/v_refreshable.dart` — `VRefreshable(onRefresh, child)`: `RefreshIndicator` over an always-scrollable `LayoutBuilder`+`SingleChildScrollView`+`ConstrainedBox(minHeight)` so a centered empty state still answers a drag (the feed's `SliverFillRemaining` pattern in widget form). Wired: `friends_list_screen` (list + both empties), `requests_screen` (3 tabs, empties incl.), `blocked_users_screen` (list + empty via the existing `VStateView`), `my_groups_screen` (list + empty). All four reload via the notifiers' `refresh()` (invalidates the right provider per tab) | `flow_test.dart` +9 (RED-proven): one drag→reload per screen (friends, requests received, invites, blocked, my-groups) + the 4 empty-state variants. Existing assertions unchanged | ✅ 9/9 |
| R14 | **Search autofocus + the 2-char min-hint** (mirror the invite screen's hint) | DIRECT — `search_screen.dart:88` (autofocus), `invite_screen.dart:129-137` (Samay's own min-chars hint) | `search_screen.dart`: `autofocus: true` on the field; the `query.isEmpty → SizedBox.shrink` empty surface became the centered `friendsMinCharsHint` text for `query.length < 2` (identical gate to invite). 1 new l10n key | `flow_test.dart` +3 (RED-proven): keyboard attached on entry (`tester.testTextInput.hasAnyClients`), 1-char query → hint + no results, 2-char query → results. **Expected fallout absorbed:** the 6 pre-existing search tests that entered `'a'` now legitimately hit the hint — updated to `'an'` (`restyle_test` ×5, `friends_screens_test` ×1). The debounce-recording test (expects `['an']`) stayed green unchanged | ✅ 3/3 (+6 repointed) |
| R15 | **Mutual-friend dialog when the request is accepted instantly** | DIRECT — `search_screen.dart:208-226`, `public_profile_screen.dart:133-151` | **Data layer (report-sanctioned):** `UserService.sendFriendRequest` now returns `Future<String>` — `pending` (fresh insert) or `accepted` (the addressee had already sent the current user a `pending` request → the friendship is accepted instantly, exactly Juega's atomic `send_friend_request`; the old behavior *threw* on the reverse direction). `FriendsRepository` passes the status through. UI: `search_screen._sendFriendRequest` + `public_profile._sendRequest` show the mutual dialog (`friendsMutualAcceptedTitle`/`Body` + OK) on `accepted`, keep the snackbar on `pending`. 2 new l10n keys | Service test rewritten (`throws on reverse` → `accepts instantly + reports accepted`, `inserts` → `reports pending`); repo test asserts the pass-through. `flow_test.dart` +3 (RED-proven): search accepted → dialog + no snackbar, search pending → snackbar + no dialog, public-profile accepted → dialog | ✅ 3/3 |
| R16 | **Inline leave-group: the trigger moves from the overflow menu to a danger row next to the member count** (confirm dialog stays Samay-shaped) | ADAPTED — `group_detail_screen.dart:160-181` | `group_detail_screen.dart`: `TextButton.icon(Icons.logout, 'Abandonar grupo')` in `AppColors.error` (the §5.2 error semantic — glowPink 6.00:1, never raw red; same voice as the R7 danger pair) under the member-count line, before the CTA row. Popup menu now exists ONLY when frozen (the disabled frozen marker — the report's "keep the frozen item if frozen"); `_handleAction` only dispatches the frozen no-op. Zero new l10n keys (reuses `groupsLeave`/`groupsConfirmLeave`/`groupsAbandon`/`commonCancel`) | `groups/flow_test.dart` +3 (RED-proven): inline row present + menu gone when not frozen; full leave flow (row → confirm → cancel keeps screen → confirm → `DELETE group_members` via harness → pops to home); frozen menu keeps the disabled marker. Existing `groups_screens_test` leave test repointed from menu-tap to row-tap | ✅ 3/3 |
| R17 | **Admin member-actions bottom sheet (kick/promote/demote) on tappable member rows** | ADAPTED — `group_detail_screen.dart:55-107,197-199` | NEW `lib/features/groups/widgets/member_actions_sheet.dart` — `showMemberActionsSheet(context, ref, groupId, member, onChanged)`: sharp disco sheet (black surface, radius-0 — the flat sheet chrome is U-18's to promote; flagged), avatar+name header, then role-fitting options: `member` → Hacer co-promotor / Expulsar del grupo; `co_promotor` → Hacer miembro / Expulsar; `promotor` (owner) → never tappable. Actions call the EXISTING `GroupsRepository` RPCs (`setMemberRole` / `kickMember` — verified present in `group_service.dart:125-155`); **kick is confirmed via an `AlertDialog` first** (F8, `groupsKickConfirmTitle(name)` + body + Cancelar/Expulsar in error); failures → transient snackbar (F7); success → `onChanged` reload. Gated in BOTH surfaces: `group_members_screen.dart` (rows tappable when the current user's own row says `promotor`/`co_promotor`; `more_horiz` affordance) and the `group_detail_screen.dart` members tab (`_RowMember` gained `userId` + `canAct`; `_MemberTile` gained `onTap`). 6 new l10n keys | `groups/flow_test.dart` +5 (RED-proven): admin sheet opens with role-fitting options (promote on member / demote on co-promotor), non-admin rows never open it, kick confirms + calls `kickMember` + reloads (`getGroupMembers` called twice), promote calls `setMemberRole(role: co_promotor)`, detail-tab rows open the sheet. **I-20 coordination:** the perf test now boots the harness (see deviation 3) | ✅ 5/5 |

## Deviations from the report (each justified)

1. **R15 data-layer change — the report's own gate was triggered and passed:** the report said "Samay's repository returns the friendship status — **check it**". It does NOT (returns `void`). The mission allowed: "if the data layer can't support it cheaply, implement the dialog with the existing data or flag." It CAN support it cheaply — the reverse-request existence check already exists in `sendFriendRequest`; the change is *accept instead of throw* (the exact atomic behavior Juega's RPC has). A dialog that could never fire would be dead code, so the status pass-through (`pending`/`accepted`) landed in `UserService` + `FriendsRepository` (signatures changed; 2 test files updated; `search` + `public_profile` honor it). This also *fixes* a pre-existing flow wart: previously a mutual request threw "Ya existe una solicitud…" — now it becomes an instant friendship.
2. **R11 local state instead of a provider:** the report offered "add an `isProcessing(id)` set to the requests provider (or local state)". Local state keeps the data layer untouched (per-row state is ephemeral UI); the provider option would have made `friends_providers.dart` carry UI state. No provider changes were needed for any recommendation (counts for R12 come from the already-loaded providers; R13 invalidates them).
3. **R17 gating:** the report's "admin-gated" is implemented as `promotor` OR `co_promotor` (both Samay admin roles), acting on everyone except themselves and the owner (`promotor` rows are never actionable). If the RLS layer restricts `kickMember`/`setMemberRole` to `promotor` only (S-03's audit), co-promotors will hit the failure snackbar — server-side enforcement wins either way; flagged for S-03.
4. **R17 sheet chrome is minimal by design:** U-18 owns the sheet chrome (the report says "U-18 provides the sheet chrome"); the sheet here is a plain sharp `showModalBottomSheet` (black, radius-0). Handed to U-18 to promote into a shared widget + animation (reduced-motion gated).
5. **l10n keys:** 9 total (1 R14 + 2 R15 + 6 R17), all flow-copied from the invite/leave voices — no new strings beyond what each flow needs.

## MISTAKE blocks

- **MISTAKE (test-design bugs at RED time, caught by my own RED runs):** (a) the R11 completion assertion expected the accepted row to *leave* the list, but the stub notifier returns the same data after invalidation — fixed to assert both rows' buttons are restored; (b) the R13 my-groups fixture lacked `my_role`, crashing the VBadge cast — added `'my_role': 'member'`; (c) the R17 kick test re-tapped the row while the sheet was still open (ambiguous finder) — fixed to cancel-then-reconfirm inside the sheet (realistic UX: cancel keeps the sheet open).
- **MISTAKE (missed test-impact):** R17's admin gating reads `authServiceProvider` inside `_buildMembersTab`, which broke `test/perf/list_view_builder_test.dart` (I-20's file) — it pumps `GroupDetailScreen` without the Supabase harness. Full-suite RED caught it; fixed by booting the harness in that file's `setUpAll` (lock-coordinated, U-11's precedent for R17-free member-tab changes). A report miss — the report's R17 test-impact estimate ("+3") did not include the perf-file harness dependency.

## Files modified (lock evidence — 23 locks, all U-16, all released)

| File | Change | Lock |
|---|---|---|
| `lib/shared/widgets/v_count_badge.dart` | **NEW** — R12 count badge (U-17 will reuse) | created by U-16 |
| `lib/shared/widgets/v_refreshable.dart` | **NEW** — R13 refreshable short/empty content | created by U-16 |
| `lib/features/groups/widgets/member_actions_sheet.dart` | **NEW** — R17 admin member-actions sheet | created by U-16 |
| `lib/features/friends/screens/requests_screen.dart` | R11 spinners + R12 tab badges + R13 refresh (3 tabs + empties) | acquire+release, U-16 |
| `lib/features/friends/screens/search_screen.dart` | R14 autofocus + min-chars hint + R15 mutual dialog | acquire+release, U-16 |
| `lib/features/friends/screens/friends_list_screen.dart` | R13 refresh (list + 2 empties) | acquire+release, U-16 |
| `lib/features/friends/screens/blocked_users_screen.dart` | R13 refresh (list + empty) | acquire+release, U-16 |
| `lib/features/groups/screens/my_groups_screen.dart` | R12 Solicitudes badge + R13 refresh (list + empty) | acquire+release, U-16 |
| `lib/features/groups/screens/group_detail_screen.dart` | R16 inline leave + menu-only-when-frozen + R17 members-tab sheet gating | acquire+release, U-16 |
| `lib/features/groups/screens/group_members_screen.dart` | R17 admin-gated tappable rows + sheet wiring | acquire+release, U-16 |
| `lib/features/profile/screens/public_profile_screen.dart` | R15 mutual dialog (U-09's file — coordinated, lock was free) | acquire+release, U-16 |
| `lib/core/services/user_service.dart` | R15 `sendFriendRequest` → returns `pending`/`accepted`, mutual auto-accept | acquire+release, U-16 |
| `lib/core/repositories/friends_repository.dart` | R15 status pass-through | acquire+release, U-16 |
| `lib/l10n/app_es.arb` + `app_en.arb` | 9 new keys + `flutter gen-l10n` (regenerates `app_localizations{,_es,_en}.dart`) | acquire+release, U-16 |
| `test/features/friends/flow_test.dart` | **NEW** — R11×4, R12×4, R13×9, R14×3, R15×3 = 23 tests | created by U-16 |
| `test/features/groups/flow_test.dart` | **NEW** — R16×3, R17×5 = 8 tests | created by U-16 |
| `test/features/friends_screens_test.dart` | search test `'a'`→`'an'` (R14 fallout) | acquire+release, U-16 |
| `test/features/friends/restyle_test.dart` | 5 search tests `'a'`→`'an'` (R14 fallout) | acquire+release, U-16 |
| `test/features/groups_screens_test.dart` | leave-flow test repointed to the inline row (R16) | acquire+release, U-16 |
| `test/services/user_service_test.dart` | R15: reverse-throw test → mutual-accept + `pending` return | acquire+release, U-16 |
| `test/core/repositories/friends_repository_test.dart` | R15: status pass-through | acquire+release, U-16 |
| `test/perf/list_view_builder_test.dart` | harness `setUpAll` (R17 fallout; I-20's file — coordinated) | acquire+release, U-16 |
| `docs/to-fix/TODO.md` | U-16 completion block | acquired, U-16 (released at end) |
| `docs/history/phase-04-ui/2026-08-11_U16-friends-groups-flow.md` | **NEW** — this ledger | created by U-16 |

## Tests + results

- RED proofs: friends `flow_test` → 14 failures at first RED sweep (R11×4, R12×2, R13×9 minus green-by-design), R14×2, R15×2 (+compile-RED on the signature change); groups `flow_test` → R16×2, R17×4. Service/repo RED via the rewritten expectations. Then GREEN per step: R11 4/4 → R12 4/4 → R13 9/9 → R14 3/3 (+6 repointed, green unchanged) → R15 3/3 → R16 3/3 → R17 5/5.
- `flutter test test/features/friends/ test/features/groups/ test/features/friends_screens_test.dart test/features/groups_screens_test.dart test/providers/` → **202/202**.
- `flutter test test/perf/list_view_builder_test.dart` → **2/2** (harness fix verified).
- FULL `flutter test` → **1893/1893** (U-15 baseline 1862 + 31 new, zero regressions).
- `dart analyze` → **0 issues** (the 15 lint infos my first pass introduced — unused stubs, closure-assignment vs function-declaration, local underscore names — all fixed before the final gate).
- Disco guard rails (U-13 §7): no new Playfair sites (all Inter + existing roles); badges are `VCountBadge` tiny accent-scale (no new glow fills, §7.2); R16's leave row and R17's kick option use `AppColors.error` (glowPink, AA); all new surfaces radius-0 with hairlines (N2 — no glass/radius); reduced-motion: the sheet is a plain `showModalBottomSheet` (U-18's animation scope); no emoji; N3 respected — the R11 spinner is white.

## Issues found (reported, not touched)

1. **U-17 handoff:** R12's `VCountBadge` is the shell-badge widget for R18 (Grupos tab pending count) — reuse it; it's mounted-unconditional (zero-width at 0).
2. **U-18 handoff:** the R17 sheet is minimal chrome by design — promote a shared sharp sheet widget + the reduced-motion-gated animation; the `member_actions_sheet.dart` marks this explicitly.
3. **S-03 flag:** R17 UI gating admits `promotor` AND `co_promotor` as admins; if the RLS member-role RPCs are owner-only, co-promotors hit the failure snackbar — server-side enforcement wins either way.
4. **Pre-existing (U-13 §8, still open):** `group_detail_screen._getMemberLimit` hardcodes `'14'` (I-46); friends-list `@username` double render (U-16 decision point — **decision: left as-is**, it is a content/l10n change, out of flow scope; Juega's name-only row is a copy candidate for a later content pass).
5. **Report miss absorbed:** R17's gating broke the I-20 perf harness test (deviation 3) — the report's test-impact estimate didn't include it.

## Verification commands

```bash
dart analyze                                    # 0 issues
flutter test test/features/friends/ test/features/groups/ \
  test/features/friends_screens_test.dart test/features/groups_screens_test.dart \
  test/providers/                               # 202/202
flutter test test/perf/list_view_builder_test.dart   # 2/2
flutter test                                    # 1893/1893
```

## Change log

| Date | Change |
|---|---|
| 2026-08-11 | v1.0 authored by U-16 (friends/groups flow alignment, 7/7 ledger). |
