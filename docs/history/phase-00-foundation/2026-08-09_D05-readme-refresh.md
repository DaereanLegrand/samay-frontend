# 2026-08-09 — D-05: README Refresh (Onboarding in 10 Minutes)

**Agent:** D-05 (Phase 4.1 — documentation gap closure)
**Role:** Root `README.md` + `test/README.md` rewrite; agent-lock docs; daily log.

---

## What was built

### 1. `README.md` (root) — full rewrite
The root README was Flutter boilerplate ("A new Flutter project") — replaced with:

- **Project overview** — Samay as a disco/social-life app (18–35 LATAM demographic),
  shards economy, QR attendance, group ranks, mini-games; link to the full MVP spec.
- **3-track architecture table** — Flutter app (phases 02–04 done, 05+ foundations
  planned), Go admin CLI (complete), self-hosted Supabase (foundation done, port
  remap in progress I-02).
- **Quickstart** — `flutter pub get` → `cp .env.example .env` → `flutter run`, plus
  the test/build commands. All Make targets listed in a verified table
  (every target was dry-run checked with `make -n`, see Verification).
- **`.env` vs `--dart-define`** — documents the current `flutter_dotenv` asset
  approach, why it's being replaced (to-fix M-21/M-31), and the planned
  `--dart-define` migration (I-34/M-13).
- **Approved port map** — DB 54382 / Kong 54386 / Studio 54381 / Mailpit 54384 /
  Analytics 54388 / Kong-https 54443, with the Juega coexistence rule and a
  clear warning that compose files are mid-remap (do not start while Juega runs
  until I-02 lands). Links SELFHOSTING.md (planned D-08) and
  DEPLOYMENT-PLACEHOLDER.md (planned D-10) for details; no invented URLs —
  `https://samay-api.example.com` used as the placeholder convention.
- **Repo layout map** — annotated tree of lib/, cmd/, internal/, supabase/,
  supabase-testing/, test/, docs/, tools/, with planned paths marked `PLANNED
  (owner-id)`.
- **Orchestration links** — `docs/process/DEVELOPMENT-WORKFLOW.md` + `AGENT-RULES.md`,
  `FILE-OWNERSHIP.md`, and `docs/design/DISCO-DESIGN-SYSTEM.md` referenced as
  **planned** (D-11).
- **Testing summary table** — all 6 layers incl. baseline numbers
  (176 pass / 23 pre-existing fail Flutter, 82 Go tests) and the manual QA
  runner.
- **"How to add a feature"** paragraph — refactorability emphasis: typed models
  (freezed planned I-10), feature services, Riverpod providers, design tokens
  (I-16), route registration, feature flags (I-49), TDD-first, `app_config` for
  tuneable values.
- **Known gaps** — phases done/planned, pointer to TODO.md and cross-references.

### 2. `test/README.md` — refreshed
- Added the **full test matrix** section at the top: Flutter unit/widget (`test/`),
  Flutter modular integration suite (`integration_test/` — described the intended
  layout per AGENT-RULES §2 and marked **planned, I-01**), backend curl opt-tests
  (`test/opt-*.sh` + `test/run_all_backend.sh`), Go tests (`go test ./...`), pgTAP
  (`supabase/tests/schema_test.sql` — 125 assertions), and the manual gum runner.
- **Kept the existing curl helper documentation byte-intact** (anatomy of a curl
  test, helper patterns, psql comparison, response interpretation, setup pattern,
  coverage notes) — per mission requirement.
- Updated the "Running Tests" section to include the integration suite and the
  env overrides (`SUPABASE_URL`/`ANON_KEY`/`SERVICE_KEY`).
- Extended the naming-convention section to the full matrix.

### 3. Agent-lock documentation (in root `README.md`)
New "Parallel work: `tools/agent_lock.sh`" section for **humans** working in
parallel: `list`/`status`/`acquire`/`release`/`run` examples, lock root
(`repo-locks/`, gitignored, atomic mkdir), polling/timeout semantics
(1800s default, exit codes 0/2/3), multi-file edit guidance, blocked-reporting.

### 4. Daily log (this file)
Per AGENTS.md documentation standards.

---

## Decisions made and why

- **Document the approved port map as truth, warn about the mid-remap state**
  rather than documenting the current (conflicting) compose mappings. The port
  map is the enforced convention (AGENTS.md); the compose files are being
  remapped by I-02/M-01..M-10 and are not mine to fix. New devs must know the
  *target* state and the "don't start while Juega runs" rule.
- **Every planned path is marked `PLANNED (<owner>)`** (integration_test/ I-01,
  DISCO-DESIGN-SYSTEM.md D-11, SELFHOSTING.md D-08, DEPLOYMENT-PLACEHOLDER.md
  D-10) so the README stays honest and links never dangle.
