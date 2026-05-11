# Vive! — Development Methodology (AGENTS.md)

## Overview

Vive! is built in **16 phases** (00–15). Each phase follows a strict TDD + documentation workflow. Parallel tracks run when dependencies permit.

---

## Per-Phase Workflow

```
1. PLAN  → Review docs/planification/ and docs/implementation/ for this phase
            Read cross-references.md to identify dependencies
            Break phase into steps

2. PREP  → Create docs/development/phase-XX/ directory
            Create daily log file for current date

3. RED   → Write tests that define the expected behavior
            Tests must be runnable and fail initially

4. GREEN → Implement the minimum code to pass tests
            No gold-plating — just enough to pass

5. REFACTOR → Clean up, follow Go/Flutter conventions
               Ensure no commented code, no dead code

6. VALIDATE → Run all tests (existing + new)
              Lint & typecheck
              Verify against docs/planification/ specs
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

Dependencies are defined in `docs/implementation/cross-references.md`. When starting a step:

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

| Service | Port | Default | Note |
|---------|------|---------|------|
| PostgreSQL | 5432 | 54322 | direct DB access |
| Studio | 54381 | 54321 | blocked |
| Mailpit (Email) | 54384 | 54324 | blocked |
| Kong (API Gateway) | 54386 | 54321 | all API routes go through here |
| Analytics | 54388 | 54327 | blocked |
| (pooler disabled) | — | 54329 | blocked — not needed for dev |

## Documentation Standards

- `docs/development/phase-XX/YYYY-MM-DD_step-NAME.md` — daily developer log
- `docs/planification/` — spec documents (read-only reference)
- `docs/implementation/` — step specifications (read-only reference)
- Mistakes are documented as **MISTAKE** blocks in daily logs so future devs can search for them

## Testing Commands

```bash
# Go
go test ./...

# Flutter
flutter test

# Supabase
supabase db test    # pgTAP
supabase functions serve --debug
```

## Validation Gate

Before marking a phase complete, run:

- [ ] All tests pass
- [ ] Lint passes (`golangci-lint run ./...` for Go, `dart analyze` for Flutter)
- [ ] Spec docs are satisfied (checklist from docs/planification/ and docs/implementation/)
- [ ] Cross-references updated if needed
- [ ] Daily log written for each step
- [ ] AGENTS.md updated if methodology changes
