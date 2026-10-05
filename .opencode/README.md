# `.opencode/` — project configuration for opencode sessions

This directory gives every opencode session in this repo the Samay project
context and the standing development protocol **automatically**.

## What loads automatically

| File | Effect |
|---|---|
| `opencode.json` | **Project config**: `instructions` inject AGENTS.md + `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md` into every session; `permission.bash` denies destructive git operations (commit/push allowed on human request, see below). |
| `agents/*.md` | Three subagents (see table below) + `samay` primary agent. Subagents are invoked via `@mention`; `samay` is a primary agent you can switch to with Tab. |
| `README.md` | This file — how the config works and how the lock protocol is surfaced. |

## The lock protocol is surfaced three ways

1. **Instructions:** every session loads AGENTS.md (file-semaphore section),
   `docs/process/DEVELOPMENT-WORKFLOW.md` (§2 lock guide) and
   `docs/process/FILE-OWNERSHIP.md` (ownership map) as system instructions —
   the semaphore (`tools/agent_lock.sh acquire/release/list`) is part of the
   model's context before the first message.
2. **Permissions:** `opencode.json` keeps all tools on opencode defaults but
   **denies the destructive git operations** —
   `git pull/am/cherry-pick/rebase/merge/reset/checkout/switch/clean/stash`.
   `git commit`/`git push` are **allowed on explicit human request**
   (the human authorizes commits in-session). File-write discipline stays
   rule-driven (DEVELOPMENT-WORKFLOW.md §2) rather than permission-driven:
   the lock, not the tool, arbitrates parallel edits.
3. **The `samay` agent** re-states the full protocol in its system prompt
   (read-first mandate, semaphore, backend-only testing, commit policy,
   report format) for any session that switches to it.

## Agents

| Agent | Mode | Purpose | Tools |
|---|---|---|---|
| `@reviewer` | subagent | Sign-off gate: `go test ./...` + `dart analyze` + `go vet`, then code review per DEVELOPMENT-WORKFLOW.md §5 | read/grep/glob + gate commands only (`edit`/`write` denied) |
| `@docs-verifier` | subagent | Doc↔code consistency: README baselines, cross-references statuses, security/design/infra claims, port map | read/grep/glob + `rg`/`git grep` only (`edit`/`write` denied) |
| `samay` | primary | Full DEVELOPMENT-WORKFLOW workflow for implementation work (Tab to switch) | all tools; destructive git ops denied, commit/push on human request |

## Testing architecture (directive 2026-08-31)

- **Testing is reserved for the backend**, or per task there are **no
  integration tests**.
- The Flutter/Dart test trees were **deleted**: `test/*.dart` (unit/widget/
  provider/router/theme suites), `integration_test/` (all flows + `runner.sh`),
  and `test_driver/`. They must NOT be recreated.
- What remains: **Go tests** (`go test ./...`, `internal/` + `cmd/`
  `*_test.go`), **pgTAP** (`supabase/tests/schema_test.sql`,
  `supabase/tests/schema_test.sql`), and **curl opt-tests**
  (`test/opt-NNN-*.sh`, runner `test/run_all_backend.sh`). The backend curl
  tests and pgTAP need the self-hosted stack up (approved ports 54382/54386).
- No `make flutter-test` / `make test-file` / `make test-feature` /
  `make test-integration` targets exist anymore. `make test` = `go test
  ./...` + the static opt gates.
- Backend-only TDD: Go changes ship `*_test.go`; SQL changes extend pgTAP;
  REST/RLS changes ship a curl opt-test. No Flutter test-first cycle exists.

## Notes & decisions

- **Suckless test policy (2026-08-28)** is superseded by the 2026-08-31
  backend-only directive: the Flutter `test/` tree was deleted wholesale.
- **Focused test loop** no longer applies to Flutter. Backend iteration:
  `go test ./...` for Go, `bash test/opt-NNN-<name>.sh` for a single curl
  opt-test, `bash test/run_all_backend.sh` for the suite (stack up).
- **`.agents/` was NOT created** (documented decision). the reference app's `.agents/`
  holds portable *skills* (the supabase + supabase-postgres-best-practices
  `SKILL.md` packages), not project agent definitions — and the same skills
  already exist user-wide in `~/.agents/skills/`. Samay's project-specific
  needs are fully covered by `.opencode/` + `docs/process/`; an empty
  `.agents/` would be a placeholder dir. If a portable skill is ever needed,
  install it at the user level or vendor it with real content.
- The guard `test/meta/conventions_test.dart` was deleted with the Flutter
  test tree (2026-08-31); repo conventions are now documented in
  `docs/process/` and enforced by the reviewer/security-check agents.
- Config format follows the opencode docs (opencode.ai/docs/config,
  /agents, /permissions); `.opencode/opencode.json` is a documented
  project-config location.
