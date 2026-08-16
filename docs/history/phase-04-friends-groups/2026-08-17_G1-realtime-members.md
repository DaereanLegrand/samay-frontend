# 2026-08-17 — G1-realtime-members: group members list refreshes live

Agent: `G1-realtime-members` · USER FIX 1: the group MEMBERS list must update
in realtime (accept / kick / join) in every open group-detail screen — no
pull-to-refresh.

## What was built

`GroupMembershipsRealtimeListener` (lib/features/groups/providers/
group_memberships_realtime_listener.dart) now invalidates the group's members
provider on EVERY delivered `group_members` row event, not just rows for the
current user:

- Added before the existing user_id guard:
  `final gid = row['group_id']; if (gid is String && gid.isNotEmpty)
  ref.invalidate(groupMembersProvider(gid));`
- Delivery is RLS-gated so an ACTIVE member already receives rows for ALL
  members of their groups (`group_members_read_same` via `is_group_member`)
  plus their own row (`read_own`), and REPLICA IDENTITY FULL (migration
  20260817000001) guarantees full rows on DELETE — so a co-member
  accept/kick/join lands live in every open group-detail screen.
- The info tab's member count derives from the same provider
  (`group_detail_screen.dart:87` watches `groupMembersProvider(groupId)`;
  Info tab shows `members.length`), so the count refreshes too. Did NOT
  invalidate `groupDetailProvider` (the group row itself never changes on
  membership events).
- The user_id-guarded invalidations (`groupInvitesProvider` +
  `myGroupsProvider`) are byte-identical to before; auth re-sync, dispose,
  and best-effort `AppLogger` logging are unchanged.

## Tests (RED → GREEN)

Extended `test/features/groups/group_memberships_realtime_listener_test.dart`
with a `_CountingGroupMembersNotifier extends GroupMembersNotifier`
(mirroring the existing counting-notifier pattern; family override uses
`overrideWith(() => ...)` — the zero-arg factory this Riverpod version's
family override expects):

1. **co-member event** `{'group_id': 'g-1', 'user_id': other}` →
   `groupMembersProvider('g-1')` REBUILDS; `groupInvitesProvider` +
   `myGroupsProvider` do NOT rebuild. Then **own-row event**
   `{'group_id': 'g-1', 'user_id': me}` → invites AND my-groups AND members
   all rebuild.
2. **row without a `group_id`** (unexpected payload) → no crash, nothing
   invalidated (regression guard).

RED proof: new test failed with the right reason — `a co-member event
invalidates the group members provider` — while the 4 pre-existing listener
tests stayed green. GREEN landed after the one-line listener change.

## Results

- `flutter test test/features/groups/group_memberships_realtime_listener_test.dart
  test/features/groups/flow_test.dart` → **20 passed** (6 listener incl. 2
  new + 14 flow). _Note: +2 = USER FIX 4 tests in `groups/flow_test.dart`
  landed later; today's count is **22** (6+16)._
- `dart analyze` on the two touched Dart files → **No issues found**.
- Full suite not run (per brief).

## Decisions

- Invalidate before the user_id guard so co-member rows refresh members while
  own-row invalidation order (guard → invites → myGroups) stays exactly as
  A-realtime-invites left it.
- `group_id` type-checked as `String` + non-empty instead of a bare cast —
  malformed payloads must not crash the shell-mounted listener.
- `groupDetailProvider` untouched: membership events never mutate the group
  row; the Info-tab count already derives from `groupMembersProvider`.

## MISTAKE

None (the first test-file compile error — `(_) => ...` family override
signature — was a harness/API-shape mismatch, fixed before the RED run; the
RED run itself failed only on the missing behavior).

## Commands run (reproducibility)

```bash
export AGENT_NAME=G1-realtime-members
tools/agent_lock.sh acquire test/features/groups/group_memberships_realtime_listener_test.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire lib/features/groups/providers/group_memberships_realtime_listener.dart --owner "$AGENT_NAME"
tools/agent_lock.sh acquire docs/history/phase-04-friends-groups/2026-08-17_G1-realtime-members.md --owner "$AGENT_NAME"
# RED
flutter test test/features/groups/group_memberships_realtime_listener_test.dart   # +5 -1 → RED
# GREEN
flutter test test/features/groups/group_memberships_realtime_listener_test.dart test/features/groups/flow_test.dart  # 20 passed
dart analyze lib/features/groups/providers/group_memberships_realtime_listener.dart test/features/groups/group_memberships_realtime_listener_test.dart  # No issues found
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"   # per file
```
