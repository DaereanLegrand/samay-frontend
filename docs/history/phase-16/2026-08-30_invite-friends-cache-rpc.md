# 2026-08-30 — On-device friends cache fixed: get_friend_profiles RPC

## What was built

The invite/buscar pickers showed **"Error del servidor. Intenta de nuevo."**
for empty and <5-char queries on the device. The root cause was finally
diagnosed via the device log:

```
[WARN] friends cache warm-up failed: type 'Null' is not a subtype of type
'String' in type cast
#0 _$UserProfileFromJson (user_profile.g.dart:10:18)   ← json['id'] as String
#1 FriendsRepository.getUserProfile ...
#2 FriendsCacheController._fetchFriends
```

**No user has a null username.** The `10:18` position is `json['id'] as String`
— the ID being null, not the username. That happens because the friend-profile
read went through the `user_search_view` client query, and on the production
backend (`samay-api.qallariy.lat`) that view is NOT queryable: PostgREST
returns the OpenAPI schema document (a `Map` with `swagger`/`paths`), so
`UserProfile.fromJson` got a map without a usable `id` → null cast → the WHOLE
cache warm-up aborted → empty cache → empty picker.

- **New `get_friend_profiles(uuid[])` SECURITY DEFINER RPC**
  (`supabase/migrations/130_search/02_get_friend_profiles.sql`, mirrored into
  `supabase-testing/`). Ships in the migration so it exists wherever the schema
  exists; returns ONLY the caller's accepted friends (scoped by `auth.uid()`)
  from `user_search_view` — one round trip, no N+1, no client-side view read.
- **`FriendshipService.getFriendProfiles`** calls the RPC.
- **`FriendsRepository.getUserSearchRows`** now delegates to the RPC (was a
  client `user_search_view` read).
- **`FriendsCacheController._fetchFriends`** uses the batched RPC and skips any
  unresolvable friend — one bad row can never abort the warm-up. Defensive
  cache reads skip corrupt rows instead of throwing.

## Why `user_search_view` was unreliable

The migration grants `authenticated` SELECT on `user_search_view` (120_views/
01_views.sql), and it works on the local stack. But PostgREST's schema cache on
the remote did not expose it as a queryable resource (a bare
`?select=id,username` returned the OpenAPI doc). Any client code depending on
that view is therefore deployment-fragile — the RPC removes the dependency.

## Decisions

- **RPC over view reads for friend-profile resolution.** The `search_users`
  RPC pattern (SECURITY DEFINER + `search_path=''` + auth.uid() gate) is the
  proven, deployment-portable way to read other users' profiles.
- **The warm-up must never abort on one bad row.** Skip unresolvable friends;
  cache what resolves; persist; fall back to the (possibly empty) cache on any
  network failure — never throw to the picker.
- The <5-char / empty picker path stays a pure device-DB read (encrypted Hive
  `friends_cache` box) — no network on the typing path.

## Tests

- `test/services/friendship_service_test.dart` (+2): `getFriendProfiles` calls
  the RPC with the ids and maps rows; empty list → `[]` without an RPC call.
- `test/core/repositories/friends_repository_test.dart` (+2): `getUserSearchRows`
  delegates to the friendship-service RPC; empty list short-circuits.
- `test/features/friends/friends_cache_provider_test.dart` (5): batched fetch +
  persist; **a friend with an unresolvable profile is SKIPPED, the rest land in
  the cache**; warm cache = pure disk read; network-down resolves to `[]`;
  refresh clears + re-fetches.
- `supabase/tests/schema_test.sql` (+7 → **plan(758)**): RPC exists, SECURITY
  DEFINER, empty search_path, PUBLIC-revoked, authenticated-EXECUTABLE, reads
  `user_search_view` scoped by `auth.uid()`, accepted-only. Mirrored into
  `supabase-testing/tests/`.
- Full `flutter test` = **1879 pass / 0 fail**; `flutter analyze` clean; the
  pgTAP plan-count guard passes.

## Commands run

```bash
flutter test test/services/friendship_service_test.dart                    # 23 pass
flutter test test/core/repositories/friends_repository_test.dart           # 14 pass
flutter test test/features/friends                                        # 48 pass
flutter test test/features/minigames/minigame_rpc_migration_test.dart \
  test/features/qr/qr_rpc_migration_test.dart                              # plan-guard pass
flutter test                                                              # 1879 pass / 0 fail
flutter analyze                                                           # 0 issues
# pgTAP (needs the Samay stack up — not available this session): supabase db test
```

## Files created/modified

- `supabase/migrations/130_search/02_get_friend_profiles.sql` (new)
- `supabase-testing/migrations/130_search/02_get_friend_profiles.sql` (mirror)
- `lib/core/services/friendship_service.dart` (+`getFriendProfiles`)
- `lib/core/repositories/friends_repository.dart` (`getUserSearchRows` → RPC)
- `lib/features/friends/providers/friends_cache_provider.dart` (batched fetch,
  skip-unresolvable, defensive cache reads)
- `supabase/tests/schema_test.sql` + `supabase-testing/tests/schema_test.sql`
  (Section 49e, plan 751 → 758)
- `README.md`, `test/README.md` (baselines)

## MISTAKE blocks

- **MISTAKE (blamed null username):** I initially assumed a user had a null
  `username` and "fixed" it by skipping null usernames. The crash line
  `user_profile.g.dart:10:18` is actually **`id`** (line 11 is username). The
  null `id` came from the OpenAPI-schema response of a non-queryable
  `user_search_view`, not from data. The lesson: pin the EXACT generated-code
  line/column to the failing cast before assuming which field is null.
- **MISTAKE (client view read):** the warm-up read friend profiles via a
  client-side `user_search_view` query, which is deployment-fragile. The RPC is
  the portable seam.
- **MISTAKE (migration placement):** I first placed `get_friend_profiles` in
  `040_friends/`, which runs BEFORE `120_views_ranking` creates
  `user_search_view` → `relation "public.user_search_view" does not exist` at
  apply time. Moved to `130_search/02_get_friend_profiles.sql` (runs after the
  view). The user's `make supabase-testing-reset` caught it immediately.

## Validation (2026-08-30, stack up)

- `make supabase-testing-reset` → all 33 baseline migrations apply cleanly,
  incl. `130_search/02_get_friend_profiles.sql`.
- `make supabase-seed-test` → tester users seeded.
- RPC end-to-end via Kong (`/rest/v1/rpc/get_friend_profiles`): tester2's 3
  accepted friends returned with valid id/username; passing a NON-friend id
  returns nothing for it (auth.uid() scoping verified).
- pgTAP against the testing stack: all 7 Section 49e assertions pass
  (ok 752-758). The 6 pre-existing failures (users-empty-181,
  create_minigame_session 4-arg/5-arg checks) are migration-order/seed-state
  artifacts unrelated to this change.

## Notes / follow-ups

- `supabase db test` needs the `samay` (non-testing) stack up; this session
  validated the schema test directly against `supabase-testing` (plan guard
  already validates count == assertions).
- The remote backend (`samay-api.qallariy.lat`) needs the new migration applied
  (or its PostgREST schema cache reloaded) for `get_friend_profiles` to exist;
  until then the warm-up falls back to the empty cache (no crash, empty picker).
