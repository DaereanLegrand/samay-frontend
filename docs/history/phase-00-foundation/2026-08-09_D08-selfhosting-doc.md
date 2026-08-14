# 2026-08-09 — D-08: Self-Hosting Documentation (`<private-ops-repo>/SELFHOSTING.md`)

**Agent:** D-08 (Phase 4.1 — documentation gap closure)
**Role:** Author `<private-ops-repo>/SELFHOSTING.md` — architecture, compose target state,
migration-based testing workflow, onboarding runbook, troubleshooting, and the
deviation→owner table for I-02/M-01..M-10.
**Campaign:** Samay 180-agent orchestration (docs/process/DEVELOPMENT-WORKFLOW.md), branch `fixes`.

---

## What was built

### `<private-ops-repo>/SELFHOSTING.md` (new file, new `<private-ops-repo>/` dir — D-08 owned per FILE-OWNERSHIP)

1. **Architecture** — container topology diagram (db, kong, auth, rest, realtime,
   storage, meta, studio, mailpit, + planned imgproxy/edge-runtime/supavisor/analytics),
   internal-vs-published port rules (container ports stay standard; only 6 host
   bindings approved), the approved host port table (54382/54381/54384/54386/54388/54443),
   and the Juega coexistence rule with concrete detection commands (`lsof`, `nc`,
   `docker ps`, `tools/check_ports.sh --strict`).
2. **Compose target state** — per-service target `ports:` (db 54382:5432, kong
   54386:8000 + 54443:8443, studio 54381:3000, mailpit 54384:8025, auth/rest/
   realtime/storage/meta unpublished), image-version pinning policy + current-official
   tag table (verified 2026-08-09 from `supabase/supabase` `docker/` on master),
   healthcheck + `depends_on: service_healthy` chains (long syntax), volumes, and
   environment placeholder conventions (no secrets).
3. **Migration-based testing workflow** — documents current behavior of
   `migrate.sh`/`reset.sh`/`run.sh` (both dirs) and the exact fixes I-02/M-10 must
   land: `psql -p 54382`, `SUPABASE_PUBLIC_URL` remap, run.sh echoes 54386/54382;
   pgTAP via `supabase db test` (CLI path, blocked until config.toml remap) and the
   direct psql fallback against 54382; curl opt-tests (`test/opt-001-rls-security.sh`,
   `test/run_all_backend.sh`, default `http://127.0.0.1:54386`); how to run all of it
   without disturbing Juega (project isolation, never `supabase start` pre-remap).
4. **Onboarding runbook** — fresh clone → port check → `docker compose up -d --wait`
   → `migrate.sh`/`reset.sh` → pgTAP → `run_all_backend.sh` → `flutter run` with
   `SUPABASE_URL=http://127.0.0.1:54386`.
5. **Troubleshooting** — port conflicts, stale volumes (incl. named volumes),
   Kong routing (kong.yml route table, entrypoint, CRLF gotcha), mailpit, storage
   S3-vs-file (macOS bind-mount note), reset-vs-migrate (no tracking table —
   idempotency requirement).
6. **Known deviations table** — 27 verified rows mapping every stale item
   (compose ports, config.toml db port, run.sh/migrate.sh/reset.sh URLs,
   supabase-testing missing migration 20260724000002, duplicate `deno-cache` key,
   unpinned/latest images, missing healthchecks, kong key placeholders, check_ports
   path discrepancy, …) to its owning agent (I-02, M-01..M-10, M-13, M-30, D-04,
   I-34, I-77, S-08, S-15/S-16).
7. **Sources** section — every fetched/consulted URL plus Juega read-only reference.

### Daily log (this file)

Per AGENTS.md documentation standards: what/decisions/mistakes/commands/verification.

---

## Decisions made and why

- **Document the target state, not the current state, as the spec.** The repo
  compose files are mid-remap (I-02/M-01..M-10); SELFHOSTING.md is the agreed
  "what it must become" so those agents have an exact blueprint. Every target is
  grounded in the approved port map (AGENTS.md) and the official Supabase compose.
