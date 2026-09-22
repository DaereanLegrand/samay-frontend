# Samay — backend + realtime stress harness (`samay-loadtest`)

Date: 2026-09-21
Phase: 16 (post-MVP tooling)
Author: loadtest-agent

## What was built

A Go stress harness that both **generates realistic seed data** and **runs a
concurrent backend + realtime load** against a deployed gateway:

- `cmd/samay-loadtest/main.go` — flag/env wiring, signal handling, report render.
- `internal/loadtest/` — engine:
  - `config.go` — flags, validation, localhost guard, realtime URL builder.
  - `plan.go` — deterministic match plan (4 game types × 4 states × modes),
    friendship-edge generator, weighted picker.
  - `image.go` — in-process deterministic JPEG identicon avatars + gradient
    banners (no external image libs / services).
  - `client.go` — Kong HTTP client (auth admin, password/refresh, REST, RPC,
    storage upload) with a tuned connection pool.
  - `realtime.go` — native Supabase Realtime (Phoenix channels v1) websocket
    client (join/heartbeat/next) over `github.com/coder/websocket`.
  - `seed.go` — creates users, friendships, groups + members, events + rosters +
    photos, direct chats + messages, and 100 minigame matches across every game
    type and lifecycle state (lobby / countdown / playing / finished) with
    game-state, reactions and results.
  - `workload.go` — weighted authenticated/anon read+write mix.
  - `realtime_run.go` — N subscribers + activity generators, join ok/decline
    counts and write→delivery latency percentiles.
  - `metrics.go` / `report.go` — per-op latency percentiles + JSON/table report.
- Makefile targets: `build-loadtest`, `loadtest`, `loadtest-smoke` (keys read
  from gitignored env files at run time).

Contract: **create-only, no cleanup.** Each run is namespaced by `--run-id`;
non-localhost targets require `--yes`.

## Live run (target `https://samay-api.qallariy.lat`, create-only)

Seed (run-id `20260922T041306`): 100 users + 100 avatars, 300 friendships,
15 groups (15 banners, 113 members), 20 events (40 photos), 40 chats
(293 messages), 100 matches (100 game-states, 500 reactions, 45 results).

Load: 50 workers × 60s → **8120 ops, 1 error (0.012% error rate)**. p50 ≈ 250 ms
(network RTT to the host dominates), p90 ≈ 420–570 ms, p99 ≈ 2–3 s.

Realtime: 25 clients × 60s → 432 events, 75 joins / 0 declines; delivery
p50 ≈ 599 ms, p95 ≈ 3.7 s, p99 ≈ 6.2 s. 30 reconnect errors under load
(`received header with unexpected rsv bits set`), all self-healed by the
backoff reconnect loop.

## Decisions

- **Go harness under `cmd/` + `internal/loadtest/`** — fits the repo's Go
  backend and backend-only testing doctrine; ships as a reusable binary.
- **`--jwt-secret` first, GoTrue login fallback** — the target accepts
  locally-minted HS256 user JWTs (`supabase/.env` `JWT_SECRET`), so no per-user
  GoTrue sign-in and no sign-in rate-limit throttle. Without the secret the
  harness falls back to password logins and reports partial success.
- **Create-only** (user directive): no teardown; `--run-id` namespacing keeps
  re-runs collision-free.
- **Free-tier event capacity = 7** in the seeder — direct `events` inserts still
  fire `assert_event_capacity`, which freezes capacity from the creator's
  entitlement tier (7/14/56/1120).

## MISTAKE blocks

- **MISTAKE — duplicate identity build.** `Run` pre-built the identity list so
  tokens could be minted without seeding, and `Seed` built it again → 2× users
  (`--users 3` seeded 6). Fix: `Seed` only builds identities when
  `ds.Users` is empty.
- **MISTAKE — infinite loop when group size > distinct users.** The group-member
  loop kept drawing from a `seen` set that could never grow past the user count,
  so `memberCount` larger than the population spun forever (94% CPU, no
  network). Fix: `capMembers(desired, users)` + an attempts guard. Regression
  test `TestCapMembers`.
- **MISTAKE — realtime phase never terminated.** `RunRealtime` waited on a
  `WaitGroup` while subscribers looped on the parent context, which was never
  cancelled; the smoke run hung past its duration. Fix: derive a cancellable
  context, cancel it when the window closes, and guard the shutdown with a
  20 s timeout. Regression test `TestRealtimePhaseTerminates`.
- **MISTAKE — write ops acted as the wrong user.** `write:message` /
  `write:friend_request` picked random actors while the JWT belonged to a
  different identity, violating RLS insert policies. Fix: pass the acting
  identity into every op; messages are limited to chats the actor participates
  in (`Dataset.UserChats`).
- **MISTAKE — metrics test coupling.** The first `Recorder.Record` signature
  took a `time.Time` start, making the expected percentiles non-deterministic.
  Fix: record explicit durations.

## Commands run

```bash
go get github.com/coder/websocket@v1.8.13
go test ./internal/loadtest/...          # 40 tests green
go vet ./...
bash test/opt-005-seeds-static.sh        # PASS
bash test/opt-007-compose-static.sh      # PASS
bash test/opt-008-makefile-static.sh     # PASS
bash tools/check_secrets.sh              # PASS
make loadtest-smoke                      # live smoke, 0 errors
make loadtest                            # full 100/100 run, PASS
```

## Open items

- Realtime `rsv bits` client errors under heavy concurrent subscribe load cause
  reconnects (self-healing); worth investigating whether Kong/Realtime is
  emitting compressed frames the client did not negotiate.
- `loadtest-smoke` / `loadtest` currently default to the remote
  `samay-api.qallariy.lat` (user-designated testing-backed host); override with
  `LOADTEST_URL=` for any other environment.
- No `--jwt-secret`: `make loadtest` reads `JWT_SECRET` from the gitignored
  `supabase/.env` at run time (never committed).
