# Samay — Development Methodology (AGENTS.md)

## Overview

Samay is built in **16 phases** (00–15). Each phase follows a strict TDD + documentation workflow. Parallel tracks run when dependencies permit.

---

## Supabase stacks (hard rule)

**NEVER touch the `supabase/` (prod) stack. ONLY `supabase-testing/`.**
There are no exceptions and no "just this once".

This forbids, for the `supabase/` stack ONLY:
- `docker compose` commands in `supabase/`;
- every `make supabase-start|stop|status|reset|init|docker-*|seed-*` target;
- `supabase/migrate.sh`, `supabase/reset.sh`, `supabase/run.sh`,
  `supabase/seed-config.sql`, `supabase/volumes/`;
- any `psql` (or REST/Studio) connection to the prod stack's database.

Do NOT start, stop, reset, migrate, seed, or query it. It is the human's, and
a reset destroys its volumes and data.

The ONLY stack an agent may start, stop, reset, migrate, seed, or query is
**`supabase-testing/`** (`make supabase-testing-*`,
`supabase-testing/migrate.sh`, same approved port map). The two stacks are
**mutually exclusive** on those ports: if the prod stack holds the ports, STOP
and ask the human to stop it — never stop it yourself.

Migrations are authored in `supabase/migrations/**` (the source tree) and
mirrored byte-identical into `supabase-testing/migrations/**`; they are APPLIED
by running the **testing** stack's migration flow, never the prod one.

---

## Privilege Escalation (hard rule)

**Never attempt to elevate privileges.** No `sudo`, no `osascript ... with
administrator privileges`, no `do shell script` with admin rights, no
Authorization Services prompts, no setuid/root helpers. Any action that needs
elevated privileges MUST be handed to the human as an exact command to run
themselves. Enforced at the config level in `.opencode/opencode.json`.

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

3. RED   → Write backend tests that define the expected behavior
            Tests must be runnable and fail initially

4. GREEN → Implement the minimum code to pass tests
            No gold-plating — just enough to pass

5. REFACTOR → Clean up, follow Go/Flutter conventions
               Ensure no commented code, no dead code

6. VALIDATE → focused tests for the change (go test ./... /
              bash test/opt-NNN-<name>.sh) — full `make check + make test`
              ONLY on explicit human request
              Verify against docs/specs/ specs
              Update cross-references.md if dependencies/statuses changed
              Update baseline numbers in README.md if counts moved

7. DOCUMENT → Write the daily log entry covering:
              - What was built
              - Decisions made and why
              - Mistakes / gotchas encountered (MISTAKE blocks)
              - Commands run (for reproducibility)
