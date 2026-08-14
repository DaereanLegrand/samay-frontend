# 2026-08-10 — M-12: Makefile Docker/Supabase half — targets refresh (OVERRIDES, minio reset), pgTAP + backend gates

**Agent:** M-12 (Phase 4.3 — Makefile track, Supabase/Docker targets)
**Role:** Refresh the docker/supabase Makefile targets that predate the M-series
overhaul: `OVERRIDES` passthrough to compose commands, minio volume removal on
reset (M-06 gotcha), env-driven-port consistency, keep the testing twins in
sync; add `supabase-db-test` (pgTAP for the self-hosted stack), the live
`supabase-backend-tests` gate, and the static `supabase-stack-check`; update
the SELFHOSTING.md runbook + TODO.md.
**Campaign:** Samay 180-agent orchestration, branch `fixes`; Juega untouched
(read-only), NO commits, NO containers started, NO image pulls — verification
is dry-run/parse-only (`make -n`, `docker compose config --quiet`, static
gates).

---

## What was built

### 1. `Makefile` — Docker/Supabase section (owner M-12 ✅, FILE-OWNERSHIP row)

- **`OVERRIDES ?=` passthrough (new variable):** `supabase-docker-start` and
  `supabase-testing-start` run `docker compose $(OVERRIDES) up -d --wait`.
  Default (empty) = each stack's `.env` `COMPOSE_FILE` layering (pg17+s3;
  testing adds mailpit — DKR-02/M-06); `make supabase-docker-start
  OVERRIDES="-f docker-compose.yml"` = base-only (file backend). Documented in
  the section comment. `down`/`ps` intentionally stay override-free (project
  identity comes from `.env`; nothing to layer for a teardown/status).
