# D-09 — Development Workflow Document (`docs/process/DEVELOPMENT-WORKFLOW.md`)

**Agent:** D-09 (Phase 4.1 — documentation gap closure)
**Role:** Author of the definitive day-to-day developer + agent workflow document
**Owner map:** `docs/process/DEVELOPMENT-WORKFLOW.md` (per `docs/process/FILE-OWNERSHIP.md`)
**Date:** 2026-08-09

## What was built

`docs/process/DEVELOPMENT-WORKFLOW.md` (new) — the day-to-day workflow document for humans
and agents, covering all 8 mandated sections:

1. **Standard task cycle** — the AGENTS.md PLAN→PREP→RED→GREEN→REFACTOR→VALIDATE→DOCUMENT
   loop enriched with orchestration specifics: lock-before-edit, test-at-every-layer,
   integration-suite update, baseline comparison, and the "never commit yourself" rule.
2. **File-semaphore human guide** — full `tools/agent_lock.sh` command reference
   (`list`/`status`/`acquire`/`release`/`run`/`wait`), exit codes (0/2/3), when to lock
   (incl. new files), blocked-agent protocol (report `BLOCKED on <path> by <owner>`, pick
   non-conflicting work), and the common-mistakes list (forgetting to release, editing
   without a lock, anonymous `local-<pid>` owners, `wait`≠acquire, stale locks).
3. **Test conventions** — Dart unit/widget in `test/` (mirror layout, naming, H-01
   in-memory-Supabase harness reference), `integration_test/` modular suite (file-per-feature,
   independently runnable, `runner.sh` + `run_all.sh` — flagged as **planned, I-01**),
   curl opt-tests (`opt-NNN-desc.sh`, self-contained, exit 0/1, auto-registered by
   `run_all_backend.sh`), Go `httptest` convention (with `internal/ops/users_test.go`
   example), pgTAP (`schema_test.sql` + mirrored testing-stack file, **plan(N) must equal
   the actual test count** — D-04's 129 verified under the nested-SELECT counting rule),
   and the baseline table (176/23 flutter, 82 go, 0 errors/19 info analyze) with the
   **new-failure rule**: new failures must be explained, and "matches baseline" means the
   exact same failure set in the same files.
4. **Ports & env** — the approved port map (54382/54381/54384/54386/54388/54443), the
   mid-remap warning (compose/config still conflict with Juega → do NOT start the stack
   until I-02), `.env` (flutter_dotenv asset, current) vs `--dart-define` (planned I-34/
   M-13) usage rules, Juega coexistence rules (read-only, never its ports).
5. **Refactorability doctrine** — user-requirement checklist: feature-first dirs, design
   tokens (I-16/U-01..U-03), freezed models (I-10), feature services + repositories
   (I-11/I-50), feature flags (I-49/I-69), RoutePaths registration, `app_config` for
   tuneables, Riverpod state — plus a **reviewer checklist** of 10 concrete checks.
6. **Commit/checkpoint policy** — agents never commit; orchestrator validates
   (`dart analyze`, `flutter test`, `go test ./...`) then commits AND pushes at
   STOP-50/100/150/180 (branch `fixes`).
7. **Agent report format** — copied verbatim from AGENT-RULES.md §0.8 (ID+role, what was
   built, files with lock evidence, tests+results, sources, issues found).
8. **Cheatsheet** — lock + test command quick reference.

Daily log: `docs/history/phase-00-foundation/2026-08-09_D09-dev-workflow.md` (this file).

## Decisions made and why

- **`integration_test/` described as "planned, I-01", never as existing** — verified with
  `ls integration_test` (does not exist). The doc specifies the *intended* layout per
  AGENT-RULES §2 and tells agents to add flow files after I-01 lands the scaffold.
- **Baseline numbers sourced from the H-01/H-02 daily logs** (the documented 176/23, 82, 0/19)
  rather than re-run: mission constraint says verify "as much as verifiable without running
  the full suite". Static verification: `rg -c '^func Test'` = 82 Go test funcs (1:1 with
  the documented baseline); Flutter test cases statically counted at 118 (`testWidgets` 77 +
  `test(` 41) — documented 199 (176+23) from H-02, difference explained by parametrized/
  helper-invoked cases, so I cite the documented numbers and mark static counts as
  approximations in this log only (the workflow doc carries only the documented numbers).
- **`.env` finding numbers cited as M-21/M-31/H-21** — cross-checked in
  `docs/to-fix/TODO.md` lines 52/88/98 and D-05's log (H-21 owner I-34/M-13).
- **Port table copied from AGENTS.md** (the enforced convention) and the compose mid-remap
  warning included with the I-02/M-01..M-10 ownership, consistent with D-01/D-02/D-05/D-06.
- **pgTAP plan-count rule documented from D-04's verified counting method** (SELECT lines −
  plan − finish − nested SELECTs inside `ok(NOT EXISTS ...)`), because D-04 proved the naive
  `rg -c '^\s*SELECT '` overcounts.
