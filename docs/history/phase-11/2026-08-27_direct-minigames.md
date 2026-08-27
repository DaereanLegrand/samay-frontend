# 2026-08-27 — Direct (group-less) minigame sessions + Direct/Group hub toggle

## What was built

Group-less ("direct") minigame sessions are now first-class: **a user with
zero groups can create and play a minigame with a friend — no group required.**
Groups remain a convenience (bulk-invite / regular group play), matching the
user's framing ("groups is a nice to have... to quickly invite other people").

### Database (`supabase/migrations/100_minigames` + `140_minigame_invites`, mirrored)
- `minigame_sessions.group_id` is now **NULLable** — NULL = DIRECT session.
- New **`player_limit`** column (frozen at creation): the CREATOR's
  `subscription_tier` selects the cap from `app_config`
  (`minigame.free_max_players` = 8, `minigame.pro_max_players` = 32,
  `minigame.vip_max_players` = 100; fallback 8). Frozen on the row so a
  creator downgrade can never lock a running session. Enforced in
  `create_minigame_session` (roster = self + invitees), `join_minigame_session`
  and `accept_minigame_invite` (participant count) → typed `player_limit_reached`.
- **Conditional group gate** in `create/join/finish_minigame_session`:
  `p_group_id IS NOT NULL AND NOT is_group_member(...)` → `not_member`; a
  NULL group skips membership. Direct join/finish gate on
  participant-or-pending-invite standing → typed `not_allowed` (a bystander
  can never join or settle a direct wager).
- New RLS **`ms_read_direct_participant`** on `minigame_sessions`: requires
  `group_id IS NULL` AND `auth.uid() = ANY(participants)`. Direct sessions are
  readable ONLY by participants (invitees via the existing `ms_read_invitee`);
  bystanders can't list/watch/inspect them. Group sessions unchanged.
- `seed-config.sql`: +3 `minigame.*_max_players` keys (42 total).

### Flutter
- `MinigameService`: `createSession(String? groupId, ...)`, new
  `listMySessions()` (direct sessions where `auth.uid() = ANY(participants)`),
  `_columns` + `player_limit`, new typed rejections `playerLimitReached` +
  `notAllowed`.
- `MyMinigameSessionsNotifier` / `myMinigameSessionsProvider` (direct list).
- `MinigamesScreen` now has a **Direct / Group toggle** at the top
  (`MinigameScope`). `groupId` is optional: null → Direct default (a fresh
  user lands here); non-null → Group preselected (arrivals from group detail /
  group chat), toggle still reaches Direct. Group scope shows a group picker
  when no group is chosen (with a create-group CTA for the zero-groups edge).
- Routes: new static **`RoutePaths.minigamesDirect = '/minigames'`** registered
  BEFORE the `:groupId` hub (flag-gated). Convention test updated.
