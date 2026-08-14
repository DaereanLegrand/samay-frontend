# Samay — Development Workflow

**The day-to-day developer + agent workflow.** This document is the definitive how-to for
humans and agents working in this repo: how to take a task from idea to merged work, how the
file-semaphore works, what tests every change must ship, which ports/env rules apply, how to
keep the codebase extensible, and what the orchestrator does at checkpoints.

Authoritative sources this document mirrors (do not contradict them):

- `AGENTS.md` — methodology, port convention, orchestration protocol
- `docs/process/DEVELOPMENT-WORKFLOW.md` — mandatory rules for every spawned agent (read this too)
- `docs/process/DEVELOPMENT-WORKFLOW.md` — the 180-agent campaign plan
- `docs/process/FILE-OWNERSHIP.md` — who owns every path
- `test/README.md` — full test matrix + curl test-writing guide

---

## 1. The standard task cycle (PLAN → PREP → RED → GREEN → REFACTOR → VALIDATE → DOCUMENT)

Every task — human or agent — follows the 7-step cycle from `AGENTS.md`, enriched below with
the orchestration specifics (locks, test suites, checkpoints). Skip nothing; the cycle is what
keeps 180 agents from clobbering each other.

### 1.1 PLAN

- Read the specs first: `docs/specs/product/` (product/CLI/web-server specs, read-only) and
  `docs/specs/steps/` (step specs, read-only).
- Read `docs/specs/steps/cross-references.md` to find your step's direct dependencies and
  check their `*.DONE` markers in `docs/history/phase-XX/`. A step with unmet deps is
  blocked — do not start it.
- Check `docs/process/FILE-OWNERSHIP.md` for every path you will touch. If a file is owned by
  another agent, you may only modify it if your assignment requires it (and you hold its lock).
- Break the task into small, reviewable steps. Each step = one cycle through the workflow.
- Run `tools/agent_lock.sh list` to see who is currently working where.

### 1.2 PREP

- Create/verify the phase log directory `docs/history/phase-XX/`.
- Create your daily log file for today: `docs/history/phase-XX/YYYY-MM-DD_<ID>-<slug>.md`.
  **Create the log file before any code** — you will fill it in step 7.
- Agents: `export AGENT_NAME=<your-id>` once per session so every lock command is consistent.

### 1.3 RED — write the failing test first

TDD is non-negotiable: **no implementation code without a failing test first.** The test
defines what "correct" means; implementation makes it pass.

Write tests at **every layer your change touches** (see §3):

| Layer | Where | Example |
|---|---|---|
| Dart unit/widget | `test/`, mirroring `lib/` | `test/features/groups_screens_test.dart` |
| Flutter integration | `integration_test/<module>_flow_test.dart` (I-01, 2026-08-09) | `integration_test/events_flow_test.dart` |
| Backend behavior | `test/opt-NNN-desc.sh` + registered in `test/run_all_backend.sh` | `test/opt-001-rls-security.sh` |
| Go | `*_test.go` next to the code | `internal/ops/users_test.go` |
| SQL | `supabase/tests/schema_test.sql` (pgTAP) | one `SELECT ok(...)` per assertion |

Run the new test and confirm it fails for the *right* reason. If it fails for a wrong reason
(setup bug, environment), fix the test — a red test must be red because the behavior is
missing, not because the harness is broken.

### 1.4 GREEN — implement the minimum

- Write the minimum code to pass the tests. No gold-plating, no "while I'm here" refactors.
- **Lock before you edit** (see §2). Hold the lock for the whole edit; release after.
- Run the focused test suite as you go (e.g. `flutter test test/features/groups_screens_test.dart`),
  not the whole matrix, until step 6.

### 1.5 REFACTOR

- Clean up: follow Go/Flutter conventions (`analysis_options.yaml` lints, `flutter_lints`),
  no commented-out code, no dead code, no `print` (use the logger once I-05 lands it).
- Spanish UI strings stay inline until localization (I-14/I-15); then move to ARB.
- Keep the change minimal and focused on your assignment.

### 1.6 VALIDATE

