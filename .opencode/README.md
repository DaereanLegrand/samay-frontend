# `.opencode/` — project configuration for opencode sessions

This directory gives every opencode session in this repo the Samay project
context and the 180-agent campaign protocol **automatically**. It was created
by agent **M-25** (Phase 4.3, ARC-08 / TOOL-05 / L-02) on 2026-08-10.

## What loads automatically

| File | Effect |
|---|---|
| `opencode.json` | **Project config** (loaded by opencode from `.opencode/opencode.json`): `instructions` inject AGENTS.md + `docs/process/DEVELOPMENT-WORKFLOW.md` + `docs/process/FILE-OWNERSHIP.md` into every session; `permission.bash` denies destructive git operations (commit/push allowed on human request, see below). |
| `agents/*.md` | Four project agents (see table below). Subagents are invoked via `@mention`; `samay` is a primary agent you can switch to with Tab. |
| `README.md` | This file — how the config works and how the lock protocol is surfaced. |

## The lock protocol is surfaced three ways

1. **Instructions:** every session loads `docs/process/DEVELOPMENT-WORKFLOW.md`
   (§1 file semaphore), `docs/process/FILE-OWNERSHIP.md` (ownership map) and
   `docs/process/DEVELOPMENT-WORKFLOW.md` (§2 lock guide) as system
   instructions — the semaphore (`tools/agent_lock.sh acquire/release/list`)
   is part of the model's context before the first message.
2. **Permissions:** `opencode.json` keeps all tools on opencode defaults
   but **denies the destructive git operations** —
   `git pull/am/cherry-pick/rebase/merge/reset/checkout/switch/clean/stash`.
   `git commit`/`git push` are **allowed on explicit human request**
   (product decision 2026-08-14 — the campaign is over; the human
   authorizes commits in-session). File-write discipline stays rule-driven
   (DEVELOPMENT-WORKFLOW.md §2) rather than permission-driven: the lock,
   not the tool, arbitrates parallel edits.
3. **The `samay` agent** re-states the full protocol in its system prompt
   (read-first mandate, semaphore, TDD, no-commit, report format) for any
   session that switches to it.

## Agents

| Agent | Mode | Purpose | Tools |
|---|---|---|---|
| `@reviewer` | subagent | Sign-off gate: `dart analyze` + `flutter test` + `go test ./...`, then code review per DEVELOPMENT-WORKFLOW.md §5 | read/grep/glob + gate commands only (`edit`/`write` denied) |
| `@security-check` | subagent | Security gates: `make secrets-check` + `tools/check_ports.sh --strict` + audit vs `docs/security/` (RLS, E2EE, sanitization, port map) | read/grep/glob + the two gates only (`edit`/`write` denied) |
| `@docs-verifier` | subagent | Doc↔code consistency: TODO.md statuses, daily logs, port map, FILE-OWNERSHIP paths, spec compliance | read/grep/glob + `rg`/`git grep` only (`edit`/`write` denied) |
| `samay` | primary | The campaign protocol agent — full DEVELOPMENT-WORKFLOW workflow for implementation work (Tab to switch) | all tools; destructive git ops denied, commit/push on human request |

`reviewer` and `security-check` map to the campaign's own gates (V-series
and S-series scope) so a human can delegate the pre-sign-off matrix to a
subagent in any session.

## Notes & decisions

- **`.agents/` was NOT created** (documented decision). Juega's `.agents/`
  holds portable *skills* (the supabase + supabase-postgres-best-practices
  `SKILL.md` packages), not project agent definitions — and the same skills
  already exist user-wide in `~/.agents/skills/`. Samay's project-specific
  needs are fully covered by `.opencode/` + `docs/process/`; an empty
  `.agents/` would be a placeholder dir, which the repo forbids
  (structure_test dynamic invariant). If a portable skill is ever needed,
  install it at the user level or vendor it with real content.
- The guard `test/meta/conventions_test.dart` (I-48's file) enforces: the
  config exists + parses, references DEVELOPMENT-WORKFLOW.md + FILE-OWNERSHIP.md,
  allows `git commit`/`git push` (human-authorized, since 2026-08-14), denies
  the destructive git ops, and ships the three subagents + README.
- Config format follows the opencode docs (opencode.ai/docs/config,
  /agents, /permissions) as of opencode 1.18.16; `.opencode/opencode.json`
  is a documented project-config location (verified with
  `opencode debug config`).
