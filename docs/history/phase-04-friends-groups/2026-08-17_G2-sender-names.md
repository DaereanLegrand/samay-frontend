# G2 — sender-name labels in group chat (USER FIX 2)

Date: 2026-08-17
Agent: G2-sender-names

## Context

USER FIX 2: in group chat, peer-bubble sender labels showed a random-looking
8-char uid prefix (e.g. `e5b725d6`) instead of the username (e.g. `tester4`).

Root cause (verified live, per assignment): when a user is INVITED to a group,
`groupMembersProvider(groupId)` fetches under RLS, which denies member lists to
non-active members → it caches `AsyncData([])` (keepAlive family +
ThrottledRefresh). Accepting the invite from the Requests screen invalidated
only `groupInvitesProvider` + `myGroupsProvider`, NOT the membership-dependent
providers — the stale empty members cache persisted and `_senderNameOf`
(lib/features/chat/widgets/chat_thread_view.dart) fell back to the uid prefix
for every peer.

## What was built

1. `RequestsScreen._acceptInvite` now ALSO invalidates
   `groupMembersProvider(groupId)`, `groupDetailProvider(groupId)` and
   `contributionsProvider(groupId)` after a successful accept. The invite rows
   already carry `group_id` (GroupService.getGroupInvites selects
   `id, group_id, role, joined_at, groups!inner(name)`); `_buildInvites` passes
   it through.
2. `ChatThreadView`: per-thread fallback resolver — when a peer sender has no
   row in `groupMembersProvider`, resolve the username ONCE per sender id via
   `friendsRepositoryProvider.getUserProfile(senderId)` (user_search_view —
   never throws, null for missing). Caches:
   - `_resolvedSenders` (senderId → username)
   - `_senderLookups` (senderId → in-flight future; concurrent bubbles coalesce)
   - `_unresolvedSenders` (ids with no profile — never retried)
   The uid-prefix fallback remains ONLY as the pending/final-resort label.

## Decisions

- Members-provider lookup stays the primary source; the direct resolution only
  kicks in for senders missing from the member rows.
- One lookup per sender id per thread: the in-flight map coalesces concurrent
  bubbles; the result/unresolved caches make it strictly one network call.
- Failures are logged with the id only (never the username), swallowed, and the
  id is cached as unresolved — no retry loops, no throw into the UI.
- `setState` only after the async gap (mounted-checked) — never during build.
- `_acceptInvite(String membershipId, String groupId)`; empty groupId (stale
  rows) skips the family invalidations harmlessly.

## Commands

- `flutter test test/features/friends/flow_test.dart test/features/chat/chat_screen_test.dart test/features/chat/chat_list_screen_test.dart test/features/groups/flow_test.dart`
- `dart analyze lib/features/friends/screens/requests_screen.dart lib/features/chat/widgets/chat_thread_view.dart test/features/friends/flow_test.dart test/features/chat/chat_screen_test.dart`

## Results

- RED: `flutter test test/features/friends/flow_test.dart test/features/chat/chat_screen_test.dart`
  → 3 new tests failed for the right reasons: members/detail/contributions
  builds stayed at 1 after accept; the uid prefix was never replaced by the
  resolved username. 56 pre-existing tests in those files stayed green.
- GREEN: `flutter test test/features/chat/chat_screen_test.dart
  test/features/chat/chat_list_screen_test.dart test/features/friends/flow_test.dart
  test/features/groups/flow_test.dart` → 79/79 pass. _Note: +2 = USER FIX 4
  tests in `groups/flow_test.dart` landed later; today's count is **81**
  (28+6+31+16)._
- `dart analyze` on the touched dirs/files → 0 issues.

## MISTAKE

- None this run, but note for future agents: `supabaseClientProvider` reads
  `Supabase.instance.client`, which THROWS SYNCHRONOUSLY in widget-test
  containers without a harness override. The resolver's try/catch must wrap
  the `ref.read` itself (not just the await) or the D4a uid-prefix test
  regresses with an exception escaping build.
