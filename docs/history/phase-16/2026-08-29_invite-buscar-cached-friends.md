# 2026-08-29 — On-device friends cache for invite/buscar (<5-char + empty)

## What was built

The invite/buscar search pickers previously showed **"Error del servidor.
Intenta de nuevo."** for empty and <5-char queries — the `< 5` path routed
through `friendsListProvider`, which does an N+1 per-friend profile fetch and
throws `ProfileResolutionError` on any unresolvable friend, surfacing as the
server-error toast. Per the user directive, the friend list is now an
**independent on-device cache fetched in the background at app launch** and
read by the pickers for empty + short queries.

- **Device-DB cache** (`lib/core/services/storage_service.dart`): a new
  encrypted Hive box `friends_cache` (AES-256, key in the platform Keystore,
  same as the other caches) storing the friend list as JSON, keyed by user id
  so an account switch never leaks. `HiveService` gains
  `cacheFriends` / `getCachedFriends` / `clearCachedFriends`.
- **Background warmer** (`lib/features/friends/providers/friends_cache_provider.dart`):
  `FriendsCacheController` (an `AsyncNotifier`) reads the device DB first —
  disk-first, so the picker has friends before any network lands — and if the
  cache is cold, fetches the friend list once and persists it. A warm-up
  failure is logged and falls back to the (possibly empty) cache, NEVER throws.
  `FriendsCacheWarmer` is mounted at the app root (`app.dart`) and kicks the
  fetch as soon as the user is authenticated.
- **`recentFriendsProvider` now sources from the on-device cache**
  (`lib/features/friends/providers/recent_friends_provider.dart`): no
  `friendsListProvider`, no N+1, no server-error path. Recency (chat inbox /
  minigame sessions) still degrades gracefully when cold.
- **Empty input shows the friend list**: `userSearchProvider` treats an empty
  query as "show all cached friends" (both `SearchScreen` and the group
  `InviteScreen` now render the friends on open, before any typing).
- The `search_users` RPC is STILL never fired for <5-char queries (SR002).

## Decisions

- **The friend list is a per-user device-DB cache, not a per-session
  in-memory provider.** It is fetched once at app launch (background), awaited,
  and persisted — so it survives app restarts and works offline.
- **The `< 5` / empty path is pure disk read.** Zero network I/O on the typing
  path; the "Error del servidor" path is structurally impossible (the provider
  never throws, never touches the N+1 friends-list fetch).
- **Disk-first, network-second**: the cache controller returns cached rows
  immediately if present (no network even on cold start with a warm DB).
- **Threshold stays the server contract** (`InputSanitizer.searchQueryMinLength
  = 5`) in `userSearchProvider`; screens don't branch on it.
- Kept `groupsMinCharsHint` / `friendsMinCharsHint` l10n keys (still asserted
  as *absent* by `flow_test.dart`); they are no longer referenced by any
  screen.

## Tests

- `test/features/friends/friends_cache_provider_test.dart` (new, 4): cold
  cache fetches + persists to the device DB + returns the friends; warm cache
  serves from the DB with zero network; empty cold cache (network down)
  resolves to `[]`, never throws; `refresh()` clears + re-fetches.
- `test/features/friends/recent_friends_provider_test.dart` — re-pointed to
  stub the on-device cache (`friendsCacheProvider`) instead of the old
  `friendsListProvider` source; recency ordering preserved.
- `test/features/friends/user_search_provider_test.dart` — re-pointed to the
  cache; **EMPTY query returns all cached friends** (must display the list).
- `test/features/friends/flow_test.dart` — R14: **EMPTY input shows the full
  cached friend list with zero backend calls**; the 5-char→1-char sequence
  regression now reads from the stubbed cache.
- `test/features/groups_screens_test.dart` — InviteScreen: **EMPTY input shows
  the full cached friend list**.
- `test/providers/*`, `test/features/profile/*`, `integration_test/theme_flow_test.dart`
  — the 5 fake `HiveService` implementations gained the 3 new methods.
- Full `flutter test` = **1874 pass / 0 fail**.
- `flutter analyze` clean.

## Commands run

```bash
flutter test test/features/friends test/features/groups test/features/minigames \
  test/providers test/features/profile test/router test/meta        # 558 pass
flutter test test/features/friends                                  # 37 pass
flutter test -d macos integration_test/theme_flow_test.dart         # pass
flutter test -d macos integration_test/friends_flow_test.dart       # pass
flutter test -d macos integration_test/minigames_flow_test.dart     # pass
flutter test                                                         # 1874 pass / 0 fail
flutter analyze                                                      # 0 issues
```

## Files created/modified

- `lib/core/services/storage_service.dart` (+`friends_cache` box + 3 methods)
- `lib/features/friends/providers/friends_cache_provider.dart` (new — the
  on-device cache controller + `FriendsCacheWarmer`)
- `lib/features/friends/providers/recent_friends_provider.dart` (reads the
  cache; no more N+1 / server-error path)
- `lib/app.dart` (mounts `FriendsCacheWarmer`)
- `lib/features/auth/providers/auth_scope_reset.dart` (+`friendsCacheProvider`)
- `test/features/friends/friends_cache_provider_test.dart` (new)
- `test/features/friends/recent_friends_provider_test.dart`,
  `test/features/friends/user_search_provider_test.dart`,
  `test/features/friends/flow_test.dart`,
  `test/features/groups_screens_test.dart` (re-pointed + empty-query tests)
- 5 fake `HiveService` implementations updated
- `docs/specs/steps/cross-references.md`, `README.md` (baseline → 1874)

## MISTAKE blocks

- **MISTAKE (in-memory only):** my first fix made `recentFriendsProvider`
  fetch via `friendsListProvider.future` on first watch. On the real device
  that fetch threw `ProfileResolutionError` (an unresolvable friend among the
  user's 3) → the picker showed "Error del servidor". The user directive was
  explicit: an INDEPENDENT cache fetched at app launch, persisted to the
  device DB, and read by the pickers — not a lazy in-memory fetch on the
  typing path. Rebuilt as the disk-first `friendsCacheProvider` + warmer.
- **MISTAKE (empty query):** I had not verified that EMPTY input renders the
  friend list. The user explicitly required it. `userSearchProvider` treats
  empty as "all cached friends" and both screens are pinned by empty-query
  widget tests.
- **MISTAKE (stale test source):** `recent_friends_provider_test` and
  `user_search_provider_test` still stubbed the old `friendsListProvider`
  source after the rewire; they returned empty until re-pointed to
  `friendsCacheProvider`.

## Notes / follow-ups

- `friendsCacheProvider` flushes with `auth_scope_reset` on logout/account
  switch; the per-user Hive key keeps accounts isolated even if a flush is
  missed.
- Recency degrades to username order on first open (chat inbox / minigame
  sessions stay cache-only). If exact recency is wanted on first open, warm
  those too — deferred: friends-showing is the priority.
- The realtime friendships stream (`FriendshipsRealtimeListener`) invalidates
  `friendsListProvider`, which `FriendsCacheWarmer` listens to and mirrors
  into `friendsCacheProvider.refresh()` — so accept/decline/unfriend updates
  the on-device cache without waiting for the next launch.
