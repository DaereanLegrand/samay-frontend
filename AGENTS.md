# Samay — Development Methodology (AGENTS.md)

## Overview

Samay is built in **16 phases** (00–15). Each phase follows a strict TDD + documentation workflow. Parallel tracks run when dependencies permit.

---

## Per-Phase Workflow

```
1. PLAN  → Review docs/specs/steps/ for pending-work specs of this phase
            Read cross-references.md to identify dependencies
            Read <private-ops-repo>/DATABASE.md + <private-ops-repo>/BACKEND.md for as-is references
            Break the work into steps

2. PREP  → If the session is worth a record, create
           docs/history/phase-XX/YYYY-MM-DD_<slug>.md (the dir may not exist
           yet — create it; history starts empty and grows as needed)

3. RED   → Write tests that define the expected behavior
            Tests must be runnable and fail initially

4. GREEN → Implement the minimum code to pass tests
            No gold-plating — just enough to pass

5. REFACTOR → Clean up, follow Go/Flutter conventions
               Ensure no commented code, no dead code

6. VALIDATE → focused tests for the change (make test-file /
              make test-feature) — full `make check + make test` ONLY on
              explicit human request
              Verify against docs/specs/ specs
              Update cross-references.md if dependencies/statuses changed
              Update baseline numbers in README.md if counts moved

7. DOCUMENT → Write the daily log entry covering:
              - What was built
              - Decisions made and why
              - Mistakes / gotchas encountered (MISTAKE blocks)
              - Commands run (for reproducibility)
```

## TDD Rules

- **No implementation code without a failing test first.**
- **UI-only exception:** pure visual/layout changes (styling, tokens, spacing,
  text placement) with no behavior or data-flow impact skip RED/GREEN — but
  they still keep the behavior/widget tests green, and MUST NOT add
  visual-pinning assertions (token-budget, 2026-08-27): token values are
  pinned once in `test/design_tokens/` + `test/theme/` + `test/widgets/` —
  feature tests assert behavior, never exact `BoxDecoration`/`fontSize`/
  token internals. `test/meta/conventions_test.dart` enforces this.
- Tests live in `*_test.go` (Go), `test/` (Flutter), `integration_test/`
  (flows — every feature ships one), `test/opt-NNN-*.sh` (backend curl) and
  `supabase/tests/schema_test.sql` (pgTAP).
- **Test-layer budget (max 2–3 layers per change):** logic → unit test; UI
  behavior → widget test; ONE flow per feature → `integration_test/`;
  backend security/RLS → opt-curl + pgTAP. No restyle layer; never duplicate
  the same assertion across layers (each layer earns its keep).
- **Iteration loop (default, explicit directive 2026-08-27):** run ONLY the
  tests your change touches via `make test-file FILE=<path>` /
  `make test-feature FEATURE=<name>` / `make test-files FILES="a b"`. The
  full `make check` + `make test` gate runs ONLY when the human explicitly
  asks for a full validation.
- SQL migrations are tested via `supabase db test` (pgTAP) where applicable.
- Test fixtures mirror real Supabase data shapes.
- Keep `plan(N)` in the pgTAP suite equal to its real assertion count.

## Phase Dependency Rules

Dependencies are defined in `docs/specs/steps/cross-references.md`. When starting a step:

1. Verify all direct dependencies are satisfied (status column).
2. After completing a step, update the status column and check whether any downstream dependency just became satisfiable.

## Parallel Track Policy

When dependencies allow, run tracks in parallel:

```
Track A: Supabase/DB work
Track B: Go module/CLI work
Track C: Flutter app work
```

Sync points occur when a track's output is needed by another (e.g., the DB schema must be deployed before CLI commands can query it). For file-level coordination between concurrent sessions use the semaphore below.

## File semaphore (parallel work)

- Before modifying any file, `tools/agent_lock.sh acquire <path> --owner <your-id>`; if another session holds it, WAIT; release after (`release`). Locks live in `repo-locks/` (gitignored). `tools/agent_lock.sh list` shows held locks.
- Never edit under someone else's lock; never delete another lock. Full usage: `docs/process/DEVELOPMENT-WORKFLOW.md`.

## Port Convention

Juega's running Supabase owns host ports 5432/54321/54323/8443 — NEVER map Samay services onto them.

| Service | Port | Note |
|---------|------|------|
| PostgreSQL | 54382 | direct DB access |
| Studio | 54381 | |
| Mailpit (Email) | 54384 | |
| Kong (API Gateway) | 54386 | all API routes go through here |
| Analytics | 54388 | |
| Kong HTTPS | 54443 | self-hosted compose stack |

`tools/check_ports.sh --strict` must exit 0 after any infra change.

## Documentation Standards

- `docs/README.md` — docs hub / map
- `docs/design/DESIGN.md` — the current design language (tokens live in code)
- `docs/security/SECURITY.md` — precautions applied now, each with its why,
  plus open items; `E2EE-ARCHITECTURE.md` for chat crypto
- `<private-ops-repo>/` — self-hosting runbook + deployment placeholders
- `docs/specs/steps/` — specs for steps NOT yet implemented + `cross-references.md`
  statuses (implemented steps' behavior is documented by code/tests; their specs are removed)
- `<private-ops-repo>/DATABASE.md` — DB catalog as-is; `<private-ops-repo>/BACKEND.md` — Go CLI/API surface as-is
- `docs/specs/steps/` — specs for steps NOT yet implemented + `cross-references.md`
  statuses (implemented steps' behavior is documented by code/tests; their specs are removed)
- `docs/history/phase-XX/YYYY-MM-DD_<slug>.md` — optional daily developer log
  (fresh start; write one when a session deserves a record)
- Mistakes are documented as **MISTAKE** blocks so future sessions can search for them
- No secrets in code, tests, or docs — ever

## Testing Commands

```bash
make test          # flutter test + go test ./...
make check         # dart analyze + flutter analyze + go vet + ports + secrets gates
go test ./...

# Supabase
supabase db test    # pgTAP (needs the stack up)
bash test/run_all_backend.sh    # curl opt-tests (needs the stack up)
```

## Validation Gate

Before marking a phase complete:

- [ ] All tests pass (`make test`)
- [ ] Gates pass (`make check`: analyzers, vet, port map, secrets)
- [ ] Spec docs are satisfied (checklist from docs/specs/)
- [ ] cross-references.md statuses updated if needed
- [ ] README.md baseline numbers updated if counts moved
- [ ] Daily log written if the session deserves one
