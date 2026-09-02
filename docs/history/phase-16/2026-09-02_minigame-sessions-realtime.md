# 2026-09-02 — Realtime-driven minigame session lists (stale per-game list fix)

## What was built

A returning player whose match was still ACTIVE on the server sometimes saw no
row on the per-game detail page — so there was no way to rejoin. Repro
(2026-09-02, simulator): tester4 left a running Truth or Dare (tapped back,
never kicked); the match was NOT listed on the "verdad o reto" page.

DB audit proved the server was healthy: `minigame_sessions` row `active`,
tester4 still in `participants`, invite `accepted`, RLS
`ms_read_direct_participant` passes. Root cause was a **stale client cache**:
`myMinigameSessionsProvider` is a keep-alive (non-autoDispose) provider built
once; nothing invalidated it on remote membership changes, and an invitee who
accepted after their copy had already been built never saw the session again.

Fix — mirror of the repo's four shell-lifetime realtime listeners (friendships,
group memberships, inbox, minigame invites), which is the canonical Supabase
Postgres-Changes + RLS pattern (server gates delivery, client re-fetches):

- `RealtimeService.subscribeToMinigameSessions` — subscribes to ALL
  `minigame_sessions` changes (`PostgresChangeEvent.all`). postgres_changes
  cannot filter an array membership (`participants` is uuid[]), so the whole
  table streams and the RLS SELECT policies bound delivery to rows the caller
  may read. `minigame_sessions` is already in `supabase_realtime` with
  REPLICA IDENTITY FULL (180_lobby) — no schema/publication migration needed.
- `MinigameSessionsRealtimeListener` — per-user channel (subscribe /
  re-subscribe on auth change / unsubscribe on dispose). On ANY delivered row:
  `ref.invalidate(myMinigameSessionsProvider)` (the per-game ongoing list),
  `ref.invalidate(myPendingInvitesProvider)` (a membership change shifts
  pending-invite vs ongoing), and — when the row carries a `group_id` —
  `ref.invalidate(minigameSessionsProvider(groupId))` (the group hub list).
- Mounted in `MainShell` beside the other four listeners (shell lifetime, so
  it covers the top-level `/minigames/...`, `/session/...` and `/play/...`
  routes too — the shell stays mounted underneath them).

## Decisions and why

- **Realtime invalidation, not accept-side patches**: the bug report's phrasing
  ("cannot not appear — if cached read cache; if new matches add; if match
  updates, the update") is exactly the read-cache-plus-invalidation model these
  listeners implement. It heals every remote path (accept on another device,
  host removal, status → finished, a session created for you) with one durable
  seam instead of sprinkling invalidate calls through each mutation flow.
- **Subscribe to the whole table, trust RLS**: the canonical Supabase guidance
  (docs fetched this session). No `user_id` column exists on the session row
  to filter on; RLS is the filter.
- **No backend/migration**: 180_lobby already put `minigame_sessions` on the
  publication with REPLICA IDENTITY FULL precisely so participant array
  changes stream whole rows.
- The pending-invite red badge is deliberately NOT touched — it stays owned by
  `MinigameInvitesRealtimeListener` (notification stream).

## Tests

No test layer added — pure client seam, and Dart/Flutter test trees are deleted
(directive 2026-08-31). Validation is static:

- `dart analyze lib` → **No issues found!**
- `flutter analyze lib` → **No issues found!**

## Commands

```bash
dart analyze lib
flutter analyze lib
```

## Files

- `lib/core/services/realtime_service.dart` (+`subscribeToMinigameSessions`)
- `lib/features/minigames/providers/minigame_sessions_realtime_listener.dart`
  (new)
- `lib/core/router/main_shell.dart` (mount the listener)