- **File-semaphore section written for humans too** (not just agents) — mission statement
  says humans will read this document; includes a lock/no-lock decision table and the
  blocked-protocol in plain language.
- No cross-references.md update needed (D-09 is a leaf doc task — no step deps changed).

## MISTAKE

- **MISTAKE (avoided by verification):** first draft planned to tell agents "each opt-test
  must be registered in run_all_backend.sh". Verified `test/run_all_backend.sh` — it globs
  `test/opt-*.sh` automatically. Documented the real behavior (no registration needed;
  keep `opt-NNN-` numbering sequential).
- **MISTAKE (avoided):** nearly stated `flutter test` baseline as "199 total". Documented
  baselines are "176 pass / 23 documented pre-existing failures" — that is how every log
  (H-01/H-02, AGENT-RULES §2) states it; the doc uses the same phrasing.

## Commands run (verification, all static / read-only)

```bash
bash -n tools/agent_lock.sh && bash -n tools/check_ports.sh \
  && bash -n test/run_all_backend.sh && bash -n test/opt-001-rls-security.sh   # all clean
ls integration_test                 # No such file or directory (planned, I-01)
ls <private-ops-repo> docs/design           # No such file or directory (planned D-08/D-10/D-11)
rg -c "^func Test" cmd internal --glob '*_test.go' | awk -F: '{s+=$2} END {print s}'  # 82
rg -c 'testWidgets\(' test --glob '*.dart' | awk -F: '{s+=$2} END {print s}'          # 77
rg -c '^\s*test\(' test --glob '*.dart' | awk -F: '{s+=$2} END {print s}'             # 41
git branch --show-current           # fixes
git status --short                  # working tree: D-01..D-06 + H-02 modifications, no conflicts
rg -n '54382|54386' AGENTS.md       # port table present (source of truth)
rg -n 'M-21|M-31|H-21' docs/to-fix/TODO.md   # .env findings → I-34/M-13 owners
tools/agent_lock.sh list            # (before my work: no locks held)

export AGENT_NAME=D-09
tools/agent_lock.sh acquire docs/process/DEVELOPMENT-WORKFLOW.md --owner D-09
tools/agent_lock.sh acquire docs/history/phase-00-foundation/2026-08-09_D09-dev-workflow.md --owner D-09
# (wrote both files)
tools/agent_lock.sh release docs/process/DEVELOPMENT-WORKFLOW.md --owner D-09
tools/agent_lock.sh release docs/history/phase-00-foundation/2026-08-09_D09-dev-workflow.md --owner D-09
```

## Verification

- [x] Every tools/path/script referenced in the workflow doc exists or is explicitly tagged
      as planned: `tools/agent_lock.sh` (bash -n clean, subcommands verified against source:
      acquire/release/wait/status/list/run), `tools/check_ports.sh` (exists, D-01),
      `test/run_all_backend.sh` + `test/opt-001-rls-security.sh` (bash -n clean),
      `integration_test/` (confirmed absent → marked planned I-01),
      `supabase/tests/schema_test.sql` + `supabase-testing/tests/schema_test.sql` (exist,
      plan(129) per D-04), `Makefile` targets cross-checked (`make -n` behavior from D-05).
- [x] Baseline numbers consistent with documented reality: 82 Go test funcs statically
      verified; 176/23 and 0-errors/19-info taken from H-01/H-02 logs and AGENT-RULES §2.
- [x] Report format in the doc matches AGENT-RULES.md §0.8 verbatim (re-read §0.8 during writing).
- [x] No conflicts with D-01..D-06 content (port map, planned docs, to-fix statuses, H-01/H-02
      harness references all aligned).
- [x] No code changed; no commits made; no Juega files or ports touched.

## Issues found (reported, NOT fixed — out of scope)

1. `supabase/config.toml` `[db] port = 5432` and both `docker-compose*.yml` sets still map
   5432/54321 — the workflow doc's "do not start the stack" warning stays valid until
   I-02/M-01..M-10 land (same finding as D-01/D-02/D-05/D-06).
2. `.env.example:5` still carries a real anon key (H-21) and `.env` is still a Flutter asset
   (M-21/M-31) — I-34/M-13 scope; documented in §4.2 without repeating the key.
3. `integration_test/` does not exist yet — I-01 must land the scaffold before §3.2's
   per-feature flow files can be added; the doc already gates on it.
4. `test_runner.sh` still hardcodes `127.0.0.1:5432` (I-02/M-10 remap scope) — out of my scope,
   already flagged by D-02/D-05.

## Lock evidence

- `docs/process/DEVELOPMENT-WORKFLOW.md` — ACQUIRED by D-09 (2026-08-09T05:44:34Z, lock
  9aef66f7e439993ccc59a675), RELEASED after write.
- `docs/history/phase-00-foundation/2026-08-09_D09-dev-workflow.md` — ACQUIRED by D-09
  (lock 2518bb390f712711ef098652), RELEASED after write.
