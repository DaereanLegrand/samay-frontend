# 2026-08-28 — Verdad o Reto play engine (DB/backend layer)

## What was built

The reusable **minigame play engine** (`150_minigame_play/play.sql`): two
tables + five RPCs that power all 5 game types (poke_chain, questions,
truth_dare, drunk_bottle, challenge) with game-specific state living in a
jsonb payload.

- `minigame_game_state` — one row per minigame session; `state` jsonb
  (`judge_index`, `round`, `phase` + game-specific keys), append-only
  `rounds` jsonb[], `minigame_game_state_touch` updated_at trigger, FORCE
  RLS with the single `mgs_read_participant` SELECT policy (reads the
  session row exactly when participant/invitee/group-member does).
- `minigame_prompts` — generic prompt bank (game_type + prompt_type +
  category + body), FORCE RLS, `mgs_prompts_select` (authenticated reads
  active prompts), seeded with the es-first Verdad o Reto content using
  deterministic ids + `ON CONFLICT (id) DO NOTHING`.
- RPCs (all SECURITY DEFINER, `SET search_path TO ''`, typed jsonb
  statuses): `get_minigame_game_state`, `init_minigame_game_state`
  (random first subject), `reveal_minigame_prompt` (random prompt of the
  validated prompt_type), `advance_minigame_turn` (round-robin judge_index
  + random subject), `complete_minigame_game` (draw settlement mirrored
  from `finish_minigame_session` NULL-winner path: `minigame_refund` per
  participant + session status flip).
- `minigame_game_state` joined to `supabase_realtime` (guarded DO block,
  mirror of 140_minigame_invites).

## Decisions

- **Security posture** mirrors 100_minigames/140_minigame_invites exactly:
  FORCE RLS, no client table writes, every mutation through SECURITY
  DEFINER RPCs, `not_authenticated`/`session_not_found`/`not_allowed`/
  `session_not_active`/`invalid_prompt_type`/`already_started`/`started`/
  `revealed`/`advanced`/`finished`/`not_started`/`ok` typed statuses.
- The random subject on `advance_minigame_turn` is server-random
  (`participants[floor(random()*n)+1]`), per the product requirement that
  players do NOT self-select. `judge_index` advances round-robin without
  skipping (the generic judge rotation), and the new subject may equal the
  current judge (independent dimensions).
- `complete_minigame_game` uses NULL-winner settlement: refunds every
  participant via `minigame_refund` when wager > 0 — there is no winner in
  a party game. ACL = authenticated + service_role.
- Deterministic prompt ids seeded in-migration so re-runs are idempotent.
- pgTAP Section 49c added after 49b; plan(661) → **742** (81 new
  assertions — counted against the same assertion regex the Dart static
  guard uses).

## Commands run

- `bash tools/check_migrations.sh` — passed (parity + no untracked after
  mirroring).
- `make test-file FILE=test/features/minigames/minigame_rpc_migration_test.dart` — passed.
- `make test-feature FEATURE=minigames` — passed.
- `make test-file FILE=test/meta/conventions_test.dart` — passed.
- pgTAP (stack UP): `PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql` — **42/742** after migrating; full 742 after re-init (`make supabase-testing-init` + `make supabase-init` applied the migration; the RLS/PG-catalog reality matches the migration once re-initialized).

## MISTAKE blocks

- **MISTAKE (migration state):** running pgTAP against the *already-live*
  local DB (which had NOT yet applied 150_minigame_play) correctly reports
  the new table/function assertions as failures — the assertion suite is
  the migration spec. The suite only passes once the migration is applied
  to the local stack (`make supabase-init`/`make supabase-testing-init`).
  Not a spec deviation; a deploy-ordering reality.
- **MISTAKE (contract-pinning):** Section 48's anon-SECURITY-DEFINER
  quarantine and Section 50/28's `function_privs_are` checks run against
  the whole `public` function inventory, so the play RPCs must carry the
  exact REVOKE PUBLIC / GRANT authenticated(+service_role for
  complete/settle) lines or the pre-existing gates fail.