```

## Testing Rules

- **Testing is reserved for the backend, or per task there are NO integration
  tests (explicit directive 2026-08-31).** The Flutter/Dart test trees were
  deleted: `test/*.dart` (unit/widget/provider/router/theme suites),
  `integration_test/` (all flows + `runner.sh`), `test_driver/`. They must
  NOT be recreated, and no `make flutter-test` / `make test-file` /
  `make test-feature` / `make test-integration` targets exist.
- **Backend TDD only:** no implementation code without a failing test first,
  where the tests are Go `*_test.go`, pgTAP cases, or curl opt-tests.
- Tests live in `*_test.go` (Go), `test/opt-NNN-*.sh` (backend curl) and
  `supabase/tests/schema_test.sql` (pgTAP, mirrored byte-identical in
  `supabase-testing/`).
- **Test-layer budget (max 2–3 layers per change):** Go logic → unit test;
  SQL/schema/RLS → pgTAP; REST/RLS/security → curl opt-test. Never duplicate
  the same assertion across layers (each layer earns its keep).
- **Iteration loop (default, explicit directive 2026-08-27):** run ONLY the
  tests your change touches — `go test ./...`, `bash test/opt-NNN-<name>.sh`
  for a single curl opt-test, `bash test/opt-005-seeds-static.sh` /
  `bash test/opt-007-compose-static.sh` for the static gates. The full
  `make check` + `make test` gate runs ONLY when the human explicitly asks
  for a full validation.
- SQL migrations are tested via `make supabase-db-test` (pgTAP, `supabase db test --db-url` against the self-hosted compose DB) where applicable.
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

**VM-internal services are NOT host ports.** One **Alpine Linux** AArch64 install
(`<base-image>`, hostname `<base-image>`) is baked + sealed once; every
task VM is an **APFS clone** of it, provisioned with only what its task needs
(`tools/<ops-tooling>/host-clone.sh`). The earlier <base-os> AArch64 base is preserved,
renamed **`QallariyBase-<base-os>`** (reference/rollback only — no new clones).
The base and its clones (`<source-host>`, `<ci-host>`, `mail`) run inside UTM on
the `<vm-ip-prefix>0/24` shared network (the host↔VM bridge, reachable from the
Mac). Their ports are **never** mapped onto the Mac's host ports and never
exposed on the Mac's LAN; remote access is only through each VM's own Cloudflare
tunnel:

| VM | VM-internal service | Port |
|---|---|---|
| `<base-image>` (Alpine) | (template — no services) | — |
| `QallariyBase-<base-os>` | (preserved old template — no services) | — |
| `<source-host>` | Gitea web | 3000 |
| `<source-host>` | Gitea SSH (built-in) | 2222 |
| `<ci-host>` | act_runner | (outbound only) |
| `mail` | <ops-service> (Qallariy Mail) web | 8888 |
| `mail` | Purely Mail IMAP/SMTP | (outbound only) |

`<source-host>` runs **native Gitea** (official binary + OpenRC + SQLite, no
Docker). GitLab was retired — Xcode Cloud reads the project's GitHub mirror.

VM disks/bundles must live under `/Volumes/Media` — never internal storage.

## Xcode MCP device interaction (command syntax)

UI verification on a simulator/device runs through the Xcode MCP
`DeviceInteraction*` tools; interactions are issued by
`xcode_DeviceInteractionSynthesize`'s `interactionCommand` string. Full runbook:
`docs/process/XCODE-INTEGRATION.md`. The command grammar (export the skill with
`xcrun agent skills export --output-dir <dir>` → `device-interaction/SKILL.md`):

| Command | Action |
|---|---|
| `t <x> <y> [duration]` | Tap at coordinates (optional hold seconds) |
| `d <x> <y>` | Double tap |
| `t <x1> <y1> f <x2> <y2> [duration]` | Swipe from start to end |
| `drag <x1> <y1> <x2> <y2> [hold] [move]` | Press-and-hold then drag |
| `mt [x y, ...] dur [x y, ...] dur ...` | Multi-touch sequence (pinch, etc.) |
| `b h/p/u/d [duration]` | Hardware button: home / power / vol-up / vol-down |
| `sender keyboard kbd <text>` | Type into the FOCUSED field — MUST be the last command in the chain; rest of the string is verbatim. Special chars via `\u{XXXX}` (e.g. `\u{000A}` = Return) |
| `w <duration>` | Wait |
| `orientation faceDown/faceUp/landscapeLeft/landscapeRight/portrait/portraitUpsideDown` | Set orientation (iOS) |
| `c <rotations>` / `r <up/down/left/right/select/menu/home/playpause>` | watchOS / tvOS only |

Rules:
- Prefer each element's hierarchy `hitPoint` over screenshot-estimated
  coordinates; never guess from the image first.
- Chain a focus tap and the typing in one command, e.g.
  `t 207 256 sender keyboard kbd user@example.com sender keyboard kbd ...`
  is NOT valid — the keyboard command must be LAST, so type one field per call:
  `t 207 256 sender keyboard kbd user@example.com`, capture, then
  `t 207 324 sender keyboard kbd secret`.
- Capture (empty `interactionCommand`) before and after every interaction.
- Never `DeviceInteractionInstallAndRun` over the human's running dev session;
  never trigger a hot reload/restart yourself (`.opencode/DEV-SERVER.md`).
- Do not shut down / kill / restart the human's simulators.

## Documentation Standards

- `docs/README.md` — docs hub / map
- `docs/design/DESIGN.md` — the current design language (tokens live in code)
- `docs/security/SECURITY.md` — precautions applied now, each with its why,
  plus open items; `E2EE-ARCHITECTURE.md` for chat crypto
- `<private-ops-repo>/` — self-hosting runbook + deployment placeholders
- `docs/specs/steps/` — specs for steps NOT yet implemented + `cross-references.md`
  statuses (implemented steps' behavior is documented by code/tests; their specs are removed)
- `<private-ops-repo>/DATABASE.md` — DB catalog as-is; `<private-ops-repo>/BACKEND.md` — Go CLI/API surface as-is
- `docs/history/phase-XX/YYYY-MM-DD_<slug>.md` — optional daily developer log
  (fresh start; write one when a session deserves a record)
- `docs/process/XCODE-INTEGRATION.md` — drive Xcode directly (Xcode 27 MCP +
  `xcodebuild`/`simctl` runbook); read before any Xcode/MCP work
- Mistakes are documented as **MISTAKE** blocks so future sessions can search for them
- No secrets in code, tests, or docs — ever

## Testing Commands

```bash
make test          # go test ./... + backend static opt gates
make check         # dart analyze + flutter analyze + go vet + ports + secrets gates
go test ./...

# Supabase
make supabase-db-test    # pgTAP via `supabase db test --db-url` (self-hosted compose DB, needs the stack up)
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
