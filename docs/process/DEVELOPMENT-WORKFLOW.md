# Samay — Development Workflow

**The day-to-day developer + agent workflow.** How to take a task from idea
to merged work: the task cycle, the file semaphore, what tests every change
must ship, which ports/env rules apply, and how to keep the codebase
extensible.

Authoritative companions: `AGENTS.md` (methodology, ports) and
`docs/process/FILE-OWNERSHIP.md` (path ownership map).

---

## 1. The standard task cycle (PLAN → PREP → RED → GREEN → REFACTOR → VALIDATE → DOCUMENT)

### 1.1 PLAN

- Read the as-is references first: `<private-ops-repo>/DATABASE.md` (DB catalog),
  `<private-ops-repo>/BACKEND.md` (Go CLI/API surface), and `docs/specs/steps/`
  (specs for steps not yet implemented).
- Read `docs/specs/steps/cross-references.md` for your step's dependencies and
  current statuses.
- Break the task into small, reviewable steps; each step = one cycle.
- Run `tools/agent_lock.sh list` to see who is currently working where.

### 1.2 PREP

- If the session deserves a record, create
  `docs/history/phase-XX/YYYY-MM-DD_<slug>.md` (create the dir if needed;
  it may not exist yet).
- Agents: `export AGENT_NAME=<your-id>` once per session so every lock command
  is consistent.

### 1.3 RED — write the failing test first

TDD is non-negotiable: **no implementation code without a failing test first.**
Write tests at every layer your change touches, but respect the **test-layer
budget (max 2–3 layers per change)** — pick the smallest set that covers the
behavior, never the same assertion twice across layers:

| Layer | Where | When |
|---|---|---|
| Dart unit | `test/`, mirroring `lib/` layout | pure logic / services |
| Dart widget (functional) | `test/features/<feature>/` | UI behavior (interaction, state) — MUST assert service/HTTP wiring (`when`/`verify` or the real `harnessHttp.sent*` contract), never a bare render |
| Flutter integration | `integration_test/<module>_flow_test.dart` (register in `runner.sh` after its data deps) | ONE flow per feature |
| Backend behavior | `test/opt-NNN-desc.sh`, picked up automatically by `test/run_all_backend.sh` | API/RLS/security |
| Go | `*_test.go` next to the code (`httptest` mocks for PostgREST) | CLI/API server logic |
| SQL | pgTAP case in `supabase/tests/schema_test.sql` (+ byte-identical mirror in `supabase-testing/tests/`) | schema/RLS/RPC |

**Suckless test policy (2026-08-28):** only FUNCTIONAL tests ship in `test/`
— logic, contract, and HTTP-to-Supabase-harness wiring (`harnessHttp.sent*`).
NO UI-only tests: no per-screen render / empty-state-copy / loading-skeleton /
`renders without overflow` / `takeException()==null` smoke suites, no
visual-pin files, no whole-file screen-render suites. Every widget test must
assert a behavior or wiring, never that a widget merely rendered.
`test/meta/conventions_test.dart` enforces this. Token values are pinned once
in `test/theme/app_theme_test.dart`; feature tests assert behavior
(token-budget, 2026-08-27).

Run the new test and confirm it fails for the *right* reason.

**UI-only exception** (per `AGENTS.md` §TDD Rules): pure visual/layout changes
(styling, tokens, spacing, text placement) with no behavior or data-flow impact
skip RED/GREEN. They still keep the behavior/widget tests green, and MUST NOT
add visual-pinning assertions (token-budget, 2026-08-27).

### 1.4 GREEN — implement the minimum

- Minimum code to pass the tests; no gold-plating, no drive-by refactors.
- **Lock before you edit** (§2); release after.
- Iterate with the **focused loop** (§1.6), not the full suite.

### 1.5 REFACTOR

- Follow `analysis_options.yaml` lints / `flutter_lints`; no commented-out or
  dead code; no `print` (use `AppLogger`).
- Keep the change minimal and focused on the assignment.

### 1.6 VALIDATE

- **Default iteration loop (explicit directive 2026-08-27):** run ONLY the
  tests your change touches — `make test-file FILE=<path>` /
  `make test-feature FEATURE=<name>` / `make test-files FILES="a b"` /
  `go test ./...`. This is the day-to-day loop; do NOT auto-run the full
  matrix on every iteration.
- **Full gate** (`make check` + `make test`) runs ONLY when the human
  explicitly asks for a full validation — e.g. before marking a phase
  complete or before a commit that touches broad surface area.
- Stack-dependent suites when infra changed or backend behavior was touched:
  `bash test/run_all_backend.sh` and `supabase db test` (need the Docker stack up).
- Baseline numbers live in `README.md` §Testing summary — update them in the
  same commit if your change moved them.
- Update `docs/specs/steps/cross-references.md` statuses if a step's state changed.

### 1.7 DOCUMENT

Write the daily log entry (created in PREP): what was built, decisions made
and why, mistakes/gotchas as searchable **MISTAKE** blocks, commands run.
Never commit another session's in-flight work out from under it (§6).

---

## 2. File semaphore — `tools/agent_lock.sh`

Locks exist because multiple agents *and humans* edit this repo concurrently.
**Acquire a lock before editing a file, release after. If someone else holds
it, wait — never edit under a held lock.** Locks live in `repo-locks/`
(gitignored); each lock is an atomic `mkdir`'d directory (crash-safe).

```bash
tools/agent_lock.sh list                         # who holds what
tools/agent_lock.sh status <path>                # LOCKED/FREE + owner
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME"
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"
tools/agent_lock.sh run <path> --owner "$AGENT_NAME" -- <cmd>   # auto-release
```

