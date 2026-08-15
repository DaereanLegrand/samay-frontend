# Friends list freshness — local invalidation + realtime sync (2026-08-14)

**Branch:** `fixes` · **Worktree:** post-`af52ebf` (uncommitted by user directive)

## Symptom

"Friend appears on only one account" — after tester3 accepted tester2's
request, only one device's friends list showed the friendship. The DB row was
correct (single accepted row); the clients were stale.

## Root cause

`friendsListProvider` is a non-autodispose `AsyncNotifierProvider` — built
once, cached forever. NO friendship mutation invalidated it (accept/decline
invalidated only `friendRequestsProvider`), and there was no realtime, so the
remote side stayed stale until pull-to-refresh.

## What was built

1. **Local invalidation** — `friendsListProvider` invalidated after every
   mutation: requests accept/decline (`requests_screen`), public-profile
   send (mutual-accept)/accept/block (`public_profile_screen`), search send
   (mutual-accept), party-finder block.
2. **Realtime (remote side)** —
   - Migration `20260815000002_friendships_realtime.sql` (both stacks):
     `friendships` added to the `supabase_realtime` publication (mirrors the
     `messages` precedent). pgTAP +1 assertion (386/386) + header count 35.
   - `RealtimeService.subscribeToFriendships`: subscribes to
     `PostgresChangeEvent.all` on `friendships`; filters rows to the current
     user client-side (postgres_changes cannot OR two columns). RLS
     (`friendships_read_involving`) already gates the stream.
   - `FriendshipsRealtimeListener` (new, `lib/features/friends/providers/`):
     shell-mounted (`main_shell.dart`), subscribes when the auth user
     resolves (`ref.listen` on authStateProvider — the post-frame probe alone
     missed late-resolving sessions), re-syncs on account switch, unsubscribes
     on dispose; on ANY event touching the user → invalidates
     `friendsListProvider` + `friendRequestsProvider` (the shell badge
     derives from the latter). Failures logged, never silent.

## Tests

- `realtime_service_test` +2: friendships channel wiring (`event: all`,
  table `friendships`, per-user channel name) + row filtering (requester OR
  addressee pass; unrelated rows dropped) + no-session throw.
- `friendships_realtime_listener_test` (new): a remote friendships event
  invalidates BOTH providers (observed as rebuilds).
- Full suite 2232/2232 · analyze 0 · pgTAP 386/386 · migration parity
  byte-identical.

## Decisions

- Shell-mounted (not screen-level) so freshness holds from anywhere.
- The listener renders `SizedBox.shrink` inside a Stack above the Scaffold —
  zero visual footprint.

## MISTAKE blocks

- **MISTAKE:** the first listener draft probed the auth state only from a
  post-frame callback — a late-resolving provider meant it never subscribed.
  Fixed with `ref.listen(authStateProvider, ...)`.
- **MISTAKE:** `super(client: null!)` in a fake service throws in checked
  mode (`null!` is a runtime null check on the literal) — use mocktail
  `Mock implements` + `registerFallbackValue` for function-typed args.

## Follow-ups

- **LOGOUT FLUSH (user directive, same session):** `AuthScopeReset`
  (`lib/features/auth/providers/auth_scope_reset.dart`, mounted in
  `SamayApp` above the Navigator) — on logout (authenticated → signed out)
  or account switch, invalidates the 23 user-scoped providers (friends,
  requests, blocked, search, groups ×6, profile ×2, notifications, chat,
  QR, minigames, photos, party, feed, shards, events ×2). Test:
  `auth_scope_reset_test.dart` — logout + re-login rebuilds the cache.
  Suite 2233/2233 · analyze 0.

## Appendix — research consulted (2026-08-14)

- Riverpod docs (providers lifecycle): non-autodispose providers keep state
  until the container dies — the account-switch staleness root cause.
- Code with Andrea — "Riverpod Data Caching and Providers Lifecycle" and
  "Riverpod 2.0: The Ultimate Guide": the documented pattern for scoped
  caching is invalidating the user-scoped set when the session changes;
  family invalidation clears all instances.