- **No invented deployment URLs** — used `https://samay-api.example.com` as the
  documented placeholder, deferring real URLs to D-10's document.
- **README kept focused (onboarding ≤10 min)**, with depth pushed to existing
  docs (specs, test guide, orchestration docs) via links — mirroring the
  "docs should be the index, not the dump" principle.
- **test/README.md keeps its original curl guide untouched** — it's referenced
  by the workflow docs and worked; only structure was added around it.

## MISTAKEs / gotchas

- **MISTAKE (caught early):** first draft of the README claimed `make build`
  builds an APK — verified with `make -n build` it branches on `TARGET` (apk vs
  unsigned iOS IPA). Documented both variants correctly.
- **MISTAKE (verified instead of assumed):** nearly documented `integration_test/`
  as existing; `ls integration_test` confirmed it does not yet exist. Marked
  planned (I-01) in both READMEs.
- **Gotcha:** `docs/design/`, `<private-ops-repo>/`, `docs/security/` directories don't
  exist yet — links to their future files are written as relative paths that
  resolve once D-08/D-10/D-11/D-06/D-07 land (they are referenced from the
  repo-layout map with "PLANNED" tags, so a V-agent can verify later).
- **Gotcha:** `supabase/docker-compose.yml` still maps host ports 5432/54321
  (Juega conflicts) — NOT touched (I-02's file). README documents this honestly.

## Commands run

```bash
# Verification of every documented command (dry-run, no execution)
make -n build          # flutter build apk | TARGET=ios → unsigned IPA
make -n build-cli      # go build -o samay ./cmd/samay-admin
make -n build-linux    # GOOS=linux GOARCH=amd64 go build -o samay-linux
make -n flutter-test   # flutter test
make -n flutter-analyze# dart analyze
make -n lint           # dart analyze + go vet (+ golangci-lint if present)
make -n test           # flutter test + go test ./... -v
make -n supabase-docker-start/stop/status/reset   # docker compose in supabase/
make -n supabase-testing-start                     # docker compose in supabase-testing/
make -n migrate-check # git status check on supabase/migrations/
ls test_runner.sh tools/agent_lock.sh test/run_all_backend.sh test/opt-001-rls-security.sh supabase/tests/schema_test.sql   # all exist
ls integration_test docs/design <private-ops-repo>          # confirmed absent (planned paths)

# Lock protocol (all three files)
tools/agent_lock.sh acquire README.md --owner D-05
tools/agent_lock.sh acquire test/README.md --owner D-05
tools/agent_lock.sh acquire docs/history/phase-00-foundation/2026-08-09_D05-readme-refresh.md --owner D-05
tools/agent_lock.sh list          # 3 locks held by D-05 (evidence in final report)
# ... write files ...
tools/agent_lock.sh release README.md --owner D-05
tools/agent_lock.sh release test/README.md --owner D-05
tools/agent_lock.sh release docs/history/phase-00-foundation/2026-08-09_D05-readme-refresh.md --owner D-05
```

## Verification

- [x] Every command documented in the READMEs was dry-run verified (`make -n …`,
      file existence) — none invented.
- [x] Every linked path either exists or is explicitly tagged `PLANNED (<owner>)`.
- [x] No secrets introduced; no real deployment URLs invented
      (`https://samay-api.example.com` placeholder convention only).
- [x] No commits made; working tree only.
- [x] No Juega files touched; no Juega ports used.
- [x] Existing curl-helper documentation in `test/README.md` preserved verbatim.
- [x] Lock evidence: acquired/released on all 3 files (see report).

## Issues found (reported, NOT fixed — out of scope)

1. **`supabase/docker-compose.yml` + `supabase-testing/docker-compose.yml` still
   map host ports 5432/54321** (Juega conflicts) and `run.sh`/`migrate.sh`
   scripts print/use the old URLs (`localhost:54321`, DB `5432`). Port remap is
   I-02/M-01..M-10's assignment — flagged so it isn't forgotten.
2. **`test_runner.sh` hardcodes `DB_URL` at `127.0.0.1:5432`** (line 4) — same
   port conflict; belongs to the I-02/M-10 remap.
3. **`.env.example` contains a real anon key** (`sb_publishable_…`) and a real
   domain (`samay-api.qallariy.lat`) — finding H-21, owned by I-34/M-13.
4. **`docs/design`, `<private-ops-repo>`, `docs/security` dirs don't exist yet** — the
   README references their planned files; D-06/D-08/D-10/D-11 must land them.
5. **`test/opt-001-rls-security.sh` + `run_all_backend.sh` default to
   `http://127.0.0.1:54386`** (Kong, correct) but embed dev keys as defaults —
   consistent with the current stack; S-08 should revisit before any
   non-local run.