- Use the same stable `--owner` string for acquire and release.
- Multi-file edit: acquire all locks first, edit, then release all.
- Creating/renaming/deleting a file: lock the path too (both paths on rename).
- Reading/searching and running tests need no lock.
- On acquire timeout (default 1800 s): report `BLOCKED on <path> by <owner>`
  and move on to non-conflicting work. Never barge, never delete another lock.
- Common failure: forgetting to release. Prefer `run` for short operations.

Path→owner assignments are recorded in `docs/process/FILE-OWNERSHIP.md`.

---

## 3. Test conventions

- Dart tests mirror the `lib/` tree; fixtures use real Supabase column names.
- Widget tests that touch `Supabase.instance` initialize it with in-memory
  storages (see the harness in `test/support/` and any existing feature test
  for the pattern). Zero network in unit/widget suites.
- Integration flows are hermetic by default (`integration_test/support/
  fake_supabase.dart`); each file runs standalone and via `runner.sh`.
- curl opt-tests are self-contained: create users via the admin auth API,
  seed via `service_role`, clean up on exit (`trap`), exit 0/1, defaults to
  Kong at `http://127.0.0.1:54386`. Keys come from the environment /
  gitignored `.env.local` files — no secrets committed.
- pgTAP: `plan(N)` must equal the real assertion count (a static guard in
  `test/features/minigames/minigame_rpc_migration_test.dart` +
  `test/features/qr/qr_rpc_migration_test.dart` enforces consistency).
- Migrations live under `supabase/migrations/<domain>/<nn>_<name>.sql` and are
  mirrored byte-identical into `supabase-testing/migrations/`.

Baseline numbers & the new-failure rule: any new failure, analyze issue, or
changed failure set must be explained and fixed by whoever introduced it.
"Matches the baseline" means exactly the same (zero-failure) result recorded
in `README.md`.

---

## 4. Ports & environment

### 4.1 Approved port map (source of truth: AGENTS.md)

Juega's running Supabase owns host ports **5432, 54321, 54323, 8443** — NEVER
map Samay services onto them, and never stop/start Juega containers.

| Service | Port |
|---|---|
| PostgreSQL (direct) | **54382** |
| Studio | **54381** |
| Mailpit (dev email) | **54384** |
| Kong (API gateway) | **54386** |
| Analytics | **54388** |
| Kong HTTPS | **54443** |

After any infra change: `bash tools/check_ports.sh --strict` must exit 0.

### 4.2 Environment & secrets

- App config is injected at BUILD time via `--dart-define-from-file=.env`
  (Makefile handles it); read through `lib/core/config/env_config.dart`.
  `.env` is gitignored and NOT a Flutter asset; `.env.example` holds
  placeholders only.
- Local secret values live in gitignored `.env` / `.env.local` files
  (root + `supabase*/`). They are the source of truth for
  `tools/check_secrets.sh`: if any local secret value appears in a tracked
  file, the gate fails. Never paste real keys into code, tests, or docs.
- Go backend/curl tests read `SUPABASE_URL` / `ANON_KEY` / `SERVICE_KEY` from
  the environment (or gitignored local env files).

---

## 5. Refactorability doctrine

Every change must keep the codebase modular, typed, and easily extensible:

- Features live in `lib/features/<feature>/` nesting
  `screens/ providers/ widgets/ logic/` (`*_screen.dart` → `screens/`,
  `*_provider(s).dart` → `providers/`, widget-only files → `widgets/`,
  pure domain logic → `logic/`). Cross-cutting code lives in `lib/core/`.
- Data flows through typed freezed models — raw maps are a stopgap, not a target.
- Business logic in services/repositories, never in build methods or callbacks.
- No hardcoded tuneable values — configurable things go in `app_config`.
- New behavior ships behind a flag (`AppFeatureFlag` + `FlagGate`) so it can
  be released by config.
- Routes use `RoutePaths.*`; UI uses design tokens (`SamayThemeExtension`);
  state in Riverpod providers.

Reviewer checklist: feature-first placement · typed models · logic outside
widgets · app_config for tuneables · flags for new behavior · typed routes ·
tokens for colors/spacing · tests at every touched layer · integration flow
updated · no commented-out/dead code · `dart analyze` clean · baselines intact.

---

## 6. Commit policy

- Coordinate commits: check `git status` and `tools/agent_lock.sh list` before
  committing so you never sweep away another session's uncommitted work.
- Commit what you actually did; keep unrelated changes out.
- The repo's permission config denies destructive git ops
  (reset/checkout/switch/clean/rebase/merge/am/cherry-pick/pull) for agents;
  humans authorize those explicitly.

---

## 7. Agent report format

Every agent's final message back to the orchestrator should contain:

1. Agent ID + role
2. What was built (bullet list)
3. Files created/modified (with lock evidence)
4. Tests added + results (commands + output summary)
5. Issues found / pre-existing bugs encountered — report, don't fix out-of-scope

---

## 8. Quick reference

```bash
export AGENT_NAME=<your-id>

tools/agent_lock.sh list                         # who holds what
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME"
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"

# DEFAULT iteration loop — run ONLY the tests your change touches:
make test-file FILE=test/features/friends/flow_test.dart   # one file
make test-files FILES="a_test.dart b_test.dart"             # several files
make test-feature FEATURE=friends                           # one feature dir
go test ./...                                               # Go only

# Full gates — ONLY on explicit human request (token-budget 2026-08-27):
make check        # dart analyze + flutter analyze + go vet + ports + secrets
make test         # flutter test + go test ./...
bash integration_test/runner.sh          # hermetic integration suite
bash test/run_all_backend.sh             # curl opt-tests (stack up)
supabase db test                          # pgTAP (stack up)
bash tools/check_ports.sh --strict       # port-map gate
bash tools/check_secrets.sh              # secrets gate (.env-based)
```
