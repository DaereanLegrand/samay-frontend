# 2026-08-31 — Host-device countdown + round-0 key distribution (on-device fixes)

## What was built

- **`203_minigame_host_start` migration** — `start_minigame_match(p_session_id)`
  SECURITY DEFINER, creator-only (`participants[0]`). The host's device calls
  it when its own 5s device-clock countdown reaches 0 without a cancel; it
  flips `state.phase` `countdown → playing`. The realtime stream carries the
  authoritative "match is starting" broadcast to every participant.
- **Removed the server countdown entirely**: `init_minigame_game_state` no
  longer seeds `countdown_ends_at`; `get_minigame_game_state` no longer
  lazy-flips countdown (the async-timer auto-finish lazy-flip is KEPT). No
  cron, no server timer.
- **`_CountdownOverlay` reworked** to the two-counter model:
  - Host: countdown number + Cancel; at 0 the host's device auto-calls
    `startMatch()`.
  - Non-host: countdown number; at 1 → "Waiting for the host…" with a 10s
    watchdog → host-error if neither start nor cancel arrives.
  - The overlay now repaints every second (`setState`) — the number actually
    counts down (previously frozen at 5/4).
- **Round-0 key distribution fix**: `mintRoundKeyAndDistribute` +
  `rotateRoundKey` build the history bundle from `r=0` (was `r=1`), so `K_0`
  reaches the roster and the non-host subject can encrypt/decrypt round 0.

## Decisions

- Per user directive (2026-08-31): **no cron, no server countdown, no server
  timer, no `countdown_ends_at`**. The countdown is on-device, synced to each
  device's internal clock, started by the server's `phase='countdown'` signal.
  The HOST's device is authoritative for confirming start (`start_minigame_match`).
- Host sees its own countdown + Cancel (Counter B); non-hosts see Counter A
  then "Waiting for the host".

## MISTAKE blocks

**MISTAKE: the on-device countdown never repainted.** The overlay's
`Timer.periodic` only called `refresh()` at 0 — it never called `setState` per
tick, so the number was computed once and frozen at 5/4 until the server flip.
Fix: `setState` every second.

**MISTAKE: the server countdown flip depended on a lazy client read.**
`get_minigame_game_state` flipped `countdown → playing` only when a client
read after the deadline. If no client re-read (backgrounded app, missed tick),
the match never started — the host had to leave/re-enter. Fixed by making the
host's device call `start_minigame_match` explicitly.

**MISTAKE: round-0 keys were never distributed.** The game starts at round 0,
but the history-bundle loops ran `for (r = 1; r <= round; r++)`. At round 0 the
loop body never executed, so `K_0` stayed local to the host and the subject
self-healed to an empty bundle → `round key 0 missing`. Fix: `r = 0`.

## Commands

```bash
make supabase-testing-reset
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres \
  -c "CREATE EXTENSION IF NOT EXISTS pgtap SCHEMA public;" \
  -f supabase/tests/schema_test.sql
bash test/opt-021-minigame-play-v2.sh   # 71/71 (TEST I: host-confirmed countdown)
bash test/opt-018-minigame-play.sh      # 28/28
bash test/opt-020-minigame-voting.sh    # 31/31
dart analyze lib/ && go test ./...
```
