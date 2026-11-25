# `.opencode/` — project configuration for opencode sessions

This directory gives every opencode session in this repo the Samay project
context and the standing development protocol **automatically**.

## What loads automatically

| File | Effect |
|---|---|
| `opencode.json` | **Project config**: `instructions` inject AGENTS.md + `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md` + the standing-rule docs (`DEV-SERVER.md`, `SIMULATORS.md`) into every session; `permission.bash` denies destructive git operations (commit/push allowed on human request, see below) and simulator spawning. |
| `agents/*.md` | Three subagents (see table below) + `samay` primary agent. Subagents are invoked via `@mention`; `samay` is a primary agent you can switch to with Tab. |
| `DEV-SERVER.md` | **Standing rule**: never kill/restart the human's `make dev` / `flutter run`, never trigger a reload. |
| `SIMULATORS.md` | **Standing rule**: never spawn simulators; always ask which existing device(s) may be used. |
| `README.md` | This file — how the config works and how editing is coordinated. |

## Editing coordination and permissions

1. **Instructions:** every session loads AGENTS.md,
   `docs/process/DEVELOPMENT-WORKFLOW.md` (§2 "Editing coordination") and
   `docs/process/FILE-OWNERSHIP.md` (ownership map) as system instructions.
   No lock tool ships in this repo — coordinate through the human and
   `git status`.
2. **Permissions:** `opencode.json` keeps all tools on opencode defaults but
   **denies the destructive remote/history operations** —
   `git pull/am/cherry-pick/rebase/merge/reset/checkout/switch/clean/stash`.
   `git commit`/`git push` are **allowed on explicit human request**
   (the human authorizes commits in-session). The `samay` primary agent
   enforces the same deny-set in its own permission block.
3. **The `samay` agent** re-states the full protocol in its system prompt
   (read-first mandate, coordination, test policy, commit policy, report
   format) for any session that switches to it.

## Agents

| Agent | Mode | Purpose | Tools |
|---|---|---|---|
| `@reviewer` | subagent | Sign-off gate: `dart analyze` + `flutter analyze` + `flutter test`, then code review per DEVELOPMENT-WORKFLOW.md §5 | read/grep/glob + gate commands only (`edit`/`write` denied) |
| `@docs-verifier` | subagent | Doc↔code consistency: README baselines, cross-references statuses, security/design claims, port map | read/grep/glob + `rg`/`git grep` only (`edit`/`write` denied) |
| `@security-check` | subagent | Secrets + security-posture audit against `docs/security/` | read/grep/glob + `make secrets`/`make check` only (`edit`/`write` denied) |
| `samay` | primary | Full DEVELOPMENT-WORKFLOW workflow for implementation work (Tab to switch) | all tools; destructive git ops denied, commit/push on human request |

## Testing architecture

- **Backend-first.** Go tests (`go test ./...`, `internal/` + `cmd/`
  `*_test.go`), pgTAP (`supabase/tests/schema_test.sql`) and curl opt-tests
  (`test/opt-NNN-*.sh`, runner `test/run_all_backend.sh`) live in the **backend**
  repo and need the self-hosted stack up (`ENV=testing-local`:
  Kong 54396 / Postgres 54392; `ENV=testing`: 54386 / 54382).
- **This repo carries Dart unit tests** under `test/*.dart` (115 tests) for
  pure logic — the 2026-08-31 "no Dart tests" directive was **rescinded**
  (Q16, see `pubspec.yaml` dev_dependencies). `flutter test` is the gate.
- `make test` here runs the static Makefile gate
  (`test/opt-008-makefile-static.sh`), not `flutter test`; `make check` runs
  `secrets` + `ruby-toolchain` then `dart analyze` + `flutter analyze`.
- `test/support/`, `test/meta/conventions_test.dart`, `test_driver/` and
  `integration_test/` remain absent by convention (there is no widget or
  integration suite).

## Notes & decisions

- **Suckless test policy (2026-08-28)** is superseded first by the 2026-08-31
  backend-only directive and then by **Q16 (2026-11)**, which reinstated Dart
  unit tests for critical pure logic. No widget/integration tree is re-created.
- **Focused test loop:** `flutter test test/<file>_test.dart` for one suite,
  `flutter test` for all; the backend loop (`go test ./...`,
  `bash test/opt-NNN-<name>.sh`, `bash test/run_all_backend.sh`) lives in the
  backend repo.
- **`.agents/` was NOT created** (documented decision). The user-level
  `.agents/` holds portable *skills* (the supabase + supabase-postgres-best-practices
  `SKILL.md` packages), not project agent definitions — and the same skills
  already exist user-wide in `~/.agents/skills/`. Samay's project-specific
  needs are fully covered by `.opencode/` + `docs/process/`; an empty
  `.agents/` would be a placeholder dir. If a portable skill is ever needed,
  install it at the user level or vendor it with real content.
- The old guard `test/meta/conventions_test.dart` is gone; repo conventions are
  documented in `docs/process/` (and checked by the `docs-verifier` agent), with
  pure-logic coverage in the `test/*.dart` suites.
- Config format follows the opencode docs (opencode.ai/docs/config,
  /agents, /permissions); `.opencode/opencode.json` is a documented
  project-config location.