- Run **all** relevant suites (§3) — the ones your change can affect, plus the full Flutter and
  Go suites. The validation gate is: `make test` (now `test-all`: flutter unit/widget + Go +
  backend static gates opt-005/opt-007 + hermetic integration suite) and `make check`
  (`dart analyze` + `flutter analyze` + `go vet` + `tools/check_ports.sh --strict`).
- Compare against the documented baseline (§3.6): **2209 pass / 0 failures** (Flutter),
  `go test ./...` green (182 tests), **`dart analyze` 0 issues** (re-verified 2026-08-13). If you see *new*
  failures or *new* analyze issues, they are yours — fix them before moving on.
- Verify against the spec docs (the PLAN checklist).
- Update `docs/specs/steps/cross-references.md` if dependencies changed (D-02 owns the file
  in this campaign — coordinate via its lock if the change is yours to make).
- Update the modular integration suite for everything you touched (§3.2/§3.3).

### 1.7 DOCUMENT

Write the daily log entry (the file you created in PREP) covering:

- What was built
- Decisions made and why
- Mistakes / gotchas encountered (as a **MISTAKE** block — searchable for future devs)
- Commands run (for reproducibility)

Never commit your work (see §6 — the orchestrator commits at checkpoints).

---

## 2. File semaphore — the human guide to `tools/agent_lock.sh`

Locks exist because the repo is edited by many agents *and humans* at once. **Acquire a lock
before editing a file, release it after. If someone else holds it, wait — never edit under a
held lock.** Locks live in `repo-locks/` (gitignored); each lock is an atomic `mkdir`'d
directory (crash-safe), named by a hash of the target path.

### 2.1 Commands

```bash
# See who holds what (read-only, safe anytime)
tools/agent_lock.sh list

# Check a single file
tools/agent_lock.sh status lib/core/router/app_router.dart    # LOCKED: <path> + owner / FREE: <path>

# Acquire before editing. Polls every 2s; default timeout 1800s (30 min).
tools/agent_lock.sh acquire <path> --owner <your-id> [--timeout <seconds>]

# ... edit the file ...

# Release after (only the owner may release)
tools/agent_lock.sh release <path> --owner <your-id>

# One-shot: acquire → run → release automatically (trap-based, release on exit)
tools/agent_lock.sh run <path> --owner <your-id> -- bash -c 'echo working; sleep 1'

# Wait until a lock is free WITHOUT acquiring it
tools/agent_lock.sh wait <path> [--timeout <seconds>]
```

Exit codes: `0` acquired/released/clean · `2` timed out · `3` usage error. `release` of an
unheld lock exits 0; `release` by a non-owner exits 1 (refused).

The `--owner` must be stable: use `AGENT_NAME` (`export AGENT_NAME=I-07-retry`) or your
git/human handle. If you call `acquire` without `--owner`, the script falls back to
`local-<pid>` — your later `release` will match, but anyone reading `list` won't know who you
are. Always pass `--owner`.

### 2.2 When to lock

| Situation | Action |
|---|---|
| Editing/creating a file | Lock the exact path before the first edit, release after the last |
| Multi-file edit | Acquire all locks first (any order), edit, then release all |
| Creating a new file | Lock the new path too (creators own new files — `FILE-OWNERSHIP.md`) |
| Renaming/moving files | Lock both old and new paths |
| Deleting a file | Lock the path, then remove |
| Only reading/searching | No lock needed |
| Running tests/builds | No lock needed |

### 2.3 When blocked

- If `acquire` times out (30 min): report `BLOCKED on <path> by <owner>` in your final report
  and **move on to any non-conflicting part of your assignment**. Never edit anyway.
- If `list` shows an owner you can coordinate with (same team, e.g. `⚙️` co-owner roles in
  FILE-OWNERSHIP), you may `wait` for them or ping the orchestrator — but never barge.
- Blocked ≠ stuck: reorder your work so the locked file is last.

### 2.4 Common mistakes

- **Forgetting to release** — the most common failure. Locks are crash-safe, but a stale lock
  (left by a killed session) blocks everyone until removed. Prefer `run` for short operations;
  it releases on exit via `trap`. If you find a stale lock whose owner is gone, report it to
  the orchestrator — do not silently `rm -rf` another agent's lock.
- **Editing without a lock** — corrupts parallel work and is undetectable until merge time.
- **Releasing with a different `--owner`** — refused with exit 1; use the same owner string for
  acquire and release.
