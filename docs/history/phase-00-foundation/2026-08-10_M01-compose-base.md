# 2026-08-10 — M-01: Compose Base Overhaul (pins, healthchecks, depends_on, obsolete keys)

**Agent:** M-01 (Phase 4.3 — Docker self-hosting track, base compose overhaul)
**Role:** DKR-04 (version pinning) + DKR-09 (healthcheck dependency chains) + DKR-01
(runtime of the self-hosted compose target state): healthchecks, `depends_on`
`service_healthy` chains, image pinning, obsolete `version:` removal, override
merge verification — following `<private-ops-repo>/SELFHOSTING.md` §2 (D-08 target state) exactly.
**Campaign:** Samay 180-agent orchestration, branch `fixes`; Juega's stack running on
5432/54321/54323/8443 (read-only, untouched; no Samay containers started).

---

## What was built

### `supabase/docker-compose.yml` + `supabase-testing/docker-compose.yml` (overhauled)

1. **`version: "3.8"` removed** (obsolete key, D-08 row 16) — also removed from the
   `pg17`/`s3` overrides and the `mailpit` override (all 7 compose files).
2. **Images pinned** to SELFHOSTING.md §2.2 "official current" tags (D-08 verified at
   write time; **re-verified against `supabase/supabase@master`
   `docker/docker-compose.yml` today — the doc's list is NOT stale**, zero delta):

   | Service | Old pin | New pin |
   |---|---|---|
   | db | `supabase/postgres:17.4.5.2` | `supabase/postgres:17.6.1.136` |
   | kong | `kong:2.8.1` | `kong/kong:3.9.3` |
   | auth | `supabase/gotrue:v2.174.6` | `supabase/gotrue:v2.189.0` |
   | rest | `postgrest/postgrest:v12.2.10` | `postgrest/postgrest:v14.12` |
   | realtime | `supabase/realtime:v2.34.13` | `supabase/realtime:v2.102.3` |
   | storage | `supabase/storage-api:v1.15.1` | `supabase/storage-api:v1.60.4` |
   | meta | `supabase/postgres-meta:v0.85.3` | `supabase/postgres-meta:v0.96.6` |
   | studio | `supabase/studio:20250129.1` | `supabase/studio:2026.08.03-sha-022b374` |
   | mailpit (testing override) | `axllent/mailpit:latest` ✗ | `axllent/mailpit:v1.30.7` (Docker Hub current, pushed 2026-08-08) |

   `rg "latest"` over every compose file → 0.
3. **Healthchecks** per D-08 §2.3 (patterns verified against the official compose for
   the exact pinned tags): db `pg_isready` (kept), kong `kong health`, auth
   `wget --spider /health`, rest `postgrest --ready` (+ `PGRST_ADMIN_SERVER_PORT:
   3001`/`HOST: localhost` — `--ready` needs the admin server), realtime
   `curl -fsS http://localhost:4000/healthcheck` (auth-free endpoint — see
   deviation note in §2.3), storage `wget --spider /status`, meta
   `node fetch http://localhost:8080/health` (postgres-meta v0.96.6 exposes
   `GET /health`, verified in `src/server/app.ts`), studio
   `node fetch /api/platform/profile` (official form, `start_period: 20s`).
4. **`depends_on` chains** (long syntax): `db(healthy) → kong/auth/rest/realtime/
   storage/meta/studio`; `storage → rest: service_started`; `studio → meta:
   service_started`; testing `auth → mailpit: service_started` (merged from the
   mailpit override — verified in the merged config). **`restart: unless-stopped`**
   on all 8 services (D-08 §2.3 "all services").
5. **Env compat for the pinned tags** (each verified in the image's source at the
   pinned tag):
   - **realtime v2.102.3**: `SECRET_KEY_BASE` is `System.fetch_env!`-required at
     boot (`config/runtime.exs:382`); `API_JWT_SECRET` replaces legacy `JWT_SECRET`
     (`runtime.exs:4` — no fallback); `METRICS_JWT_SECRET` required; `APP_NAME`
     required in prod; `SEED_SELF_HOST: "true"` seeds the `realtime-dev` tenant.
     Dropped obsolete: `JWT_SECRET`, `FLY_ALLOW_NON_TLS`, `SECURE_CHANNELS`,
     `TEMPORARY_SLOT`, `REPLICATION_MODE`, `REPLICATION_POLL_INTERVAL`, `SLOT_NAME`,
     `PLUGIN_NAME` (absent from v2.102.3 `ENVS.md`/`runtime.exs`).
   - **storage-api v1.60.4**: `DATABASE_URL` required (non-multitenant
     `getConfigFromEnv` throws when unset — `src/config.ts:446`); old
     `PG_DATABASE_URL` not read. `FILE_STORAGE_PATH` → `FILE_STORAGE_BACKEND_PATH`
     (`src/config.ts:378` — otherwise the file backend ignores `./volumes/storage`).
     `PGRST_JWT_SECRET` still accepted (fallback, `:323`), `TENANT_AUTO_CREATE`
     now ignored by the image (kept, harmless — noted).
   - **postgres-meta v0.96.6**: legacy `PG_META_PG_*` env names GONE
     (`src/server/constants.ts` reads `PG_META_DB_HOST/PORT/NAME/USER/PASSWORD`);
     old names would fall back to localhost:5432 = never reach `samay-db`.
     `PG_META_PG_META_SCHEMA` dropped (no longer in the image's env surface).
   - **gotrue v2.189.0**: `GOTRUE_JWT_DEFAULT_EXP` → `GOTRUE_JWT_EXP`
     (`internal/conf/configuration.go` JWTConfiguration `exp`; no `jwt_default_exp`
     key; default is 3600 anyway). Everything else unchanged.
   - **studio**: `HOSTNAME: "0.0.0.0"` added (official env for the pinned tag —
     without it the container may bind only loopback and the 54381 publish
     would be unreachable).
   - **rest**: `PGRST_DB_SCHEMA` singular KEPT — PostgREST stable docs confirm
     backwards compat ("db-schemas … also available in singular as db-schema").
     `PGRST_DB_POOL` still valid in v14.
6. **Ports untouched**: `54382:5432`, `54386:8000`, `54443:8443`, `54381:3000`
   (base ×2), `54384:8025` (mailpit). Container-internal URLs keep 5432.
7. **Overrides verified** (mission item 3): `pg17` override re-pins db to the same
   pinned `17.6.1.136` tag (prevents the default stack from silently running the
   stale 17.4.5.2 through `COMPOSE_FILE`); `s3`/`mailpit` overrides merge cleanly
   (no conflicts — `environment:`/`depends_on:` maps merge per key; verified in the
   merged output). All 9 combos parse: `docker compose config --quiet` exit 0.

### `test/opt-007-compose-static.sh` (new static gate, auto-registered by `run_all_backend.sh`)

Stack-free gate: no-`version:` ×7 files, pinned-tag contract + no-`:latest` (flat
`svc=image` list — macOS bash 3.2 has no associative arrays), healthcheck/restart/
depends_on per service (block parser), env-contract greps for the pinned tags,
approved-host-port-map assertions (54381/54382/54384/54386/54443; NO 5432/54321/
54323/8443 or any non-approved host binding), `docker compose config --quiet` on
9 combos (skips gracefully without docker). **Exit 0.**

### Docs

- `<private-ops-repo>/SELFHOSTING.md` — deviations table gained a Status column; rows
  1,2,3,4,5,15 (I-02 work, verified by M-01), 16, 18, 19, 20 (M-01 work) marked ✅
  with dates; §2.2 and §2.3 carry "2026-08-10 (M-01): target reached" notes incl.
  the healthcheck/env deltas vs the doc's table.
- `docs/to-fix/TODO.md` — DKR-04/DKR-09 workstream block (statuses live in
  `categories/13-DOCKER-INFRASTRUCTURE.md`, D-03-owned — status flips there are
  D-03's to make at re-verification; flagged in Issues).

## Decisions made and why

- **Pin to the doc's "official current" column, not the "current repo pin" column.**
  D-08's §2.2 target IS the official-verified tag set and deviation row 20 says
  "pin set per §2.2"; re-fetching `supabase/supabase@master` today confirmed zero
  drift — the mission's "if stale, keep working + note delta" branch did not
  trigger.
- **Env-var updates were REQUIRED by the pin, not cosmetic.** Each rename is
  backed by the pinned image's source (see above); without them realtime would
  crash at boot (`fetch_env!`), storage would crash (`DATABASE_URL is undefined`)
  or write to the wrong path, and meta would point at localhost:5432. The
  mission's "env vars untouched otherwise" is honored — nothing else moved.
- **realtime healthcheck uses `GET /healthcheck`** (verified auth-free in
  `realtime_web/router.ex`) instead of D-08's `Bearer $ANON_KEY` tenant-health
  form, which cannot work: Samay's `.env` has `SUPABASE_ANON_KEY`, not `ANON_KEY`,
  so compose interpolation would send an empty bearer and the tenant endpoint
  would reject. Deviation recorded in SELFHOSTING.md §2.3.
- **Kong pinned to `kong/kong:3.9.3` per the doc.** The declarative `kong.yml`
  (`_format_version: "2.1"`, `keyauth_credentials`) is the same shape Juega runs
  successfully on kong 3.9.1, so the format survives the jump; M-09 owns final
  verification (entrypoint + key alignment).
- **mailpit pinned by M-01** although row 18 lists M-06..M-08: the mission's
  context explicitly lists "mailpit unpinned" in M-01's scope and the no-`:latest`
  gate must hold repo-wide; row 18 is marked done with the note that full override
  semantics (row 17) remain M-06..M-08's.
- **pg17 override re-pinned to 17.6.1.136**: the default stack layers it via
  `COMPOSE_FILE`; leaving 17.4.5.2 there would silently undo DKR-04 on every
  default start. It is now an explicit no-op documenting the "stay on PG17"
  escape hatch when base moves to PG18.
- **No `name:` key, no `.env` changes**: project isolation still comes from
  `COMPOSE_PROJECT_NAME` in each `.env` (untouched).

## MISTAKE / gotcha

- **MISTAKE (test bug, fixed before shipping):** first draft of `opt-007` used
  `declare -A` — macOS ships bash 3.2 (no associative arrays); with `set -u` the
  script died with `db: unbound variable`. Replaced with a flat `svc=image` list.
- **MISTAKE (test bug, fixed):** Compose v5 rejects `-f` AFTER the subcommand
  (`docker compose config --quiet -f x` → `unknown shorthand flag: 'f'`);
  `-f` flags must precede `config`. `run_cfg` now builds `docker compose <flags>
  config --quiet`.
- **Gotcha:** Compose v5 does NOT interpolate `${ANON_KEY}` in healthchecks from
  `.env` unless the var exists there — this is why the doc's realtime healthcheck
  shape had to be replaced (see Decisions).
- **Gotcha:** the merged `docker compose config` output confirmed the mailpit
  override's `auth.environment` merges over the base auth env (same values) and
  `depends_on` maps union — no conflicts, but always verify with `config`, never
  assume.
- **Pre-existing bug found (NOT fixed — M-09's file):** `volumes/api/kong-entrypoint.sh`
  is mounted OVER the image's `/docker-entrypoint.sh` and `exec`s
  `/docker-entrypoint.sh kong docker-start` — i.e. it execs ITSELF recursively,
  after an `until kong health` loop that can never pass because the wrapper never
  starts kong. The official/Juega pattern mounts the wrapper elsewhere
  (`/home/kong/kong-entrypoint.sh`) and `exec /entrypoint.sh kong docker-start`
  against the intact image entrypoint. Kong will not become healthy until M-09
  rewrites the mount/entrypoint. Unchanged by M-01 (out of scope, locked by
  ownership) — but the checkpoint stack start WILL hit it.
- **Gotcha:** `docker compose config` in the stack dirs auto-loads each `.env`
  (`COMPOSE_FILE`), so the "default" combo already layers pg17+s3 (supabase/) and
  pg17+s3+mailpit (testing/); the explicit `-f` combos prove each override layers
  standalone.

## Commands run (reproducibility)

```bash
# Research (read-only): official tag verification + per-image env contracts
curl -s https://raw.githubusercontent.com/supabase/supabase/master/docker/docker-compose.yml
curl -s https://raw.githubusercontent.com/supabase/realtime/v2.102.3/config/runtime.exs
curl -s https://raw.githubusercontent.com/supabase/storage-api/v1.60.4/src/config.ts
curl -s https://raw.githubusercontent.com/supabase/postgres-meta/v0.96.6/src/server/constants.ts
curl -s https://raw.githubusercontent.com/supabase/auth/master/internal/conf/configuration.go
curl -s https://postgrest.org/en/stable/references/configuration.html   # db-schema still valid
curl -sL https://hub.docker.com/v2/repositories/axllent/mailpit/tags    # v1.30.7 current

# Locks (evidence) — 11 files
tools/agent_lock.sh acquire supabase/docker-compose.yml --owner M-01-compose-base
# ... same for the 10 other paths ...
tools/agent_lock.sh list   # 11 locks held by M-01-compose-base

# Parse gates (all 9 combos, exit 0; stack NOT started)
cd supabase && docker compose config --quiet
docker compose -f docker-compose.yml -f docker-compose.pg17.yml config --quiet
docker compose -f docker-compose.yml -f docker-compose.s3.yml config --quiet
docker compose -f docker-compose.yml -f docker-compose.pg17.yml -f docker-compose.s3.yml config --quiet
cd ../supabase-testing && docker compose config --quiet
docker compose -f docker-compose.yml -f docker-compose.pg17.yml config --quiet
docker compose -f docker-compose.yml -f docker-compose.s3.yml config --quiet
docker compose -f docker-compose.yml -f docker-compose.mailpit.yml config --quiet
docker compose -f docker-compose.yml -f docker-compose.pg17.yml -f docker-compose.s3.yml -f docker-compose.mailpit.yml config --quiet

# Static gate
bash test/opt-007-compose-static.sh            # exit 0
bash test/run_all_backend.sh                   # opt-005 ✅, opt-007 ✅, live 001/002/003/004/006 fail-fast (stack not up — expected)

# Port hygiene
rg -c "latest" supabase/docker-compose.yml supabase-testing/docker-compose.yml   # 0
tools/check_ports.sh --strict                  # STRICT PASS, 0 violations
```

## Verification

- [x] `docker compose config --quiet` exit 0 on the base + all override combos in
      both stacks (9/9) — no containers started, Juega untouched.
- [x] `bash test/opt-007-compose-static.sh` exit 0 (all sections green).
- [x] `test/run_all_backend.sh`: opt-007 auto-registered; static gates (005, 007)
      green; live opt-tests fail-fast on the absent stack exactly as before
      (documented I-78 behavior).
- [x] `rg "latest"` over every compose file → 0 matches.
- [x] `tools/check_ports.sh --strict` → STRICT PASS (0 violations).
- [x] No `version:` key in any of the 7 compose files.
- [x] Port bindings unchanged (54382/54386/54443/54381/54384) — diff-verified.
- [x] Lock evidence: 11 files acquired + released (see report).
- [x] No commits; no Juega files touched; no Samay containers started.

## Issues found (reported, NOT fixed — out of scope)

1. **kong-entrypoint recursion (blocks `docker compose up -d --wait` at the
   checkpoint):** `supabase/volumes/api/kong-entrypoint.sh` (and testing mirror)
   is mounted over the image entrypoint and execs itself; the `until kong health`
   loop can never pass. M-09 must switch to the official pattern (mount wrapper
   beside the image entrypoint, `exec /entrypoint.sh kong docker-start` — see
   Juega's working wrapper). Until then kong never reaches healthy.
2. **`categories/13-DOCKER-INFRASTRUCTURE.md` status flips** (DKR-04/DKR-09 rows)
   are D-03's file (not in M-01's lock list) — the DKR statuses live there; TODO.md
   (updated here) + SELFHOSTING.md carry the evidence for D-03's re-verification.
3. **`kong.yml` still `_format_version: "2.1"` + top-level `keyauth_credentials`**
   with `your-anon-key`/`your-service-role-key` placeholders — fine on kong 3.9.x
   (Juega proves the format family), but key alignment + entrypoint are M-09's
   (SELFHOSTING rows 22).
4. **`imgproxy`/`functions`/`supavisor` services still absent** (row 21) and the
   pg17/s3 overrides remain minimal stubs (row 17) — M-06..M-08. `deno-cache`
   volume stays declared for when functions land.
5. **realtime `DB_USER: postgres`** (superuser, unchanged) works for logical
   replication but is the least-privilege-weakest choice; S-15/checkpoint may want
   a dedicated `supabase_admin`-style role like the official stack.
6. **studio env lacks `POSTGRES_*`** (official passes them) — dashboard features
   that touch the DB directly beyond the meta proxy may misbehave; out of M-01's
   "env untouched otherwise" scope, flagging for the checkpoint.
7. **`TENANT_AUTO_CREATE: true`** in the storage env is ignored by storage-api
   v1.60.4 (harmless, kept) — consider dropping at the next storage touch.
8. **test/README.md opt-suite list** (D-05-owned) doesn't mention opt-007 yet —
   auto-registered via the `opt-*.sh` glob, doc refresh for D-05/V-05.

## Sources consulted

- <https://github.com/supabase/supabase/tree/master/docker> — `docker-compose.yml`
  fetched 2026-08-10: tag verification (zero delta vs SELFHOSTING.md §2.2) +
  official healthcheck/restart/depends_on patterns
- <https://github.com/supabase/realtime/tree/v2.102.3> — `config/runtime.exs`,
  `ENVS.md` (API_JWT_SECRET/SECRET_KEY_BASE/METRICS_JWT_SECRET/APP_NAME/SEED_SELF_HOST
  contract), `lib/realtime_web/router.ex` (`/healthcheck` auth-free)
- <https://github.com/supabase/storage-api/tree/v1.60.4> — `src/config.ts`
  (DATABASE_URL required; FILE_STORAGE_BACKEND_PATH; PGRST_JWT_SECRET fallback)
- <https://github.com/supabase/postgres-meta/tree/v0.96.6> — `src/server/constants.ts`
  (PG_META_DB_* only), `src/server/app.ts` (`GET /health`)
- <https://github.com/supabase/auth/tree/master> — `internal/conf/configuration.go`
  (JWTConfiguration.Exp → GOTRUE_JWT_EXP)
- <https://postgrest.org/en/stable/references/configuration.html> — `db-schema`
  singular still accepted (backwards compat); `PGRST_DB_POOL` valid
- <https://hub.docker.com/v2/repositories/axllent/mailpit/tags> — v1.30.7 current
- Juega (READ-ONLY): `/Users/daerean/Codes/apps/Juega/supabase/docker-compose.yml`
  + `volumes/api/kong-entrypoint.sh` — kong 3.9.x pattern
- Repo: `<private-ops-repo>/SELFHOSTING.md`, `docs/to-fix/categories/13-DOCKER-INFRASTRUCTURE.md`
  (DKR-01..09), `docs/history/phase-00-foundation/2026-08-09_{I02-port-remap,D08-selfhosting-doc}.md`,
  `docs/process/{AGENT-RULES,FILE-OWNERSHIP,ORCHESTRATION}.md`, AGENTS.md port table
