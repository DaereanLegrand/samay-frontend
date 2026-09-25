# 2026-09-24 — Configurable `@tester` seed universe (`tools/seed-feed-test.sh`)

## What was built

A large, **configurable** `@tester` test dataset for the local
`supabase-testing` stack, independent of the small `seed-test.sql` snapshot
(which is untouched):

- `supabase-testing/seed/seed-feed-test.sql` — N-configurable data (`:n`,
  `:base_url`): users, friendships, groups + members/contributions/rank
  snapshots, events + hosts/invites/attendances, minigame sessions +
  invites + group notices, group chats, notifications, event photos + likes.
- `tools/seed-feed-test.sh` — orchestrator: creates `tester` +
  `tester2..testerN@tester.com` (password `tester123`) through the GoTrue
  admin API, downloads + uploads **100% coverage** images (randomuser.me
  portraits → `avatars/`, Lorem Picsum banners/covers/photos →
  `events/`/`groups/`), applies the SQL, reports counts.
- **Script only** — no Makefile target (per directive: "its only as tools/
  script nothing else").

Defaults: `N=100` (99 numbered + `tester@tester.com`). Override with
`N=40 bash tools/seed-feed-test.sh`.

## Decisions made and why

- **Testing stack only, no prod mirror**: seeds live under
  `supabase-testing/seed/`; `supabase/seed-test.sql` and the `supabase-seed-test`
  target are untouched, so `opt-005`/`opt-007` seed-parity gates stay green.
- **Rows are trigger-bypassed but app-faithful**: `session_replication_role =
  replica` suppresses capacity/tier/notification triggers, but the values were
  taken from *real app-created rows* (see below) rather than invented, so the
  data matches what the server actually writes.
- **100% image coverage** (per directive, overriding the earlier 10% NULL
  idea): every account has an avatar; every event has a banner; every group a
  cover.
- **Chats/notifications included as a test-only exception** (the small
  `seed-test.sql` keeps its no-conversations directive).

## MCP-first replication (the corrected workflow)

Initially this was built backwards (SQL authored from the schema first). Redone
on directive: drive the app via Xcode MCP, then read the rows it produced and
replicate those shapes.

Real rows captured from the running app (logged in as `tester@tester.com`,
`samay-api.qallariy.lat` → local testing Kong):

| Flow | Captured reality | SQL replica change |
|---|---|---|
| Create group | `group_shards=0`, `size_tier=micro`, `rank_bracket=b0_20`, `frozen_at=NULL`; host-only `group_members`; `chats(type=group)` + host participant | tier by member count, shards = contribution sum, frozen only on the admin-frozen group |
| Create event | `status=upcoming`, `preshards_remainder_action='return'`, `dynamic_qr_enabled=false` at pool 0 | `dynamic_qr_enabled = (pool > 0)` |
| Create minigame | `name=NULL`, `auto_name='partida-N'`, `player_limit=32` (PRO tier), `round_target=5`, `prize_positions=3`, `play_mode='by_turns'` | auto_name for every session, `player_limit=32` for PRO creators |

## MISTAKE blocks (for future sessions)

- **MISTAKE — built the seed schema-first.** The user wanted: perform each
  state in the app via Xcode MCP → inspect the DB → make the script a replica
  of that. Writing the SQL from the schema produced values the app can never
  write (e.g. a user-created group with `group_shards=12345`,
  `size_tier=medium`, `rank_bracket=b80_90`). Always create a canonical
  instance through the real client first, then replicate.
- **MISTAKE — misread a stale app session as a broken backend.** The running
  app held a session for the *old* `tester3` UUID (`c5c2cba7…`) that the seed
  had deleted. Its group-create failed with `VALIDATION_ERROR` (FK
  `groups_created_by_user_id_fkey`) and the feed showed stale `[demo-arq]`
  cache. REST login as `tester@tester.com`/`tester3@tester.com` proved the
  backend was fine; a logout/login fixed it. Seed runs recreate auth users, so
  **the app must re-login after every seed run.**
- **MISTAKE — multi-line `@echo` in the help recipe.** Inserting a help entry
  as raw indented lines (not TAB-prefixed `@echo`) broke the whole Makefile
  (`missing separator`), which made every `make -n <target>` fail in
  `opt-008`. Each help line must be its own `@echo "…"` with a leading TAB.
- **MISTAKE — `ARRAY[ARRAY[…], …][i]` 2-D array indexing** yields a scalar in
  Postgres, not a 1-D array. Use `CASE` returning `ARRAY[…]::text[]`/`uuid[]`.
- **MISTAKE — `row_number()` is `bigint`**; `pg_temp.tuid(text, int)` needs an
  explicit `::int` cast.

## Commands run

```bash
# apply / iterate
PGPASSWORD=postgres psql -h 127.0.0.1 -p 54382 -U postgres -d postgres \
  -v n=10 -v base_url=http://127.0.0.1:54386 \
  -f supabase-testing/seed/seed-feed-test.sql

N=100 bash tools/seed-feed-test.sh

# static gates
bash test/opt-005-seeds-static.sh   # 45 checks, PASS
bash test/opt-008-makefile-static.sh # PASS
```

## Known issues observed (out of scope, not fixed)

- Feed invitation card shows a `RenderFlex overflowed by 0.6 pixels` banner.
- Event create: provided coordinates persist to `location_lat/lng` but
  `location_name` stays empty → UI shows "Sin ubicación".
- Lobby `Partida abierta` switch renders ON while its accessibility value
  reads `0`.

## Follow-up fixes (same day)

- **Broken event covers** (iPhone 11): the seed was storing event banners in the
  private `events` bucket and pointing `events.cover_url` at the public
  `/events/…` path → storage returned `404 Bucket not found`, so the feed
  showed broken-image placeholders. The app's real contract
  (`media_service.dart:56 uploadEventCover`) uploads covers to the **public
  `groups` bucket at `event_covers/<ts>.jpg`** and stores that public URL.
  Seed now uploads `groups/event_covers/<eventId>.jpg` and sets `cover_url`
  accordingly; verified `200 image/jpeg` and real photos in the feed after a
  fresh login. Event **photos** stay in the private `events` bucket (signed
  URLs), path aligned to `<eventId>/photos/photo-<j>.jpg`.
- **Feed card overflow + title layout**: `_MinigameMatchCard` put the game
  label + title in a narrow left column (`flex: 2`) where the title wrapped to
  2 lines and the card overflowed (`BOTTOM OVERFLOWED BY 5.0 PIXELS`). New
  layout: the game name and the partida name are each a **single full-width row
  on top of the bubbles**, and the bubble row takes the remaining height via
  `Expanded`. Added `lib/shared/widgets/circulating_text.dart` — a one-line text
  that stays static when it fits and circulates (marquee) when wider than the
  card, mirroring the Games-tab `GameNameBand`; used for the minigame card
  (game name + title) and the event card title. `_kMatchCardHeight` 128 → 150.
  `dart analyze` clean.
- The running dev builds still show the old card layout until a hot reload.

## Not yet UI-captured

Invite/accept/decline, friendship request/block/accept and the
draft/live/ended/cancelled event transitions were not individually driven
through the UI; the seed covers them from the server contracts (status cron,
RPCs). Driving those one-by-one via MCP remains available if a fully
UI-derived replica is required.