- **Locking with `--owner local-<pid>`** — anonymous locks are unidentifiable in `list`.
- **Holding a lock across unrelated tasks** — lock only what you touch, and release as soon as
  the edit is done; other agents `wait` behind you.
- **`wait` without a subsequent acquire** — `wait` does not acquire. After `wait` returns you
  still need `acquire` (which should now succeed immediately).

---

## 3. Test conventions

### 3.1 Dart unit/widget tests — `test/`

- Mirror the `lib/` layout: `test/features/`, `test/router/`, `test/providers/`,
  `test/services/`, `test/theme/`, `test/widgets/`.
- Naming: `<layer>_test.dart` — `test/features/groups_screens_test.dart`,
  `test/widgets/v_button_test.dart`, `test/router/route_paths_test.dart`.
- One test file per feature/layer area; group tests per widget/screen with `group('X', ...)`.
- Run: `flutter test` (or a single file while iterating).
- Test fixtures mirror real Supabase data shapes (`Map<String, dynamic>` rows, real column
  names).
- Widget tests that touch `Supabase.instance` must initialize it with **in-memory storages**
  in `setUpAll` (see the H-01 harness in
  `docs/history/phase-02-flutter-foundation/2026-07-30_H01-coming-soon-screens.md` —
  `Supabase.initialize(url: ..., anonKey: ..., authOptions: FlutterAuthClientOptions(
  localStorage: _MemoryStorage(), pkceAsyncStorage: _MemoryAsyncStorage(), ...))`). The 23
  pre-existing failures caused by *not* doing this are documented baseline (H-01 log), not your template.

### 3.2 Flutter modular integration suite — `integration_test/`

> **Landing status:** created by **I-01** (2026-08-09). Scaffold and the
> template flow (`auth_flow_test.dart`) are live — when you work on a feature,
> **add your flow file here**. The suite is **hermetic by default** (in-memory
> Supabase harness, no live server), so it is CI-safe and every file runs
> standalone.

**Layout:**

- **One file per module/feature**: `integration_test/auth_flow_test.dart`,
  `integration_test/events_flow_test.dart`, `integration_test/chat_flow_test.dart`, …
  (18 registered flows in `runner.sh`; ghost entries removed with an in-file note)
- **`integration_test/README.md`** — philosophy, prerequisites, per-file and
  whole-suite run instructions, and the template for new flow files.
- **`integration_test/runner.sh`** — whole-suite orchestrator: runs every
  existing flow in **dependency-safe order** (auth → profile → friends →
  groups → events → chat → …; missing files are skipped), prints a pass/fail
  summary, exits 0/1. Hermetic by default; `-d <device-id>` for on-device runs.
- **`integration_test/support/`** — shared helpers:
  - `fake_supabase.dart` — in-memory Supabase harness (`MemoryLocalStorage`,
    `MemoryAsyncStorage`, `initFakeSupabase()`, `FakeAuthNotifier`) — the
    pattern proven in `test/router/app_router_test.dart` (H-01). Zero network,
    zero plugins.
  - `test_app.dart` — boots the **real app** (`SamayApp`: real router, real
    theme, real screens) inside a fresh `ProviderContainer` whose only override
    is the deterministic fake auth notifier (`newTestContainer`,
    `pumpTestApp`).
  - `test_users.dart` — OPT-IN helpers to create/clean test users against a
    real local stack (Kong `54386`) via the admin API; `isLocalStackUp()`
    lets live flows skip cleanly when the stack is down.

**Each file independently runnable:**

```bash
flutter test integration_test/auth_flow_test.dart            # hermetic, no device
flutter test integration_test/auth_flow_test.dart -d <device> # on device/emulator
bash integration_test/runner.sh                              # whole suite, hermetic
bash integration_test/runner.sh -d <device-id>               # whole suite, on device
```

**Rules for every flow file** (details + template in `integration_test/README.md`):

- Deterministic: fake the auth state synchronously (`newTestContainer`),
  never leave timers that don't resolve, always `pumpAndSettle`.
- Navigate with `RoutePaths.*` only.
- Hermetic flows never touch the network; live-stack flows use
  `test_users.dart` and skip themselves when the stack is unreachable.
