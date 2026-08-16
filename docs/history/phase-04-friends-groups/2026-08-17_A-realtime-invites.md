# 2026-08-17 — A-realtime-invites: group invitations arrive without an app restart

Agent: `A-realtime-invites` · Issue 1: invites only appear after close/reopen.

## What was built

Root cause (verified): `group_members` was not in the `supabase_realtime`
publication, and no listener existed for group memberships — only
`FriendshipsRealtimeListener` and `InboxRealtimeListener` were mounted in the
shell.

- **A1** — migration `20260817000001_group_members_realtime.sql` (both
  `supabase/` and `supabase-testing/`, byte-identical): create the
  `supabase_realtime` publication if missing (20260815000002 pattern),
  `ALTER PUBLICATION ... ADD TABLE public.group_members`, and
  `REPLICA IDENTITY FULL` so DELETE events carry the full row (the listener
  needs `user_id` from delete payloads).
- **A2** — `RealtimeService.subscribeToGroupMemberships(onChange)` in
  `lib/core/services/realtime_service.dart`: channel `group-members:<uid>`,
  `PostgresChangeEvent.all` on `group_members`, forwards only rows where
  `row['user_id'] == user.id`. Mirrors `subscribeToFriendships` (line 138).
- **A3** — `lib/features/groups/providers/group_memberships_realtime_listener.dart`:
  `GroupMembershipsRealtimeListener` ConsumerStatefulWidget mirroring the
  friendships listener (post-frame subscribe, `authStateProvider` re-sync,
  unsubscribe on user change/dispose, best-effort with `AppLogger` error
  logging). On a membership row for the current user: invalidates
  `groupInvitesProvider` + `myGroupsProvider`. A defensive `user_id` check in
  the listener (beyond the service filter) makes the "row for another user"
  widget test meaningful.
- **A4** — mounted `const GroupMembershipsRealtimeListener()` in the Stack of
  `lib/core/router/main_shell.dart`. `pendingCountsProvider` derives from
  `groupInvitesProvider`, so the shell badge follows automatically.

## Tests (RED → GREEN)

- Extended `test/services/realtime_service_test.dart` with a
  `subscribeToGroupMemberships` group: channel name `group-members:<uid>`,
  event=all, table=`group_members`, forwarding only the current user's rows
  (other-user rows dropped), plus the no-session throw. RED proof (before the
  fix): `Error: The method 'subscribeToGroupMemberships' isn't defined` in
  both test files — compile failure for the right reason (missing behavior).
- New `test/features/groups/group_memberships_realtime_listener_test.dart`
  (mirrors the friendships listener test): counting notifier subclasses of
  `GroupInvitesNotifier`/`MyGroupsNotifier`, mock `RealtimeService`,
  fake auth. Covers: both providers rebuild on a row for the user; a row for
  another user does NOT rebuild; re-subscribe on user change (old channel
  unsubscribed, subscribe called twice); unsubscribe on dispose.

## Results

- `flutter test test/services/realtime_service_test.dart test/features/groups/group_memberships_realtime_listener_test.dart test/features/groups/flow_test.dart` → **28 passed** (incl. 6 new tests: 2 service + 4 listener).
- `dart analyze <5 touched files>` → **No issues found**.
- Migrations byte-identical: `shasum` matches
  (`3202a4878d9f07d8c924742a7ebad3ab8dfb92cd`).

## Decisions

- Channel name `group-members:<uid>` (plural, matches the `friendships:<uid>`
  convention) — the brief's `group-members:<uid>`.
- Listener performs its own `row['user_id'] == uid` guard in addition to the
  service filter (belt-and-braces: the mock-based widget test asserts the
  other-user row does not invalidate).

## MISTAKE

`dart format` reformatted pre-existing hunks in `realtime_service.dart` and
`realtime_service_test.dart` (the repo's committed style predates the current
formatter's line-wrapping). This would have churned another agent's files, so
both were restored from HEAD (`git show HEAD:<path>`) and only the new code
was re-applied in the original style. Final tracked diffs: +2 (main_shell),
+26 (service), +62 (test) — additions only.

## Commands run (reproducibility)

```bash
tools/agent_lock.sh list
tools/agent_lock.sh acquire <path> --owner A-realtime-invites   # per file
flutter test test/services/realtime_service_test.dart \
  test/features/groups/group_memberships_realtime_listener_test.dart \
  test/features/groups/flow_test.dart
dart analyze lib/core/services/realtime_service.dart \
  lib/features/groups/providers/group_memberships_realtime_listener.dart \
  lib/core/router/main_shell.dart \
  test/services/realtime_service_test.dart \
  test/features/groups/group_memberships_realtime_listener_test.dart
cmp supabase/migrations/20260817000001_group_members_realtime.sql \
    supabase-testing/migrations/20260817000001_group_members_realtime.sql
tools/agent_lock.sh release <path> --owner A-realtime-invites   # per file
```

## Not verified

- Migration applied to a live DB (orchestrator applies centrally; pgTAP
  suite owned by another agent this round — `schema_test.sql` untouched).
- Full Flutter suite not run (per brief — another agent may hold the flutter
  startup lock).
