# 2026-08-10 — M-02: Docker Env-Driven Configuration (DKR-03)

**Agent:** M-02 (Phase 4.3 — Docker env-driven configuration track)
**Role:** Remove hardcoded host ports from compose: both stacks' compose files
read `${VAR:-default}` with defaults matching the approved map
(54382/54381/54384/54386/54388/54443), `.env` becomes the explicit source of
truth, the rate-limit documentation fiction (M-10 issue #3) is fixed by making
compose consume `AUTH_RATE_LIMIT_EMAIL_SENT`, and the static gates
(`tools/check_ports.sh` + `test/opt-007-compose-static.sh`) understand the new
env-driven shape — following the Juega pattern SELFHOSTING.md §2.2 flagged.
**Campaign:** Samay 180-agent orchestration, branch `fixes`; Juega's stack
running on 5432/54321/54323/8443 (read-only, untouched; **no docker start, no
containers, no image pulls** — parse-only verification).

---

## What was built

### 1. `supabase/docker-compose.yml` + `supabase-testing/docker-compose.yml` (env-driven ports + URLs)

Every host binding now interpolates from env with the approved value as the
default (defaults NEVER touch Juega's 5432/54321/54323/8443):

| Service | Before (hardcoded) | After |
|---|---|---|
| `db` | `"54382:5432"` | `"${POSTGRES_PORT:-54382}:5432"` |
| `kong` | `"54386:8000"`, `"54443:8443"` | `"${KONG_HTTP_PORT:-54386}:8000"`, `"${KONG_HTTPS_PORT:-54443}:8443"` |
| `studio` | `"54381:3000"` | `"${STUDIO_PORT:-54381}:3000"` |

Internal URL envs follow the same var so a Kong port override propagates
everywhere (verified: `KONG_HTTP_PORT=54555` → `SUPABASE_URL:
http://127.0.0.1:54555` in the rendered config):

- `studio` `SUPABASE_URL` / `SUPABASE_PUBLIC_URL` → `http://127.0.0.1:${KONG_HTTP_PORT:-54386}`
- `rest` `PGRST_DB_OPENAPI_SERVER_PROXY_URI` → `http://127.0.0.1:${KONG_HTTP_PORT:-54386}`

Rate-limit fiction fixed (M-10 issue #3): `GOTRUE_RATE_LIMIT_EMAIL_SENT: 2`
→ `GOTRUE_RATE_LIMIT_EMAIL_SENT: ${AUTH_RATE_LIMIT_EMAIL_SENT:-2}` in both
stacks — compose now READS the env, so `.env` is the single source of truth.

### 2. `supabase-testing/docker-compose.mailpit.yml` (port binding)

`"54384:8025"` → `"${MAILPIT_PORT:-54384}:8025"`.

### 3. `.env` (both stacks) — port map as source of truth

- New **"Host port map — source of truth (DKR-03, M-02)"** section right after
  `COMPOSE_FILE`, listing all six approved host ports with comments:
  `POSTGRES_PORT=54382`, `STUDIO_PORT=54381`, `KONG_HTTP_PORT=54386`,
  `KONG_HTTPS_PORT=54443`, `MAILPIT_PORT=54384` (testing; documented inert in
  prod — no mailpit service there by design, SELFHOSTING §3.5),
  `ANALYTICS_PORT=54388`.
- The scattered stale copies were removed/consolidated: the old
  `KONG_HTTP_PORT=8000` / `KONG_HTTPS_PORT=8443` (container-port semantics
  that no compose entry read) and `POSTGRES_PORT=5432` are gone — one
  definition per var, and it is the HOST port now. `STUDIO_PORT` /
  `ANALYTICS_PORT` moved into the map section.
- `COMPOSE_FILE` gained a comment documenting which files compose layers
  (DKR-02/M-06) and how to run subsets via `-f`.
- `SUPABASE_PUBLIC_URL` in `.env` kept literal (compose interpolates it
  itself from `${KONG_HTTP_PORT:-54386}`; the .env value is documentation
  only — noted inline).
- **Testing `.env` rate limit:** `AUTH_RATE_LIMIT_EMAIL_SENT=10` → `2`
  (parity with prod — M-10's documented 10-vs-2 difference was a
  documentation fiction since compose hardcoded 2 in both stacks; now .env is
  consumed, so 2/2 is the honest single truth). Documented inline.

### 4. `tools/check_ports.sh` (D-01's file — locked + updated, mission-mandated)

- `parse_compose` gained two regexes: `- "${VAR:-54382}:5432"` (reports the
  default as host port, container port preserved) and the bare
  `- "${VAR:-54386}"` form. Hardcoded numeric forms still handled.
- `scan_references` (awk) gained a match-and-stitch expansion of
  `${VAR:-PORT}` → `PORT` **before** the host:port scan, so env-driven URL
  refs like `http://127.0.0.1:${KONG_HTTP_PORT:-54386}` are checked against
  the approved map. Implemented without `\1` backrefs (macOS BSD awk does not
  expand them in `gsub` — verified empirically).
- Stale 2026-08-09 header note ("violations EXPECTED until I-02 lands") —
  rewritten to describe the env-driven default reporting.
- Result: `--strict` STRICT PASS, 0 violations; the four base mappings +
  mailpit mapping all reported OK from their `${VAR:-default}` forms.

### 5. `test/opt-007-compose-static.sh` — §6 updated + new §11 (env-driven)

- **§6** binding scanner now matches the `${VAR:-default}:container` form
  (approved-default check) and FAILS on any hardcoded `"54382:5432"` literal
  (the old regex would have silently matched nothing and the required-binding
  greps would have failed — updated both).
- **§11 "Env-driven ports (DKR-03, M-02)"**:
  - 11.1 no hardcoded host-port literals in any of the 7 compose files;
  - 11.2 `SUPABASE_URL`/`SUPABASE_PUBLIC_URL`/`PGRST_DB_OPENAPI_SERVER_PROXY_URI`
    interpolate `${KONG_HTTP_PORT:-54386}` + auth reads
    `${AUTH_RATE_LIMIT_EMAIL_SENT:-2}` in both stacks;
  - 11.3 both `.env` files carry the six port keys + `AUTH_RATE_LIMIT_EMAIL_SENT=2`
    (prod also documents `MAILPIT_PORT=54384` though inert);
  - 11.4 (docker only) `docker compose config` resolves every approved
    `published:` port in both stacks' default combos; `GOTRUE_RATE_LIMIT_EMAIL_SENT:
    "2"` comes from `.env`; override roundtrips in a subshell with inline env
    vars — `POSTGRES_PORT=54444` → `published: "54444"` then restore →
    `published: "54382"`; `KONG_HTTP_PORT=54555` → `SUPABASE_URL:
    http://127.0.0.1:54555`; `MAILPIT_PORT=54666` (testing).
  - Gate total: **277 checks, exit 0**.

## Decisions made and why

- **`${VAR:-default}` with the approved value as the compose default** (not
  bare `${VAR}`): the parse stays standalone-clean when `.env` is absent (the
  s3 override already used this pattern, SELFHOSTING §2.5), and the default is
  a static guarantee that never collides with Juega even if `.env` is deleted.
- **`.env` = host ports, not container ports.** The old
  `KONG_HTTP_PORT=8000` was the official Supabase *container* port convention
  (official maps `8000:8000`); Samay's approved map is host-side
  `54386:8000`, so the var must be the host port. The container side stays a
  literal in the compose `ports:` mapping and in the `KONG_PROXY_LISTEN`
  envs — no conflict, one var one meaning.
- **Testing rate limit aligned to 2** (mission's "pick 2 for parity and
  document"). The testing stack is the CI/dev mirror of prod; a looser limit
  would only mask abuse in the environment where OTP flows are exercised
  (opt-001/opt-002).
- **`MAILPIT_PORT` documented in the prod `.env` too** — the prod stack has
  no mailpit service (SELFHOSTING §3.5 intentional difference), but the port
  map section is the single documented place for the approved map, and the
  key is inert there. Noted inline.
- **`SUPABASE_PUBLIC_URL` stays literal in `.env`**: dotenv files are not
  recursively interpolated by compose, and compose renders the URL itself
  from `${KONG_HTTP_PORT:-54386}` — the `.env` copy is documentation.
- **check_ports reports the `${VAR:-default}` DEFAULT, not runtime values** —
  the gate is a static repo check against the approved map; runtime overrides
  are a dev choice and remain the gate's reason for existing (they cannot be
  statically audited).

## MISTAKE / gotcha

- **MISTAKE (self-caught mid-edit):** first draft of the `parse_compose`
  edit added a duplicate numeric branch that would have mangled the container
  port (`BASH_REMATCH[0]%%:*` on the full match) — removed before running;
  only the two env-driven branches were added.
- **Gotcha (macOS awk):** BSD awk does NOT expand `\1` backreferences in
  `gsub` replacement strings (verified: `gsub(...,"\\1")` printed literal
  `\1`). The env expansion in `scan_references` uses a match-and-stitch loop
  instead.
- **Gotcha (zsh vs bash):** my first all-combos loop used unquoted `$combo`
  word-splitting, which zsh (the host shell) doesn't do by default → compose
  got the whole flag string as one filename. Re-run with explicit invocations;
  the opt-007 gate itself is fine (it runs under `bash`).
- **Gotcha:** `grep -q '54384:8025'` no longer matches the mailpit binding —
  the `}` after `54384` breaks the literal substring. §10.4 updated to the
  `\$\{MAILPIT_PORT:-54384\}:8025` regex (RED-proven: the gate failed on it
  once before the fix).
- **Pre-existing (reported, NOT fixed):** the two stray `.env` copies of
  `SUPABASE_PUBLIC_URL` and the container-name `STUDIO_PG_META_URL` values
  are still documentation-only (compose hardcodes the effective values) —
  M-13/S-08's env-consumption pass can finish making compose read them.

## Commands run (reproducibility)

```bash
# Locks (evidence) — 9 files, owner M-02-env-compose
tools/agent_lock.sh acquire supabase/docker-compose.yml --owner M-02-env-compose
# ... same for: supabase-testing/docker-compose.yml,
#     supabase-testing/docker-compose.mailpit.yml, supabase/.env,
#     supabase-testing/.env, tools/check_ports.sh,
#     test/opt-007-compose-static.sh, docs/to-fix/TODO.md,
#     <private-ops-repo>/SELFHOSTING.md
tools/agent_lock.sh list                      # 9 locks held by M-02-env-compose

# Parse gates (all 9 combos, exit 0; stack NOT started)
cd supabase && docker compose config --quiet && docker compose -f docker-compose.yml -f docker-compose.pg17.yml config --quiet && docker compose -f docker-compose.yml -f docker-compose.s3.yml config --quiet && docker compose -f docker-compose.yml -f docker-compose.pg17.yml -f docker-compose.s3.yml config --quiet
cd ../supabase-testing && docker compose config --quiet && docker compose -f docker-compose.yml -f docker-compose.pg17.yml config --quiet && docker compose -f docker-compose.yml -f docker-compose.s3.yml config --quiet && docker compose -f docker-compose.yml -f docker-compose.mailpit.yml config --quiet && docker compose -f docker-compose.yml -f docker-compose.pg17.yml -f docker-compose.s3.yml -f docker-compose.mailpit.yml config --quiet

# Resolved-approved-map + override roundtrip evidence
docker compose config | grep -E "published:"        # 54382/54386/54443/54381 (+54384 testing)
POSTGRES_PORT=54444 docker compose config | grep published   # db -> "54444"
docker compose config | grep published                        # restored -> "54382"
KONG_HTTP_PORT=54555 docker compose config | grep SUPABASE_URL   # http://127.0.0.1:54555
MAILPIT_PORT=54666 docker compose config | grep published       # testing -> "54666"

# Gates
bash test/opt-007-compose-static.sh          # exit 0 — 277 checks
bash test/run_all_backend.sh                 # opt-005 ✅, opt-007 ✅; live 001/002/003/004/006 fail-fast (stack not up — expected)
tools/check_ports.sh --strict                # STRICT PASS, 0 violations
bash -n tools/check_ports.sh test/opt-007-compose-static.sh   # ok
```

## Verification

- [x] `docker compose config --quiet` exit 0 on the base + every override
      combo in both stacks (9/9) — no containers started, Juega untouched.
- [x] Default combos resolve the approved map: `published: "54382"` /
      `"54386"` / `"54443"` / `"54381"` (both stacks) + `"54384"` (testing).
- [x] Override roundtrip: `POSTGRES_PORT=54444` → `published: "54444"`,
      restore → `"54382"`; `KONG_HTTP_PORT=54555` → `SUPABASE_URL:
      http://127.0.0.1:54555`; `MAILPIT_PORT=54666` → `"54666"` (subshell
      inline env, no shell/.env pollution).
- [x] `bash test/opt-007-compose-static.sh` exit 0 (277 checks, §11 green).
- [x] `tools/check_ports.sh --strict` STRICT PASS, 0 violations (env-driven
      mappings reported OK from their defaults).
- [x] `GOTRUE_RATE_LIMIT_EMAIL_SENT: "2"` in rendered configs (both stacks,
      from `.env`) — the M-10 fiction is now truth.
- [x] `rg -n '"5[0-9]{4}:[0-9]+"' supabase*/docker-compose*.yml` → 0
      hardcoded host-port literals.
- [x] Lock evidence: 9 files acquired + released by `M-02-env-compose`.
- [x] No commits; no Juega files touched; no Samay containers started.

## Issues found (reported, NOT fixed — out of scope)

1. **`docs/to-fix/categories/13-DOCKER-INFRASTRUCTURE.md` DKR-03 status flip
   is D-03's** (owner per FILE-OWNERSHIP; TODO.md + SELFHOSTING.md + this log
   carry the evidence for D-03's re-verification — M-01/M-09/M-10 precedent).
2. **`.env` `SUPABASE_PUBLIC_URL` / `STUDIO_PG_META_URL` remain
   documentation-only** (compose hardcodes the effective studio env values) —
   a follow-up env-consumption pass (M-13/S-08) could make compose read them
   too; today the env-driven URLs only cover the host-port-derived ones.
3. **`supabase/run.sh` prints a Mailpit endpoint for the prod stack that has
   no mailpit service** — pre-existing M-10 issue #1, unchanged (would break
   script parity; outside M-02's lock list).
4. **`test/README.md` opt-suite list (D-05-owned)** still doesn't mention
   opt-007's §11 — doc refresh for D-05/V-05 (M-01/M-10 flagged the same).

## Sources consulted

- Docker Compose — variable interpolation & `.env` precedence:
  <https://docs.docker.com/compose/environment-variables/envvars-precedence/>
  (shell env > `.env` — the override roundtrip relies on this)
- Docker Compose spec — `ports` long/short syntax:
  <https://docs.docker.com/reference/compose-file/services/#ports>
- Juega (READ-ONLY reference):
  `/Users/daerean/Codes/apps/Juega/supabase/docker-compose.yml` + `.env` —
  the env-driven port pattern (`${KONG_HTTP_PORT}`, `${POSTGRES_PORT}`) this
  mission adopts (SELFHOSTING §2.2 note)
- Repo: `<private-ops-repo>/SELFHOSTING.md`, `docs/to-fix/categories/13-DOCKER-INFRASTRUCTURE.md`
  (DKR-03), `docs/history/phase-00-foundation/2026-08-10_{M01-compose-base,
  M06-overrides,M10-parity}.md`, `docs/process/{AGENT-RULES,FILE-OWNERSHIP}.md`,
  AGENTS.md Port Convention, `tools/check_ports.sh` (D-01), `test/opt-007-compose-static.sh`