- Home feed `_openMinigames`: zero groups → push the **Direct hub** (no "join
  a group" snackbar); the multi-group sheet gains a **"Play directly"** first
  option.
- Chat: `ChatThreadView` composer gains a minigames entry button
  (`chatMinigameButton`) — 1:1 chat → Direct hub, group chat → that group's
  hub (both carry the toggle). Flag-gated.
- l10n (en/es): `minigamesScopeDirect/Group`, `minigamesPlayDirect`,
  `minigamesChangeGroup`, `minigamesDirectEmpty(Body)`,
  `minigamesErrorPlayerLimitReached`, `minigamesErrorNotAllowed`.

## Security posture (why it's safe)
- Every gate is **server-side**: membership is still `is_group_member`
  (SECURITY DEFINER, recursion-safe) for group sessions; direct sessions gate
  on participant/pending-invite standing inside the RPC transactions.
- The player cap is enforced in **three** RPCs (create/join/accept) and stored
  frozen — never trusted client-side.
- RLS never widens: `ms_read_direct_participant` requires BOTH `group_id IS
  NULL` AND participation, so group members don't gain read scope and
  bystanders see nothing. Verified behaviorally (opt-016 TEST G4: a bystander
  `can't read`, `can't finish`).
- Invite privacy (blocked / deleted / `minigame_invite_friends_only`) is
  unchanged — the feature only removed the group requirement, it didn't weaken
  any invite gate.

## Tests
- pgTAP `supabase/tests/schema_test.sql` (mirrored): `plan(649) → plan(661)`;
  nullable `group_id`, `player_limit` (not-null + default 8), the
  `ms_read_direct_participant` policy (name + expression), conditional
  membership gate, tier-cap computation, `player_limit_reached`/`not_allowed`
  in Section 45/49/49b. **Verified 661/661** against the self-hosted testing
  stack.
- `minigame_rpc_migration_test.dart`: +8 tests (nullable group_id, conditional
  gate, tier cap keys, join/accept cap, direct gates, `ms_read_direct_participant`,
  pgTAP pins both stacks).
- `minigame_service_test.dart`: `createSession(null,…)` → `p_group_id: null`,
  `listMySessions` filter shape, the new typed rejections.
- `minigames_screen_test.dart`: +3 direct-hub tests (default scope, direct
  create via the direct provider, Direct↔Group toggle). The shared test
  builder gained `isFilter`/`contains` overrides.
- `feed_test.dart`: zero-groups home tap → `/minigames` DIRECT hub.
- `plugged_entries_test.dart`: the old "join-a-group snackbar" test now asserts
  DIRECT navigation.
- `conventions_test.dart`: `RoutePaths.minigamesDirect` registered in
  `gatedRoutes` (flag route gating).
- `test/opt-016-minigames-invites.sh`: +TEST G (direct create null group,
  frozen free `player_limit`=8, invitee read, **bystander RLS + finish
  rejection**, over-cap create `player_limit_reached`). **24/24 pass.**
  Also fixed a pre-existing opt-016 JSON-whitespace parsing bug (PostgREST
  spaces after colons) via `norm_json()`, and made `cleanup()` delete
  friendships/minigame_invites/users rows so the suite is isolation-clean.
- `integration_test/minigames_flow_test.dart`: +direct flow (Direct hub →
  pick game → wager → create → session appears). Both flows pass on macOS.

## Validation
- `make check`: dart analyze **0**, flutter analyze **0**, go vet clean,
  ports STRICT PASS, secrets PASS.
- `make flutter-test`: **2470 pass / 0 fail** (baseline 2452 → +18).
- `go test ./...`: green (188 tests).
- `bash test/run_all_backend.sh`: **15/16** — only opt-007 static gate fails,
  the documented pre-existing SERVICE_KEY-vs-`.env` drift (opt-001..006,
  local `.env` rotated; runtime runs pass). opt-016 24/24.
- pgTAP: 661/661.

## MISTAKE blocks
- **MISTAKE (layout)**: adding the scope switch + group header to the hub
  Column collapsed the session `Expanded` on the 600px test surface, and the
  ErrorView overflowed. Attempted fix via `SliverFillRemaining` + a
  `LayoutBuilder` inside the sliver threw *"LayoutBuilder does not support
  returning intrinsic dimensions"* (SliverFillRemaining computes intrinsics).
  Fix: keep `Column + Expanded` and wrap empty/error states in a
  `LayoutBuilder → SingleChildScrollView → ConstrainedBox(minHeight: max) →
  Center` (`_fillState`) at the Column level — the standard
  fill-and-scroll pattern. Do NOT put LayoutBuilder inside a SliverFillRemaining.
- **MISTAKE (opt-test isolation)**: run 1's `opt-016` created an A→C accepted
  friendship that run 2's `cleanup` didn't remove (public.users rows survive
  the auth-user delete), silently satisfying the friends-only invite gate and
  breaking TEST A/C. Fix: `cleanup` now deletes friendships (both directions),
  `minigame_invites`, the group BEFORE its promotor user, public.users rows,
  then auth users. Also `users.minigame_invite_friends_only=true` from a prior
  run poisoned TEST A — deleting public.users rows fixed that too.
- **MISTAKE (macOS paste)**: `paste -sd, -` did not insert commas (BSD
  paste). Building the JSON array by string-append instead.
- **MISTAKE (uuid shape)**: cap-filler ids `…00000$i` were 11-char final
  segments (invalid uuid) → users insert silently failed. Used 12-char
  `…00000000000$i`.
- **Pre-existing (not mine)**: `opt-016`'s greps assumed compact JSON
  (`"status":"x"`), but PostgREST returns `"status": "x"` (space), so the
  whole suite failed on whitespace before TEST G existed. Normalized responses
  through `norm_json` (strip all whitespace). Also `users.minigame_invite_friends_only`
  was asserted via a broken `col_has_default(...,'false')` (the 3-arg form
  treats `false` as a column name) — replaced with a correct `pg_get_expr`
  check. And the app_config count test assumed 39 keys; now 42.

## Commands run (reproducibility)
```
make supabase-testing-reset
cd supabase-testing && docker compose exec db psql -U postgres -d postgres -c "CREATE EXTENSION IF NOT EXISTS pgtap;"
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql
flutter gen-l10n
flutter test test/features/minigames/ test/features/feed/ test/features/chat/ test/meta/conventions_test.dart test/features/plugged_entries_test.dart
flutter test -d macos integration_test/minigames_flow_test.dart
bash test/opt-016-minigames-invites.sh
bash test/run_all_backend.sh
make check
make flutter-test
go test ./...
```