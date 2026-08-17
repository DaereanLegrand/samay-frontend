# Samay — Development Methodology (AGENTS.md)

## Overview

Samay is built in **16 phases** (00–15). Each phase follows a strict TDD + documentation workflow. Parallel tracks run when dependencies permit.

---

## Per-Phase Workflow

```
1. PLAN  → Review docs/specs/product/ and docs/specs/steps/ for this phase
            Read cross-references.md to identify dependencies
            Break phase into steps

2. PREP  → Create docs/history/phase-XX/ directory
            Create daily log file for current date

3. RED   → Write tests that define the expected behavior
            Tests must be runnable and fail initially

4. GREEN → Implement the minimum code to pass tests
            No gold-plating — just enough to pass

5. REFACTOR → Clean up, follow Go/Flutter conventions
               Ensure no commented code, no dead code

6. VALIDATE → Run all tests (existing + new)
              Lint & typecheck
              Verify against docs/specs/product/ specs
              Update cross-references.md if dependencies changed

7. DOCUMENT → Write daily log entry covering:
              - What was built
              - Decisions made and why
              - Mistakes / gotchas encountered
              - Commands run (for reproducibility)
```

## TDD Rules

- **No implementation code without a failing test first.**
- Tests live in `*_test.go` (Go) or `test/` (Flutter/Supabase).
- SQL migrations are tested via `supabase db test` (pgTAP) where applicable.
- Each Edge Function has a corresponding test script.
- Test fixtures mirror real Supabase data shapes.

## Phase Dependency Rules

Dependencies are defined in `docs/specs/steps/cross-references.md`. When starting a step:

1. Verify all direct deps are complete (their `DONE` marker in the phase dir).
2. After completing a step, check if any downstream step's dependency is now satisfied — update the progress tracker.

## Parallel Track Policy

When dependencies allow, run tracks in parallel:

```
Track A: Supabase/DB work
Track B: Go module/CLI work
Track C: Flutter app work
```

Each track has its own daily log. Sync points occur when a track's output is needed by another (e.g., Track A's `DATA` schema must be deployed before Track B's `DBCL` can query it).

## Port Convention

> **2026-08-09**: DB port moved `5432 → 54382` so the Samay self-hosted stack can run
> alongside the running Juega Supabase (Juega owns 5432/54321/54323/8443). Kong HTTPS
> uses 54443. NEVER map Samay services onto Juega's ports.

| Service | Port | Note |
|---------|------|------|
| PostgreSQL | 54382 | direct DB access (was 5432 — conflicts with Juega pooler) |
| Studio | 54381 | |
| Mailpit (Email) | 54384 | |
| Kong (API Gateway) | 54386 | all API routes go through here |
| Analytics | 54388 | |
| Kong HTTPS | 54443 | self-hosted compose stack |

## Agent Orchestration Protocol

The 180-agent orchestration campaign (phases 4.1–4.6, 2026-08-09..11) is
**COMPLETE** (see `docs/audit/GATE-REPORT.md`); its per-agent docs were removed.
The workflow below remains the standing protocol for any future multi-agent or
parallel-human work — see `docs/process/DEVELOPMENT-WORKFLOW.md` for the full guide:

- **Every agent reads the entire repo first** (no shortcuts) and follows `docs/process/DEVELOPMENT-WORKFLOW.md`.
- **File semaphore:** before modifying any file, `tools/agent_lock.sh acquire <path> --owner <AGENT_ID>`; if another agent holds it, WAIT; release after (`release`). Locks live in `repo-locks/` (gitignored). `tools/agent_lock.sh list` shows held locks.
- **File ownership:** `docs/process/FILE-OWNERSHIP.md` maps every path to its owning agent.
- **Tests:** each worked-on thing ships tests + updates the modular integration suite (`integration_test/`, `test/opt-*.sh`, pgTAP).
- **Checkpoints:** orchestrator validates (`dart analyze`, `flutter test`, `go test ./...`), then commits AND pushes at every 50-agent stop.
- **Refactorability:** features will keep being added; keep code modular, typed, and easily extensible (tokens, feature services, models).

## Documentation Standards

- `docs/history/phase-XX/YYYY-MM-DD_step-NAME.md` — daily developer log
- `docs/specs/product/` — product/CLI/web-server specs (read-only reference)
- `docs/specs/steps/` — step specifications + `cross-references.md` (read-only reference)
- Docs are organized per the Diátaxis model (`docs/README.md` hub): `process/` (how-to),
  `specs/` (reference), `design|security|infra/` (explanation), `history/|audit/|to-fix/` (records)
- Mistakes are documented as **MISTAKE** blocks in daily logs so future devs can search for them

## Testing Commands

```bash
# Go
go test ./...

# Flutter
flutter test

# Supabase
supabase db test    # pgTAP
supabase functions serve --debug    # Edge Functions not yet implemented — boot stub only
```

## Validation Gate

Before marking a phase complete, run:

- [ ] All tests pass
- [ ] Lint passes (`golangci-lint run ./...` for Go, `dart analyze` for Flutter)
- [ ] Spec docs are satisfied (checklist from docs/specs/product/ and docs/specs/steps/)
- [ ] Cross-references updated if needed
- [ ] Daily log written for each step
- [ ] AGENTS.md updated if methodology changes
