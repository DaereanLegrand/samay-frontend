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
  commit).
- `make test-file FILE=test/features/minigames/minigame_rpc_migration_test.dart` — passed (51 tests).
- `make test-feature FEATURE=minigames` — passed (102 tests).
- `make test-file FILE=test/meta/conventions_test.dart` — passed (34 tests).
- pgTAP (stack UP): `PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql` — **741/742**; the single failure (#181 "users table empty after init/reset") is a PRE-EXISTING environmental condition: the local dev stack accumulated opt-curl test users (user_a/b/c_opt006, tester1..4) from earlier sessions. All 81 new Section 49c assertions pass.
- Full lifecycle smoke test (in ROLLBACK): create → init (random subject) → idempotent init (already_started) → reveal (random prompt) → invalid_prompt_type → advance (round-robin judge + random subject + round append + prompt clear) → complete (phase + session finished) → get (ok). Wager path: 10-shard session refunded BOTH participants via minigame_refund ledger.
- Security verify: `minigame_game_state` + `minigame_prompts` both `relrowsecurity=t, relforcerowsecurity=t`; authenticated role reads 0 rows of game state without session standing.

## Files created/modified

- `supabase/migrations/150_minigame_play/play.sql` (new)
- `supabase-testing/migrations/150_minigame_play/play.sql` (new, byte-identical)
- `supabase/tests/schema_test.sql` (Section 49c, plan 661→742)
- `supabase-testing/tests/schema_test.sql` (byte-identical mirror)
- `test/features/minigames/minigame_rpc_migration_test.dart` (new group, +9 tests → 51)
- `README.md` (pgTAP baseline plan 661→742)
- `docs/history/phase-16/2026-08-28_truth-dare-play-engine.md` (this log)

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
- **MISTAKE (FORCE without ENABLE):** `FORCE ROW LEVEL SECURITY` does NOT
  enable RLS — they are orthogonal PG knobs. The first migration applied
  only FORCE, leaving the GRANT SELECT open to ALL authenticated users
  (any authenticated user could read every game state row). Caught by the
  pgTAP `relrowsecurity` reality check; fixed with
  `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` on both tables and re-verified
  that an authenticated caller sees 0 rows without session standing.
- **MISTAKE (pg_get_functiondef formatting):** `pg_get_functiondef` normalizes
  multi-line `jsonb_build_object(...)` into a single line (or splits
  `NEW.updated_at := now()`), so the `pg_get_functiondef(...) LIKE '%...%'`
  static assertions must match the normalized body, not the migration
  source. Rewrote 4 assertions to match (touch stamp, init skeleton,
  reveal draw, advance bump).
- **MISTAKE (commit hygiene):** the pgTAP baseline number I must update
  (README line) was interleaved in a file that ALSO carried another
  session's uncommitted suckless-test edits. `git add README.md` swept
  their edits into my commit (46ecafd). No content lost — it's preserved in
  the commit — but their in-flight README work is now inside my commit
  rather than their working tree. The other session's 58 staged test-file
  deletions were NOT touched. Coordinate before touching README.md when it
  has concurrent uncommitted edits.

---

## Flutter layer (2026-08-28, same session — orchestrator)

### What was built
- **Reusable Dart engine** `lib/features/minigames/logic/minigame_engine.dart`
  — game-agnostic turn skeleton (`GameTurnSkeleton`, `MinigameGameState`,
  `GameRoundRecord`), `MinigamePhase`, `PromptOutcome`, round-robin
  `nextJudgeIndex`, seeded `randomParticipantIndex`. Pure Dart, unit-tested.
- `lib/features/minigames/logic/truth_dare.dart` — `TruthDareKind`
  (verdad/reto wire), prompt-body extraction, localized choose headers.
- `MinigameService` +5 methods: `getMinigameGameState` (null on
  `not_started`), `initMinigameGameState` (idempotent `already_started`),
  `revealMinigamePrompt` (server-random draw), `advanceMinigameTurn`,
  `completeMinigameGame` (idempotent `already_finished`) +
  `subscribeToGameState` channel. Typed error mapping per status.
- `minigameGameStateProvider` (family by session) — auto-initializes on
  first read, live-merges the `minigame-game-state` realtime channel,
  exposes `reveal`/`advance`/`complete` notifier actions.
- `TruthDareScreen` + `RoutePaths.truthDare`
  (`/minigames/play/truth-dare/:id`), flag-gated; registered in the router,
  `conventions_test` gatedRoutes, `notifications_providers` deep-link
  recognition, and `auth_scope_reset` invalidation. Subject name resolves
  from the session participants; the current subject sees Verdad/Reto,
  everyone else the waiting header; revealed prompt shows Hecho/Saltar.

### Tests
- `test/features/minigames/logic/minigame_engine_test.dart` (14) +
  `truth_dare_test.dart` (7) — pure logic.
- `minigame_service_test.dart` +9 (RPC params + typed errors).
- `minigames_providers_test.dart` +6 (auto-init, reveal/advance/complete,
  realtime merge); fakes extended for the grown interface.
- `truth_dare_screen_test.dart` — 4 functional widget tests asserting the
  reveal/advance/complete wiring (not render-only).
- `integration_test/truth_dare_flow_test.dart` (registered in runner.sh).
- `test/opt-018-minigame-play.sh` — **23/23 against the live stack**:
  not_started → init (server-random) → reveal → invalid_type → advance →
  bystander denial ×5 → complete (draw) + idempotency.

### Flutter MISTAKE blocks
- **MISTAKE (screen auth):** `TruthDareScreen` first read the current user
  from `authServiceProvider.auth.currentUser` (Supabase client) which is
  null in the hermetic harness — the screen always showed the "waiting"
  state. Fixed to `authStateProvider` (the riverpod seam the rest of the app
  uses).
- **MISTAKE (fake state loss):** widget/integration fakes' `reveal` set the
  state but `getMinigameGameState` returned a fresh un-revealed row, so
  `invalidateSelf()` after reveal wiped the prompt. Fakes must hold a
  mutable `_current` row like the real DB.
- **MISTAKE (opt-018 unbound var):** cleanup referenced `$SESSION_ID` under
  `set -u` before assignment → "unbound variable". Guarded `${SESSION_ID:-}`.

### Commands run (Flutter layer)
```bash
flutter gen-l10n
dart analyze lib test integration_test          # 0 issues
make test-feature FEATURE=minigames             # 145 pass
make test-file FILE=test/meta/conventions_test.dart
flutter test -d macos integration_test/truth_dare_flow_test.dart   # pass
flutter test -d macos integration_test/minigames_flow_test.dart    # pass (fake extended)
bash test/opt-018-minigame-play.sh              # 23/23 (stack up, migration 150 applied)
bash -n test/opt-018-minigame-play.sh
```
