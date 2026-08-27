# `.opencode/` — project configuration for opencode sessions

This directory gives every opencode session in this repo the Samay project
context and the standing development protocol **automatically**.

## What loads automatically

| File | Effect |
|---|---|
| `opencode.json` | **Project config**: `instructions` inject AGENTS.md + `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md` into every session; `permission.bash` denies destructive git operations (commit/push allowed on human request, see below). |
| `agents/*.md` | Four project agents (see table below). Subagents are invoked via `@mention`; `samay` is a primary agent you can switch to with Tab. |
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
   (read-first mandate, semaphore, TDD, commit policy, report format) for any
   session that switches to it.

## Agents

| Agent | Mode | Purpose | Tools |
|---|---|---|---|
| `@reviewer` | subagent | Sign-off gate: `dart analyze` + `flutter test` + `go test ./...`, then code review per DEVELOPMENT-WORKFLOW.md §5 | read/grep/glob + gate commands only (`edit`/`write` denied) |
| `@security-check` | subagent | Security gates: secrets gate + `tools/check_ports.sh --strict` + audit vs `docs/security/` (RLS, E2EE, sanitization, port map) | read/grep/glob + the gates only (`edit`/`write` denied) |
| `@docs-verifier` | subagent | Doc↔code consistency: README baselines, cross-references statuses, security/design/infra claims, port map | read/grep/glob + `rg`/`git grep` only (`edit`/`write` denied) |
| `samay` | primary | Full DEVELOPMENT-WORKFLOW workflow for implementation work (Tab to switch) | all tools; destructive git ops denied, commit/push on human request |

## Notes & decisions

- **UI-only changes skip RED/GREEN** (2026-08-27). Pure visual/layout changes
  (styling, tokens, spacing, text placement) with no behavior or data-flow
  impact skip the failing-test-first cycle per `AGENTS.md` §TDD Rules — but
  they still keep the behavior/widget tests green, and MUST NOT add
  visual-pinning assertions (token-budget directive 2026-08-27: token values
  are pinned once in `test/design_tokens/` + `test/theme/` + `test/widgets/`).
- **Focused test loop is the default** (2026-08-27, explicit directive).
  Agents iterate with `make test-file FILE=<path>` / `make test-feature
  FEATURE=<name>` / `make test-files`; the full `make check` + `make test`
  gate runs ONLY when the human explicitly asks. The `samay` agent prompt,
  the `reviewer` agent prompt, and the Makefile all encode this.
- **`.agents/` was NOT created** (documented decision). Juega's `.agents/`
  holds portable *skills* (the supabase + supabase-postgres-best-practices
  `SKILL.md` packages), not project agent definitions — and the same skills
  already exist user-wide in `~/.agents/skills/`. Samay's project-specific
  needs are fully covered by `.opencode/` + `docs/process/`; an empty
  `.agents/` would be a placeholder dir, which the repo forbids
  (structure_test dynamic invariant). If a portable skill is ever needed,
  install it at the user level or vendor it with real content.
- The guard `test/meta/conventions_test.dart` enforces: the config exists +
  parses, references DEVELOPMENT-WORKFLOW.md + FILE-OWNERSHIP.md, allows
  `git commit`/`git push`, denies the destructive git ops, and ships the
  three subagents + README.
- Config format follows the opencode docs (opencode.ai/docs/config,
  /agents, /permissions); `.opencode/opencode.json` is a documented
  project-config location.