- New flow files go into `runner.sh`'s `ORDERED_FLOWS` **after their data
  dependencies**.
- **Every feature ships its flow file here** — this is the end-to-end evidence
  that the feature works, not just in the widget harness (§3.2).

### 3.3 Backend curl opt-tests — `test/opt-NNN-*.sh`

- **Naming**: `test/opt-NNN-description.sh` (e.g. `opt-001-rls-security.sh`). **opt-001..008
  exist** (I-76/I-77/8a2f82d): live suite = 001 (RLS/security), 002 (events), 003 (chat/E2EE),
  004 (photos), 006 (minigames/QR); static gates = 005 (seed-dev), 007 (compose/parity),
  008 (Makefile). `test/run_all_backend.sh` globs every `opt-*.sh`.
- **Self-contained**: create their own test users via the admin auth API, seed via
  `service_role`, run assertions as anon/authenticated, clean up on exit (`trap`).
- **Exit contract**: `exit 0` on success, `exit 1` on failure. Each file runs standalone:
  `bash test/opt-001-rls-security.sh`.
- **Registered**: every `opt-*.sh` in `test/` is picked up automatically by
  `test/run_all_backend.sh` (glob `test/opt-*.sh`), which reports a summary and exits 0/1.
  New opt-tests need no registration beyond existing as a file — but keep the `opt-NNN-`
  numbering sequential.
- Defaults: `SUPABASE_URL=http://127.0.0.1:54386` (Kong, approved port), with dev keys as
  defaults; override via `SUPABASE_URL`/`ANON_KEY`/`SERVICE_KEY` env vars.
- The full curl helper anatomy (anon/auth/service_role patterns, response interpretation,
  `42501`/`PGRST204` denial semantics, test-setup pattern) is in `test/README.md` — read it
  before writing a new opt-test.
- Prerequisites to run: the self-hosted stack up (`make supabase-docker-start` /
  `supabase-docker-reset`) — the approved port map is live since I-02/M-01..M-10 (see §4.1).

### 3.4 Go tests — `*_test.go`

- Standard `go test ./...` (182 tests as of 2026-08-13 — 82 at the campaign baseline).
- CLI flag/validation behavior tested in `cmd/samay-admin/*_test.go`; business logic in
  `internal/ops/*_test.go` against `net/http/httptest` servers (see
  `internal/ops/users_test.go` — `newTestClientWithLog` returns a fake PostgREST server and a
  request log; assert paths, query strings, payloads, and response parsing).
- Run via `make test` together with Flutter, or standalone: `go test ./...`.

### 3.5 SQL — pgTAP `supabase/tests/schema_test.sql`

- One pgTAP file per stack: `supabase/tests/schema_test.sql` and the mirrored
  `supabase-testing/tests/schema_test.sql` (keep them structurally identical; the only
  allowed difference is the header migration-count note).
- **`plan(N)` must equal the actual number of test SELECTs.** Count rule: `SELECT` lines in
  the file minus the `plan(...)`, minus `finish()`, minus any *nested* SELECTs inside
  `ok(NOT EXISTS (...))`-style expressions. (D-04 verified 129 after the signup_tracker sync;
  the suite grew to plan 385 with I-77/S-03 + the 20260814 migration set.)
  When you add assertions, update the plan count — a mismatched plan makes pgTAP fail loudly.
- Run: `supabase db test` (requires the stack + CLI; use `make supabase-db-test` for the
  self-hosted stack with `--db-url`, or the psql fallback in the Makefile — ports are live, §4.1).
- Extend this file for every new migration; keep seed-count assertions in sync (38
  `app_config` keys, 1 system admin).

### 3.6 Baseline numbers & the new-failure rule

| Suite | Command | Baseline |
|---|---|---|
| Flutter unit/widget | `make flutter-test` | **2209 pass / 0 failures** (re-verified 2026-08-13) |
| Go | `go test ./...` | green (182 tests, 5 packages) |
| Static analysis | `make flutter-analyze` | **0 issues** |
| Backend curl | `bash test/run_all_backend.sh` | **8/8 opt-tests** (needs the stack up + migrated) |
| pgTAP | `supabase db test` | **385 assertions** (needs the stack up; psql fallback documented in the Makefile) |

