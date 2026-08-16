# 2026-08-15 — B-invited-state (ISSUE 2 + ISSUE 3)

Agent: `B-invited-state`. Scope: the invited-member group-detail state (ISSUE 2)
and the Info-tab restructure of GroupDetailScreen (ISSUE 3).

## What was built

- **B1** `GroupService.getMyGroups` now selects `group_id, role, status` and
  attaches `my_status` to every row (mirroring `my_role`), so invited
  memberships keep their pending marker in the groups list.
- **B2** New `GroupService.getMyMembership(groupId)`: the current user's own
  `group_members` row (`id, group_id, role, status`) scoped to the group,
  `maybeSingle` → Map or null.
- **B3** `GroupsRepository.getMyMembership` passthrough.
- **B4** New `myMembershipProvider` (`FamilyAsyncNotifier<Map<String,dynamic>?, String>`
  with `ThrottledRefresh` + `refresh()`), same shape as the other group providers.
- **B5** `GroupDetailScreen` rework:
  - Watches `myMembershipProvider(groupId)` alongside the existing three.
  - INVITED branch (`my_status == 'invited'`): violet `_scaffold` with a centered
    panel — group name (VDisplayText), `groupsInvitePendingBody`, primary
    `VButton.glowAccent` "Aceptar" (`_acceptInvite` → `acceptInvite(membershipId)` +
    invalidate groupDetail/groupMembers/contributions/groupInvites/myGroups/
    myMembership — the screen flips to the normal state) and a "Rechazar"
    `TextButton` (`_declineInvite` → `declineInvite(membershipId)` + `context.pop()`).
    No tabs, no hero CTAs, no leave. A null membership row renders the active state.
  - ACTIVE branch: `TabController` length 4; AppBar TabBar `groupsTabInfo |
    groupsTabChat | groupsTabMembers | groupsTabEvents`. Slim hero = VGlassCard
    with name + cover only. TabBarView = `_buildInfoTab` (new: description,
    tier/rank badges, shards, member count, leave row, my contribution, the
    Donar/Crear/Invitar/Juegos CTA row), `_buildChatTab` (unchanged), 
    `_buildMembersTab`, `_buildEventsTab`.
  - `_minTabArea`, frozen banner, `_invalidateData`, `_leaveGroup`, `_handleAction`
    preserved exactly.
- **B6** `MyGroupsScreen`: rows with `my_status == 'invited'` show a
  `VBadge(l10n.groupsInvitePending)` leading the subtitle wrap; tapping still
  opens the detail.
- **B7** `RequestsScreen`: `_acceptInvite`/`_declineInvite` also
  `ref.invalidate(myGroupsProvider)`.
- **Group model**: added `myStatus` (freezed) so `my_status` survives the
  `Group.fromJson → toJson` round-trip in `MyGroupsNotifier`; regenerated
  `group.freezed.dart`/`group.g.dart` with build_runner.

## L10n

No new keys — the requested keys were already in both ARBs (`groupsTabInfo`,
`groupsInvitePending`, `groupsInvitePendingTitle`, `groupsInvitePendingBody`)
and generated l10n. `flutter gen-l10n` not needed.

## Tests (RED → GREEN)

RED (proven — compile failures on current code):
- `test/services/group_service_test.dart`: `getMyMembership` group + pinned
  `my_status` in the getMyGroups enrichment test.
- `test/core/repositories/groups_repository_test.dart`: getMyMembership passthrough.
- `test/features/groups/flow_test.dart`: ISSUE-2 invited group (Aceptar/Rechazar
  only, no tabs/CTAs; Aceptar calls acceptInvite + flips; null membership
  falls back to active) + ISSUE-3 4-tab group + Info-tab content.
- `test/features/friends/flow_test.dart`: B7 accept/decline invalidate
  myGroupsProvider (counting-notifier + watcher Consumer pattern).

Note: B7's RED could not be shown as a failing run — the friends flow_test lock
was held by `C-search-accept` until after the RequestsScreen edit landed (locks
serialize file edits; the test file was written immediately after the lock was
acquired, then GREEN). The behavioral change is identical in shape to the other
proven-red tests.

restyle_test.dart needed **no** assertion changes — the 4-tab/Info-tab
restructure kept every restyle assertion green (hero glass card + VDisplayText,
badges/shards on the default Info tab, members tab hairlines).

## Validation

- `flutter test test/services/group_service_test.dart test/core/repositories/groups_repository_test.dart test/features/groups/flow_test.dart test/features/groups/restyle_test.dart test/features/friends/flow_test.dart`
  → **104 pass / 0 fail** (incl. new ISSUE-2 x3, ISSUE-3 x1, getMyMembership x3,
  B7 x2).
- `dart analyze` on all touched dirs → **0 issues**.
- `_buildChatTab` verified byte-identical (`git show HEAD` diff); tab order
  Info | Chat | Miembros | Eventos.

## MISTAKE

- Ran `dart run build_runner build` while parallel agents had in-flight edits to
  models; it regenerated only stale outputs (group.*) — verified via git diff
  that no other agent's generated files were rewritten. Coordination: check
  `git status` + lock list before running build_runner.

## Commands (reproducibility)

```bash
tools/agent_lock.sh acquire <path> --owner B-invited-state
dart run build_runner build --delete-conflicting-outputs   # after group.dart edit
flutter test test/services/group_service_test.dart test/core/repositories/groups_repository_test.dart test/features/groups/flow_test.dart test/features/groups/restyle_test.dart test/features/friends/flow_test.dart
dart analyze lib/core/services/group_service.dart lib/core/models/group.dart lib/core/repositories/groups_repository.dart lib/features/groups lib/features/friends/screens/requests_screen.dart test/services/group_service_test.dart test/core/repositories/groups_repository_test.dart test/features/groups test/features/friends/flow_test.dart
tools/agent_lock.sh release <path> --owner B-invited-state
```

## Notes / coordination

- The repo had in-flight parallel work: `OPT009-group-chain` (group_service
  transfer RPC, tests), `C-search-accept` (search_screen/user_service/friends
  flow_test — its ISSUE-5 tests ran green in my targeted run), and
  `A-realtime-invites` (main_shell + group_memberships_realtime_listener).
  All preserved; my changes are additive.
- `main_shell.dart`/`user_service.dart`/`search_screen.dart` modifications
  predate/overlap my session (other agents) — not touched by me.