- **Internal container ports documented as "keep 5432/8000/… inside the network".**
  Prevents the classic over-correction where the remap changes *container* ports too
  (matching D-01's `INFO`-classification decision in check_ports.sh).
- **pgTAP documented with two paths** (CLI `supabase db test` — blocked pre-remap;
  direct `psql` against 54382 — works today) because the CLI path is genuinely
  broken by the `[db] port = 5432` config.toml until I-02 lands.
- **Deviations table rows cite `file:line`** and cross-reference FILE-OWNERSHIP
  owners; nothing was "fixed" (out of scope — I-02/M-* own those files).
- **No secrets, no invented deployment URLs** — placeholder conventions only;
  deployment URLs deferred to D-10's DEPLOYMENT-PLACEHOLDER.md.

## MISTAKE / gotcha

- **MISTAKE (caught by verification, not assumption):** first draft assumed
  `supabase/docker-compose.yml` was merely stale-but-parseable. Running
  `docker compose config --quiet` proved it **fails to parse**: duplicate
  `deno-cache:` mapping key (lines 198–199). Recorded as deviation row #15 — this
  blocks ANY `docker compose up` in `supabase/` even after the port remap, so
  M-01..M-05 must dedupe it. The `supabase-testing/` stack parses fine (only the
  obsolete `version:` warning).
- **Gotcha:** `reset.sh`'s `psql -h localhost` with no `-p` would connect to host
  port 5432 = **Juega's pooler** — worse than a bind failure; it would migrate/seed
  the wrong database. Flagged prominently in §3.1/§6 (row 11).
- **Gotcha:** `migrate.sh` re-applies every migration every run (no tracking table);
  documented the idempotency requirement instead of assuming re-runs are safe.

## Commands run (reproducibility)

```bash
# Repo read (mandatory first step) — full tree + every infra/script/doc file
ls -R supabase supabase-testing docs test tools
# read: docker-compose*.yml x2 dirs, config.toml x2, migrate/reset/run.sh x2,
# seed.sql, kong.yml, kong-entrypoint.sh, pooler.exs, Caddyfile, nginx tpl,
# .env x2, Makefile, README.md, test/README.md, AGENTS.md,
# docs/process/{AGENT-RULES,FILE-OWNERSHIP,ORCHESTRATION,AGENT-REGISTRY}.md,
# docs/specs/product/samay_mvp_spec.md §3-4, docs/specs/steps/{INFR,DEPL},
# docs/history/phase-00-foundation/D01..D06 logs, docs/to-fix/{README,13-DOCKER},
# tools/{agent_lock,check_ports}.sh, test/{opt-001,run_all_backend}.sh,
# test_runner.sh (head), supabase/tests/schema_test.sql (head), .env.example, .gitignore

# Read-only verification (no containers started, Juega untouched)
docker compose config --quiet   # supabase/        → FAIL: duplicate key "deno-cache" (lines 198-199)
docker compose config --quiet   # supabase-testing/ → OK (obsolete `version:` warnings only)
rg -n "5432:5432|54321:8000|54443:8443" supabase/docker-compose.yml supabase-testing/docker-compose.yml
rg -n "localhost:54321" supabase/docker-compose.yml supabase-testing/docker-compose.yml
grep -n "54321\|54382\|54386" test/router/app_router_test.dart
diff supabase/seed.sql supabase-testing/seed.sql                      # identical
diff supabase/tests/schema_test.sql supabase-testing/tests/schema_test.sql  # header note only
grep -n "KONG_HTTP_PORT\|POSTGRES_PORT\|KONG_HTTPS_PORT" /Users/daerean/Codes/apps/Juega/supabase/.env   # read-only

# Lock protocol (evidence)
mkdir -p <private-ops-repo>
tools/agent_lock.sh acquire <private-ops-repo>/SELFHOSTING.md --owner D-08
tools/agent_lock.sh acquire docs/history/phase-00-foundation/2026-08-09_D08-selfhosting-doc.md --owner D-08
tools/agent_lock.sh list    # 2 locks held by D-08
# ... write files ...
tools/agent_lock.sh release <private-ops-repo>/SELFHOSTING.md --owner D-08
tools/agent_lock.sh release docs/history/phase-00-foundation/2026-08-09_D08-selfhosting-doc.md --owner D-08
```

## Verification

- [x] Every claim about current repo state grepped/verified against the working
      tree (compose ports, config.toml ports, script defaults, migration parity,
      `.env` values, test defaults, test_runner.sh:4, app_router_test.dart:111).
- [x] Compose parse check actually run (read-only): `supabase/` broken (duplicate
      `deno-cache`), `supabase-testing/` OK — recorded, not silently assumed.
- [x] Every agent ID cited (I-02, M-01..M-10, M-13, M-30, D-04, D-10, I-34, I-77,
      S-08, S-15/S-16, V-04, D-01) exists in `docs/process/FILE-OWNERSHIP.md`
      (spot-checked rows: I-02 lines 34–35, M-01..M-10 lines 122–125, M-30 line 145,
      D-04 line 20, I-34 line 67, M-13 line 128, S-08 line 191, I-77 line 114).
- [x] Official image tags cross-checked against fetched `supabase/supabase@master`
      `docker/docker-compose.yml` (2026-08-09); Juega versions read read-only.
- [x] No commits; no Juega files touched; no docker stack started; no ports used.
- [x] No secrets written; deployment URLs are placeholders (deferred to D-10).
- [x] Lock evidence: acquired + released on both new files (see Commands).

## Issues found (reported, NOT fixed — out of scope)

1. **`supabase/docker-compose.yml` is unparseable** (duplicate `deno-cache:` key,
   lines 198–199) — `docker compose up` cannot run at all until M-01..M-05 dedupes.
2. **`reset.sh` without `-p` would hit Juega's pooler (host 5432)** if run today —
   M-10 must add `-p 54382` (rows 11 in §6).
3. **supabase-testing still missing `20260724000002`** (17 vs 18 migrations) — the
   testing stack keeps PUBLIC EXECUTE on `donate_shards_to_group` (D-04 flagged
   first; row 14).
4. **Key mismatch risk:** opt-test default keys (`sb_publishable_q7ND…`) vs
   `kong.yml` `keyauth_credentials` placeholders — tests will fail against the
   compose stack until M-09 aligns keys (row 22).
5. FILE-OWNERSHIP lists `tools/check_ports.sh` (M-30) but the file lives at
   `tools/check_ports.sh` (D-01's) — path/owner to reconcile (row 25, D-01's note).

## Sources consulted

- <https://supabase.com/docs/guides/self-hosting/docker> (self-hosting compose,
  ports, health, run.sh/reset.sh semantics)
- <https://github.com/supabase/supabase/tree/master/docker> — raw
  `docker/docker-compose.yml` fetched 2026-08-09 for current image tags + healthchecks
- <https://supabase.com/docs/reference/cli/config> (config.toml reference:
  api.port/db.port/studio.port/inbucket.port/analytics.port defaults)
- <https://docs.docker.com/reference/compose-file/services/> (healthcheck +
  depends_on long syntax)
- Juega (READ-ONLY): `/Users/daerean/Codes/apps/Juega/supabase/docker-compose.yml`,
  `docker-compose.nginx.yml`, `.env` — env-driven ports + pinned-image pattern