- **`supabase-docker-reset` / `supabase-testing-reset` now clear the MinIO
  named volume** (M-06 issue #2): after `docker compose down` +
  `rm -rf volumes/db/data volumes/storage`, each runs
  `docker volume rm samay_minio-data` resp. `samay-testing_minio-data`
  inside a `( … || true )` subshell guard — the volume may not exist on a
  fresh clone, and the name is fixed by `COMPOSE_PROJECT_NAME` +
  `minio-data` (guarded with the actual volume name, per mission).
  Note: `reset.sh` itself still does NOT clear it (M-15/parity scope —
  reported, not changed).
- **`supabase-db-test` (new):** the pgTAP invocation for the self-hosted
  stack. Research verdict (see Decisions): `supabase db test --db-url
  "postgres://postgres:postgres@localhost:54382/postgres" -- supabase/tests/schema_test.sql`.
  The target gates on `nc -z 127.0.0.1 54382` (clear "start the stack first"
  error) and on `supabase` CLI presence (psql fallback command printed).
  `PGTAP_DB_URL ?=` variable overrides the URL.
- **`supabase-backend-tests` (new):** gates on `nc -z 127.0.0.1 54386` (Kong,
  approved port — clear "start + reset first" error), then runs the canonical
  `bash test/run_all_backend.sh` (auto-discovered opt-001..007; 001-006 are
  the live curl tests, 005/007 static gates that pass anywhere).
- **`supabase-stack-check` (new):** the static gates — `bash
  test/opt-005-seed-dev-static.sh` + `bash test/opt-007-compose-static.sh` +
  `tools/check_ports.sh --strict` (explicit list per mission; = the
  no-stack pre-CI stack gate).
- **`supabase-seed-dev` re-verified (no change):** after M-02's env-driven
  ports, `-p 54382` is still the correct psql form — it is the approved
  `POSTGRES_PORT` default carried by both `.env` files, and
  `test/opt-005-seed-dev-static.sh` §8 **pins** this exact psql pattern in
  the Makefile (grep for `-p 54382` inside the target block). Switching to
  `${POSTGRES_PORT:-54382}` would break the gate for zero benefit.
- **`supabase-docker-status`/`-stop` + `supabase-testing-*` verified as-is:**
  `docker compose ps` shows health; `down` needs no override layering. The
  testing twins mirror the main stack behavior (incl. `OVERRIDES` + the
  `samay-testing_minio-data` volume rm).
- **CLI `supabase-*` targets (start/stop/status/reset) documented as the
  mutually-exclusive alternative:** the config.toml remap is live (`[db] port
  = 54382`, row 7 ✅), so bare `supabase start` no longer collides with Juega
  — but the CLI stack binds the SAME approved ports as the compose stack, so
  run EITHER workflow, never both. Comment added.
- `.PHONY` extended: `supabase-db-test supabase-backend-tests supabase-stack-check`.

### 2. `<private-ops-repo>/SELFHOSTING.md` (D-08's file, locked per mission)

- Header "Last verified" → M-12.
- **§3.2 pgTAP rewritten:** the old "CLI path BLOCKED until I-02 remaps
  config.toml" is obsolete — the canonical self-hosted invocation is now
  `supabase db test --db-url …54382…` (= `make supabase-db-test`), with the
  mechanism documented (CLI v2.113.0 connects to the URL, enables `pgtap` in
  the `extensions` schema, runs pg_prove via the `supabase/pg_prove:3.36`
  docker image on the host network; first run pulls it). Bare `supabase db
  test` explicitly NOT the self-hosted path (CLI-managed stack = port
  conflict). psql fallback kept (no CLI/docker needed).
- **§3.3 opt-tests:** `make supabase-backend-tests` (gated, chains 001..007)
  + `make supabase-stack-check` (static gates incl. `check_ports --strict`).
- **§4 onboarding runbook:** steps 3/5/6 now use the make targets
  (`OVERRIDES=` subset note, `make supabase-docker-reset`, `make
  supabase-db-test`, `make supabase-backend-tests`, `make supabase-stack-check`).
- **§5 Stale volumes / reset vs migrate:** documented that the Makefile reset
  targets DO clear the minio named volume (reset.sh still doesn't — M-15).
- **§6 deviations row 27 flipped ✅** with the M-12 decision + evidence.

### 3. `docs/to-fix/TODO.md` (D-03's file, locked per mission)

- M-12 workstream block at the top (newest-first, M-01..M-11 precedent)
  summarizing the six points + verification + evidence pointer.

### 4. `docs/history/phase-00-foundation/2026-08-10_M12-makefile-docker.md` (this log)

---

## Decisions made and why

- **`supabase db test --db-url` is THE pgTAP invocation for the self-hosted
  stack.** Research (CLI v2.113.0 installed at /opt/homebrew/bin/supabase):
  - `supabase db test --help` exposes `--db-url string — Tests the database
    specified by the connection string (must be percent-encoded)`.
  - Binary strings show the implementation: connect to the URL first (fail
    fast on refused — verified live: `failed to connect … dial error
    (connect ECONNREFUSED 127.0.0.1:54382)`, exit 1, when the stack is down
    — exactly the gate we want), `create extension if not exists pgtap with
    schema extensions`, then run pg_prove via the `supabase/pg_prove:3.36`
    docker image (`--ext .sql -r`, host network for non-local targets, test
    dirs bind-mounted read-only). Test paths resolve against cwd — the repo
    root invocation `supabase db test --db-url … -- supabase/tests/schema_test.sql`
    needs no `--workdir` (verified: got past config loading straight to the
    connection attempt).
  - The plain `supabase db test` form targets the CLI-managed stack (it would
    try to manage the compose stack's ports — conflicting on 54382/54386/…),
    so it is documented as NOT the self-hosted path.
  - Why not psql-only: the CLI form is the canonical pgTAP runner (plan
    validation, per-assertion results, exit codes, both stacks' files) and
    needs no extra host tooling beyond docker (already a stack prerequisite).
    The psql fallback (SELFHOSTING §3.2, already documented pre-M-12) stays
    for no-CLI/no-image environments and is printed by the target when the
    CLI is missing.
- **psql fallback kept for `supabase-seed-dev` + documented for db-test:**
  the seed target's literal `-p 54382` is a pinned contract
  (opt-005 §8 greps it) AND the approved default of the env-driven map —
  env-variable-izing would break the static gate for no gain (M-13's
  env-sourcing pass can revisit).
- **`docker volume rm … || true` on reset (not `down -v`):** `down -v` would
  also wipe `db-config` (pgsodium key persistence) and `deno-cache`, breaking
  the established reset semantics (reset.sh pattern: only bind dirs). The
  targeted volume rm keeps the reset exact: DB data, storage file backend,
  AND MinIO objects gone; pgsodium/deno caches survive (matching the
  documented gotcha fix in SELFHOSTING §5).
- **`supabase-backend-tests` runs `run_all_backend.sh` rather than an
  explicit opt-001..006 chain:** the runner is the canonical auto-discovering
  suite (SELFHOSTING §3.3), prints per-file summary, exits 0/1 — and the two
  static members (005/007) passing anywhere is harmless. New opt-NNN tests
  need no Makefile change.
- **`supabase-stack-check` spelled explicitly (not `test-backend-static` +
  check_ports):** the mission names opt-005 + opt-007 + check_ports; an
  explicit recipe is self-documenting and keeps `make -n` output obvious.
- **CLI targets kept, not removed:** they are a legit alternative dev
  workflow (port-safe vs Juega since the remap); removing them would be
  churn. Documented mutual exclusivity with the compose stack instead.

## MISTAKE / gotcha

- **MISTAKE (avoided):** first draft of the reset target appended
  `docker volume rm samay_minio-data 2>/dev/null || true` directly into the
  `&&` chain — a failing `rm -rf` or `down` would still be masked by the
  trailing `|| true` only if parenthesized. Wrapped the guard in a `( … )`
  subshell so only the volume-rm step is non-fatal; verified the dry-run
  renders the parens correctly.
- **Gotcha (research):** `supabase db test` flags are mutually exclusive —
  `[db-url linked local]` — so `--db-url` must stand alone (no `--local`).
- **Gotcha (research):** the CLI requires the connection string "percent-
  encoded" — `postgres://postgres:postgres@localhost:54382/postgres` contains
  no characters needing encoding (verified: it parses and attempts the
  connection).
- **Gotcha (verification):** piping the CLI's failure output through `head`
  swallowed the exit code in my first check — re-verified with zsh
  `$pipestatus` → exit 1 on connection refusal (the correct gate semantics).
- **Pre-existing (reported, NOT fixed):** `supabase/run.sh` still echoes a
  Mailpit endpoint for the prod stack with no mailpit service (M-10/M-06
  issue #1 — aligning would break the script-parity gate; M-15/checkpoint
  scope).

## Commands run (reproducibility)

```bash
export AGENT_NAME="M-12-makefile-docker"
tools/agent_lock.sh acquire Makefile --owner "$AGENT_NAME"            # +3 more (below)
tools/agent_lock.sh list    # 4 locks held by M-12-makefile-docker

# Research (read-only)
supabase --version                                  # 2.113.0
supabase db test --help                             # --db-url documented
strings /opt/homebrew/bin/supabase | grep -i pg_prove  # pg_prove:3.36 image, host network
supabase db test --db-url "postgres://postgres:postgres@localhost:54382/postgres" -- supabase/tests/schema_test.sql
#   → "failed to connect … ECONNREFUSED 127.0.0.1:54382", exit 1 (stack down = gate)
nc -z 127.0.0.1 54382 && echo UP || echo DOWN        # DOWN (no containers started)
docker ps                                            # Juega's stack only (read-only sighting)

# Dry-run gates — all 16 docker/supabase targets resolve
for t in supabase-start supabase-stop supabase-status supabase-reset \
         supabase-docker-start supabase-docker-stop supabase-docker-status \
         supabase-docker-reset supabase-db-test supabase-backend-tests \
         supabase-stack-check supabase-seed-dev \
         supabase-testing-start supabase-testing-stop \
         supabase-testing-status supabase-testing-reset; do
  make -n "$t" >/dev/null 2>&1 && echo "$t OK" || echo "$t FAIL"; done   # all OK
make -n supabase-docker-start OVERRIDES="-f docker-compose.yml"  # override flows

# Parse gates (both stacks, default COMPOSE_FILE layering; stack NOT started)
cd supabase && docker compose config --quiet && echo OK
cd ../supabase-testing && docker compose config --quiet && echo OK

# Static gates
bash test/opt-005-seed-dev-static.sh                 # exit 0 (all checks)
bash test/opt-007-compose-static.sh                  # exit 0 (all checks)
tools/check_ports.sh --strict                        # STRICT PASS, 0 violations

tools/agent_lock.sh release Makefile --owner "$AGENT_NAME"    # ×4, all released
```

## Verification

- [x] `make -n` resolves for ALL 16 docker/supabase targets (incl. the
      `OVERRIDES="-f docker-compose.yml"` override form — renders
      `docker compose -f docker-compose.yml up -d --wait`).
- [x] `docker compose config --quiet` exit 0 in both stacks (default
      COMPOSE_FILE combos — pg17+s3 / pg17+s3+mailpit); no containers
      started, Juega untouched.
- [x] `bash test/opt-005-seed-dev-static.sh` exit 0 — incl. §8 which pins
      the `supabase-seed-dev` psql pattern (unchanged, still matching).
- [x] `bash test/opt-007-compose-static.sh` exit 0 (compose parse + parity
      + env-driven-port gates green).
- [x] `tools/check_ports.sh --strict` → **STRICT PASS, 0 violations** (no
      hardcoded host ports introduced; the new targets carry none).
- [x] pgTAP invocation verified dry (stack down): clean ECONNREFUSED 54382,
      exit 1 — the documented gate behavior; full run deferred to the
      checkpoint stack start (first run pulls `supabase/pg_prove:3.36`).
- [x] Lock evidence: 4 files acquired + released by `M-12-makefile-docker`.
- [x] No commits; no `git add`; Juega untouched; no containers started, no
      image pulls.

## Lock list (acquire → release, owner `M-12-makefile-docker`)

1. `Makefile` (targets refresh + new targets + .PHONY)
2. `<private-ops-repo>/SELFHOSTING.md` (§1 header, §3.2/§3.3, §4, §5, §6 row 27)
3. `docs/to-fix/TODO.md` (M-12 workstream block)
4. `docs/history/phase-00-foundation/2026-08-10_M12-makefile-docker.md` (this log)

## Target inventory (final)

| Target | Action | Stack needed |
|---|---|---|
| `supabase-docker-start` | `docker compose $(OVERRIDES) up -d --wait` (`.env` COMPOSE_FILE layering by default) | no |
| `supabase-docker-stop` | `docker compose down` | no |
| `supabase-docker-status` | `docker compose ps` (health incl.) | no |
| `supabase-docker-reset` | down + rm db/storage dirs + `docker volume rm samay_minio-data` + up | no |
| `supabase-db-test` | pgTAP: `supabase db test --db-url …54382…` (gate: nc 54382) | **yes** (DB up) |
| `supabase-backend-tests` | gate nc 54386 → `bash test/run_all_backend.sh` (opt-001..007) | **yes** (Kong up) |
| `supabase-stack-check` | opt-005 + opt-007 + `check_ports.sh --strict` | no |
| `supabase-seed-dev` | psql -p 54382 seed-dev.sql (unchanged, opt-005 §8-pinned) | **yes** (DB up) |
| `supabase-testing-start/stop/status/reset` | twins of the above (`samay-testing_minio-data`) | — |
| `supabase-start/stop/status/reset` | CLI-managed alternative (mutually exclusive with compose) | — |

## Issues found / handoffs (reported, NOT fixed)

1. **reset.sh (×2) still does NOT clear the minio named volume** — only the
   Makefile targets do (M-12). Aligning reset.sh would touch M-10's
   script-parity gate (script diffs are pinned byte-for-byte modulo identity
   tokens) — handoff to M-15/checkpoint.
2. **`supabase db test --db-url` first run pulls `supabase/pg_prove:3.36`**
   — needs the registry reachable at the checkpoint stack start.
3. **`supabase/run.sh` echoes a Mailpit endpoint for the prod stack with no
   mailpit service** — pre-existing (M-10 issue #1 / M-06 issue #4),
   unchanged.
4. **Category-file status flips are D-03's** at re-verification (MKE-06
   docker half / row 27 evidence in TODO.md + SELFHOSTING.md + this log —
   M-01..M-11 precedent).

## Sources consulted

- Supabase CLI — `supabase db test` (`--db-url` flag, mutually-exclusive
  flag group, pg_prove runner): verified locally against the installed
  binary v2.113.0 (`supabase db test --help`, `strings` on the binary —
  `supabase/pg_prove:3.36`, host-network non-local targets, pgtap enable +
  drop-finalizer semantics) + <https://supabase.com/docs/reference/cli/supabase-db-test>
- Supabase — Self-Hosting with Docker (pgTAP/pg_prove on the self-hosted
  stack, `run.sh`/`reset.sh`): <https://supabase.com/docs/guides/self-hosting/docker>
- Docker Compose — `up -d --wait` + `COMPOSE_FILE` layering + override
  merges: <https://docs.docker.com/compose/how-tos/overrides/>
- Repo: `<private-ops-repo>/SELFHOSTING.md` (§3.2/§3.3/§5, row 27),
  `docs/history/phase-00-foundation/2026-08-10_{M01-compose-base,M02-env-compose,
  M06-overrides,M11-makefile-flutter}.md`,
  `test/opt-005-seed-dev-static.sh` (§8 pin), `test/run_all_backend.sh`,
  `tools/check_ports.sh`, `docs/process/{AGENT-RULES,FILE-OWNERSHIP,
  DEVELOPMENT-WORKFLOW}.md`, AGENTS.md (Port Convention)