No pre-existing failures remain (I-47 fixed the 23; the pgTAP plan-consistency guard tests
were updated for the 385-assertion suite in 2026-08-13).

**Rule:** any new failure, new analyze error, or changed failure *set* must be explained and
fixed by the agent/human who introduced it. "Matches the baseline" means *exactly* the same
failure set in the *same files* — not "the same count" (today: zero failures).

---

## 4. Ports & environment

### 4.1 Approved port map (AGENTS.md — source of truth)

Juega's running Supabase owns host ports **5432, 54321, 54323, 8443** — NEVER map Samay
services onto them, and never stop/start Juega containers. Samay's approved map:

| Service | Port | Notes |
|---|---|---|
| PostgreSQL (direct) | **54382** | moved off 5432 (Juega pooler conflict) |
| Studio | **54381** | |
| Mailpit (dev email) | **54384** | |
| Kong (API gateway) | **54386** | REST + Auth + Realtime + Storage route here; opt-tests default here |
| Analytics | **54388** | |
| Kong HTTPS | **54443** | self-hosted compose stack |

**Current state (2026-08-13): remap landed.** `supabase/config.toml` (both stacks) uses
54386/54382/54381/54384/54388, and both `docker-compose*.yml` sets map
`${POSTGRES_PORT:-54382}:5432`, `${KONG_HTTP_PORT:-54386}:8000`, `${KONG_HTTPS_PORT:-54443}:8443`,
`${STUDIO_PORT:-54381}:3000` — no Juega-port conflicts remain. You may run
`docker compose up` / the Makefile supabase targets at any time.
`tools/check_ports.sh --strict` (D-01's script) exits 0.

### 4.2 `.env` vs `--dart-define`

- **Current state:** config is passed at BUILD time via `--dart-define` /
  `--dart-define-from-file=.env` (Makefile `FLUTTER_DEFINES`, `define-env`) and read by
  `lib/core/config/env_config.dart` (`const String.fromEnvironment`) — landed by I-34/M-13.
  `.env` is NOT a Flutter asset; `.env.example` holds placeholders only
  (`http://127.0.0.1:54386` + `your_supabase_anon_key_here`).
- **Rule of thumb:**
  - Local development: `cp .env.example .env`, fill the two Supabase vars, run. Never commit `.env` (gitignored).
  - Builds/CI/anything shipped: pass real values at build time with `--dart-define`, and never embed secrets.
  - Never put secrets in code, tests, or docs — placeholder values only.
- Backend/CLI: `internal/db` and the opt-tests read `SUPABASE_URL`/keys from the environment
  or their defaults — `.env` is app-only.

### 4.3 Juega coexistence rules

- Juega is **read-only reference** (`/Users/daerean/Codes/apps/Juega`) — you may read it for
  UI/flow patterns (Phase 4.4), never modify it.
- Never use Juega's ports (5432/54321/54323/8443) for Samay services.
- Never run docker commands that touch Juega's stack; never stop/start its containers.
- If you must start Samay's stack, the compose mappings are already on the approved map
  (see §4.1) — re-verify with `tools/check_ports.sh --strict` after any infra change.

---

## 5. Refactorability doctrine — how to keep Samay extensible

> **User requirement:** features will keep being added *after* this campaign. Every change
> must keep the code modular, typed, and easily extensible. `AGENTS.md` and the
> I-49..I-78 workstreams build the foundations below — when they land, use them.

| Foundation | Status | What it means for new code |
|---|---|---|
| Feature-first dirs | now | `lib/features/<feature>/` nests `screens/ providers/ widgets/ logic/` subdirs (M-23, 2026-08-10 — ARC-01; only non-empty subdirs exist; `*_screen.dart` → `screens/`, `*_provider(s).dart` → `providers/`, widget-only files → `widgets/`, pure domain logic → `logic/`); `lib/core/` holds cross-cutting code |
| Design tokens | now (I-16, U-01..U-03) | colors/typography/spacing/radius via `lib/core/design_tokens/` — never inline magic colors (SamayThemeExtension + SamayDurations) |
| Typed models | now (I-10, freezed) | data shapes in `lib/core/models/` (freezed, `*.freezed.dart`/`*.g.dart` generated) — raw `Map<String, dynamic>` is the documented *stopgap*, not the target |
| Feature services + repositories | now (I-11, I-50) | business logic in feature-scoped services / `lib/core/repositories/`, not in widgets; screens stay dumb |
| Feature flags | now (I-49, I-69) | new behavior ships behind a flag (`lib/core/config/feature_flags.dart` + `FlagGate`) and can be released by config, dark-first |
| Route registration | now | register routes in `lib/core/router/route_paths.dart` (constants/builders) + `app_router.dart`; never raw path strings in call sites |
| Tuneable values | now | economy/QR/limit constants go in `app_config` (admin: `./samay config set <key> <value> --confirm`) — never hardcode them |
| Riverpod state | now | state in providers (`lib/core/providers/`, `lib/features/**/providers`), not in `StatefulWidget` locals where a provider fits |

**Reviewer checklist** (used by agents reviewing their own work and by code reviewers):

- [ ] The feature lives in `lib/features/<feature>/`; nothing feature-specific leaked into `lib/core/`
- [ ] Data flows through typed models (freezed once I-10 lands) — no raw maps in widget APIs
- [ ] Business logic is in services/repositories, not in build methods or button callbacks
- [ ] No hardcoded tuneable values — everything configurable is in `app_config`
- [ ] New behavior is feature-flagged (once I-49 lands) or at least isolated behind a single seam
- [ ] Routes use `RoutePaths.*`; no raw `context.push('/...')` / `context.go('/...')` / `path: '/...'` literals outside `route_paths.dart`
- [ ] UI uses design tokens / `SamayTheme`; no ad-hoc colors
- [ ] Tests ship for the change at every touched layer, and the integration suite was updated
- [ ] No commented-out code, no dead code, no `print`, no untyped `dynamic` leaks where types exist
- [ ] `dart analyze` clean of new issues; test baseline unchanged

---

## 6. Commit & checkpoint policy

- **Agents never commit, never push, never `git add`/`git reset`/`git checkout` that could
  destroy another agent's uncommitted work.** Leave everything in the working tree.
- **The orchestrator validates, then commits AND pushes at every 50-agent stop:**
  STOP-50 (mid-4.2), STOP-100 (mid-4.3), STOP-150 (mid-4.4), STOP-180 (end of campaign).
- At each stop the orchestrator runs `dart analyze`, `flutter test`, `go test ./...`,
  fixes regressions introduced by the batch, commits, and pushes to branch `fixes`.
- Humans working outside the campaign may commit their own work following normal repo
  etiquette — but during the campaign, coordinate with the orchestrator so uncommitted
  agent work is never swept away.
- The campaign's per-agent docs (`AGENT-RULES.md`, `ORCHESTRATION.md`,
  `AGENT-REGISTRY.md`) were removed after STOP-180 (2026-08-11); this document is
  the single standing protocol for humans and agents.

