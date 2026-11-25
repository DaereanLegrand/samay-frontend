# Samay — Development Workflow

**The day-to-day developer + agent workflow.** How to take a task from idea
to merged work: the task cycle, what tests every change must ship, which
ports/env rules apply, and how to keep the codebase extensible.

Authoritative companions: `AGENTS.md` (methodology, ports) and
`docs/process/FILE-OWNERSHIP.md` (path ownership map).

---

## 1. The standard task cycle (PLAN → PREP → RED → GREEN → REFACTOR → VALIDATE → DOCUMENT)

### 1.1 PLAN

- Read the as-is references first: the backend repository's schema
  (`supabase/migrations/`) and Go CLI/API surface (`cmd/`, `internal/`).
- Break the task into small, reviewable steps; each step = one cycle.

### 1.2 PREP

- If the session deserves a record, create
  `docs/history/phase-XX/YYYY-MM-DD_<slug>.md` (create the dir if needed;
  it may not exist yet).

### 1.3 RED — write the failing test first

TDD is non-negotiable: **no implementation code without a failing test first.**
Testing is backend-first, but this repo also carries Dart unit tests under
`test/*.dart` for pure logic: the 2026-08-31 "no Dart tests" directive was
rescinded (Q16, `pubspec.yaml` dev_dependencies). Write tests at every layer
your change touches, but respect the **test-layer budget (max 2–3 layers per
change)** — pick the smallest set that covers the behavior, never the same
assertion twice across layers:

| Layer | Where | When |
|---|---|---|
| Backend behavior | `test/opt-NNN-desc.sh` (backend repo) | API/RLS/security |
| Go | `*_test.go` next to the code (`httptest` mocks for PostgREST) | CLI/API server logic |
| SQL | pgTAP case in the backend repo's `supabase/tests/schema_test.sql` (single stack) | schema/RLS/RPC |
| Dart logic | `test/*.dart` in this repo (e.g. `local_match_test.dart`) | pure app logic |

Run the new test and confirm it fails for the *right* reason.

### 1.4 GREEN — implement the minimum

- Minimum code to pass the tests; no gold-plating, no drive-by refactors.
- Iterate with the **focused loop** (§1.6), not the full suite.

### 1.5 REFACTOR

- Follow `analysis_options.yaml` lints / `flutter_lints`; no commented-out or
  dead code; no `print` (use `AppLogger`).
- Keep the change minimal and focused on the assignment.

### 1.6 VALIDATE

- **Quick reference (this repo):**
  - `flutter test` — the Dart unit suite.
  - `dart analyze` — analyzer, zero issues.
  - `make analyze` — same as `dart analyze`.
  - `make test` — the static Makefile gate (`test/opt-008-makefile-static.sh`).
  - `make check` — `secrets` + `ruby-toolchain` prerequisites, then
    `dart analyze` + `flutter analyze`.
- **Default iteration loop:** run ONLY the checks your change touches. Do NOT
  auto-run the full matrix on every iteration.
- **Full gate** (`make check` + `make test`) runs ONLY when the human
  explicitly asks for a full validation — e.g. before marking a phase
  complete or before a commit that touches broad surface area.
- **Backend suites live in the backend repo:** `go test ./...`,
  `bash test/opt-*.sh`, `make test db|api` there (they need the Docker stack up).
- Baseline numbers live in `README.md` §Testing — update them in the
  same commit if your change moved them.

### 1.7 DOCUMENT

Write the daily log entry (created in PREP): what was built, decisions made
and why, mistakes/gotchas as searchable **MISTAKE** blocks, commands run.
Never commit another session's in-flight work out from under it (§6).

---

## 2. Editing coordination

This is a single-repo workflow and no lock tool ships in this repo. When more
than one agent or human may be editing, coordinate through the human: check
`git status` before you start, keep your edits scoped to the task, and never
sweep away another session's uncommitted work.

Path→owner assignments are recorded in `docs/process/FILE-OWNERSHIP.md`.

---

## 3. Test conventions

- curl opt-tests are self-contained: create users via the admin auth API,
  seed via `service_role`, clean up on exit (`trap`), exit 0/1. In the backend
  repo they default to Kong at `http://127.0.0.1:54396`. Keys come from the
  environment / gitignored local env files — no secrets committed.
- Migrations live under `supabase/migrations/<domain>/<nn>_<name>.sql` (single
  stack, in the backend repo).

Baseline numbers & the new-failure rule: any new failure, analyze issue, or
changed failure set must be explained and fixed by whoever introduced it.
"Matches the baseline" means exactly the same (zero-failure) result recorded
in `README.md`.

---

## 4. Ports & environment

### 4.1 Approved port map (backend-owned)

The reference app's running Supabase owns host ports **5432, 54321, 54323,
8443** — NEVER map Samay services onto them, and never stop/start the reference
app containers.

`ENV=testing` layout (the backend repo's `testing.env`):

| Service | Port |
|---|---|
| PostgreSQL (direct) | **54382** |
| Studio | **54381** |
| Mailpit (dev email) | **54384** |
| Kong (API gateway) | **54386** |
| Analytics | **54388** |
| Kong HTTPS | **54443** |

`ENV=testing-local` layout (the backend repo's `testing-local.env`, the local
dev stack): PostgreSQL **54392**, Studio **54391**, Mailpit **54394**, Kong
**54396**, Kong HTTPS **54453**.

### 4.2 Environment & secrets

- App config is injected at BUILD time; read through
  `lib/core/config/env_config.dart`. `ENV=testing-local` reads the backend's
  `../backend/.env/testing-local.env`; the release ENVs (`testing`, `staging`,
  `prod`) read the vault `dart_defines.env` on the RAM disk.
- There is no `.env`, and no `.env.example`, in this repo. The gitignored
  `.env.local` holds developer overrides only (e.g. `IOS_DEVELOPMENT_TEAM`).
- Secrets never appear in tracked files. `tools/check_secrets.sh` scans the
  local env values (`../backend/.env/testing-local.env`, `.env.local`) against
  tracked files plus shape checks.

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
tokens for colors/spacing · tests at every touched layer (Go `*_test.go`,
pgTAP, opt-test in the backend repo; pure-logic Dart tests in `test/*.dart`)
· no commented-out/dead code · `dart analyze` clean · baselines intact.

---

## 6. Commit policy

- Coordinate commits: check `git status` before committing so you never sweep
  away another session's uncommitted work.
- Commit what you actually did; keep unrelated changes out.
- The repo's permission config denies destructive git ops
  (reset/checkout/switch/clean/rebase/merge/am/cherry-pick/pull) for agents;
  humans authorize those explicitly.

---

## 7. Agent report format

Every agent's final message back to the orchestrator should contain:

1. Agent ID + role
2. What was built (bullet list)
3. Files created/modified
4. Tests added + results (commands + output summary)
5. Issues found / pre-existing bugs encountered — report, don't fix out-of-scope

---

## 8. Quick reference

```bash
# This repo — run ONLY the checks your change touches:
flutter test                             # Dart unit suite
dart analyze                             # analyzer

# Full gates — ONLY on explicit human request:
make analyze     # dart analyze
make test        # static Makefile gate (test/opt-008-makefile-static.sh)
make check       # secrets + ruby-toolchain, then dart analyze + flutter analyze

# Backend suites live in the backend repo:
#   go test ./...
#   bash test/opt-*.sh
#   make test db|api
```
