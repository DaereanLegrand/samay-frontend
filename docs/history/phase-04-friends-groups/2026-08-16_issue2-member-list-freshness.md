# 2026-08-16 — group detail member-list freshness: screen-open refetch + pull-to-refresh (ISSUE: iPhone stuck at 4 members)

Agent: `orchestrator-issue2` · Phase 04 (friends & groups) · Working tree only.

## Symptom (user report)

Group "Grupito" (4 devices): Android + waydroid show the updated member list;
the iPhone is stuck at 4 members even though messages now arrive everywhere.

## Root cause (diagnosed)

`groupMembersProvider` / `groupDetailProvider` / `contributionsProvider` /
`myMembershipProvider` are **keep-alive family providers** (no autoDispose): a
re-opened `GroupDetailScreen` serves the STALE cached state forever. The only
remote-side refresh path is the shell-mounted `GroupMembershipsRealtimeListener`
(2026-08-17) — which requires (a) a build that ships the listener and (b) a
live realtime channel that actually delivered the event (realtime never
replays missed events; iOS backgrounding drops channels). The Miembros tab had
NO pull-to-refresh, so there was no non-realtime path to fresh data at all.

## Fix (RED → GREEN)

`lib/features/groups/screens/group_detail_screen.dart`:

1. **Screen-open refetch** — `didChangeDependencies` (one-shot `_refreshedOnOpen`
   guard; `ref.invalidate` is illegal in `initState` — the element's inherited
   access is not ready) invalidates all four detail-scoped providers on EVERY
   mount: group, members, contributions, my-membership. A member who joined/
   accepted on another device appears when the screen is (re)opened — no
   restart, no pull, no realtime dependency (works on older builds too).
2. **Pull-to-refresh on the Miembros tab** — `RefreshIndicator` around both the
   member ListView (with `AlwaysScrollableScrollPhysics`) and the empty state;
   `onRefresh` = `_refreshMembers()` which invalidates members + contributions
   (invalidate, NOT the ThrottledRefresh'ed `refresh()` — the explicit gesture
   must always hit the server) and awaits the refetch.

## Tests (RED → GREEN)

New `test/features/groups/group_detail_refresh_test.dart` (2 tests, mutable
members stub — the remote change is simulated between mounts/gestures):

1. **re-mount refetch**: first mount shows "4 / 14 miembros"; a 5th member is
   added "remotely"; re-mounting the screen must show "5 / 14 miembros".
   PRE-FIX: the keep-alive family cache served the stale 4-member state → RED.
2. **pull-to-refresh**: Miembros tab → fling down after a remote change →
   the new member appears. PRE-FIX: no RefreshIndicator → gesture no-ops → RED.

Validation: `dart analyze` 0 issues; `flutter test` **2423/2423** (2414 + 7
Issue-1 + 2 Issue-2); `test/features/groups` 45/45.

## Decisions made and why

- **Invalidate on every mount** (not just tab focus): freshness wins over
  cache here — the detail fetches are 2–3 small queries, and stale member
  lists were the actual user-visible bug. The `ThrottledRefresh` mixin is
  deliberately bypassed: it exists for mutation-driven refreshes, not for
  explicit user navigation/pull gestures.
- **didChangeDependencies over addPostFrameCallback**: the canonical
  mount-time invalidation seam; runs before the first build, no frame flash.

## MISTAKE (RED iteration)

First implementation put `ref.invalidate` in `initState` — Riverpod throws
"dependOnInheritedWidgetOfExactType<UncontrolledProviderScope> called before
initState completed" because `ConsumerStatefulElement.invalidate` touches the
inherited container. Moved to `didChangeDependencies` with a one-shot guard
(the probe harness reproduced it; fixed before the tests went green).

## Commands run

```bash
flutter test test/features/groups/group_detail_refresh_test.dart   # RED: 0/2 (stale cache / no gesture)
dart analyze lib/features/groups/screens/group_detail_screen.dart test/features/groups/group_detail_refresh_test.dart
flutter test test/features/groups/group_detail_refresh_test.dart   # GREEN: 2/2
flutter test test/features/groups                                  # 45/45
dart analyze                                                       # 0 issues
flutter test                                                        # 2423/2423
```

Locks: `lib/features/groups/screens/group_detail_screen.dart` +
`test/features/groups/group_detail_refresh_test.dart` (owner
`orchestrator-issue2`), held for the verifier pass.

Follow-up: independent verifier review in progress.