---

## 7. Agent report format

Every agent's final message back to the orchestrator must contain (§7 of this document):

1. **Agent ID + role**
2. **What was built** (bullet list)
3. **Files created/modified** — each with lock acquire/release evidence
4. **Tests added + results** — commands run + output summary
5. **Sources consulted** (URLs for industry-standard research)
6. **Issues found / pre-existing bugs encountered** — do NOT fix out-of-scope things; report them

Report blocks such as `BLOCKED on <path> by <owner>` in the same format, with the non-conflicting
work you completed instead.

---

## 8. Quick reference (command cheatsheet)

```bash
export AGENT_NAME=<your-id>                      # stable owner string

tools/agent_lock.sh list                         # who holds what
tools/agent_lock.sh status <path>                # LOCKED/FREE + owner
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME"
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"
tools/agent_lock.sh run <path> --owner "$AGENT_NAME" -- <cmd>

flutter test                                     # unit/widget (2209 pass / 0 fail)
dart analyze                                     # 0 issues
go test ./...                                    # 182 pass
make test                                        # make test-all: unit + go + static gates + integration
make flutter-analyze                             # dart analyze
make check                                       # dart analyze + flutter analyze + go vet + check_ports --strict
bash test/run_all_backend.sh                     # curl opt-tests (needs stack up)
supabase db test                                 # pgTAP schema_test.sql (needs stack; --db-url per Makefile)
bash tools/check_ports.sh --strict               # port-map gate (must exit 0)
```
