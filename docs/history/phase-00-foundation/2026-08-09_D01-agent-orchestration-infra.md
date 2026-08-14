# D-01 — Agent Orchestration Infra: Port-Map Checker + AGENTS.md Protocol Verify

## Date: 2026-08-09

## Context

Agent **D-01** in the Samay 180-agent orchestration (sub-phase 4.1, documentation gap
closure). Mandate: (1) build `tools/check_ports.sh` — a repo-wide port-map consistency
checker with `--report` (exit 0) and `--strict` (exit 1 on violation) modes; (2) verify the
"Agent Orchestration Protocol" section of `AGENTS.md`; (3) write this daily log. All work on
branch `fixes`. Compose/config port remapping is I-02's job — this agent only detects.

## What was built

### `tools/check_ports.sh` (new, 400 lines, bash-3.2-compatible)
Scans every config/script/code file that binds or references ports and classifies each
finding against the approved port map (AGENTS.md Port Convention) and Juega's occupied
ports (5432/54321/54323/8443):

- **Approved map embedded:** db=54382, studio=54381, mailpit=54384, kong=54386,
  analytics=54388, kong_https=54443.
- **Scanned targets:** AGENTS.md (port table only — the source of truth), both
  `config.toml`s, all `docker-compose*.yml` in `supabase/` + `supabase-testing/`,
  both `run.sh`/`reset.sh`/`migrate.sh`, both `.env`/`.env.local`, `volumes/**`
  (kong.yml, pooler.exs, Caddyfile, nginx tpl, kong-entrypoint.sh), `Makefile`,
  `test_runner.sh`, `test/**` (`*.sh`, `*.dart`, `README.md`), `internal/**`, `cmd/**`,
  `lib/**`, `.env.example`. Docs (`docs/`) are excluded — they legitimately document
  Juega's ports.
- **Parsers:** compose `ports:` entries per service (host side only), TOML `port = N`
  per `[section]`, AGENTS.md table rows vs approved map, plus a generic reference pass
  (URLs, connection strings, bare env assignments) that distinguishes host-bound
  (`localhost`/`127.0.0.1`) from container-internal (`samay-*` hosts) references.
- **Classifications:** `OK` (approved) · `VIOLATION` (Juega collision OR non-approved
  host binding — deviation) · `INFO` (container-internal / bare env / external).
- **Modes:** `--report` (default) prints everything and exits 0 even with violations;
  `--strict` exits 1 if any violation exists. `--help` documents usage.
- **Current output (expected, until I-02 lands):** 30 mappings + 149 references;
  34 violations — the two compose files and both config.tomls still map db->5432 and
  kong->54321, plus stale `localhost:54321` env refs in compose/.env, `5432` defaults in
  migrate.sh/run.sh/test_runner.sh, and non-approved host bindings (9999/3000/4000/5000/
  8080, mailpit 8025/1025).

### `AGENTS.md` (1-line edit)
Verified the "Agent Orchestration Protocol" section: it exists and is accurate — it
references `docs/process/DEVELOPMENT-WORKFLOW.md`, `docs/process/DEVELOPMENT-WORKFLOW.md`,
`docs/process/FILE-OWNERSHIP.md`, `tools/agent_lock.sh`, `repo-locks/`, and the modular
integration suite (`integration_test/`, `test/opt-*.sh`, pgTAP). Only fix: heading said
"150-agent campaigns" but ORCHESTRATION.md (single source of truth) defines the campaign
as **180 agents** — aligned the number. Nothing else touched.

## Decisions

- **bash 3.2 compatibility:** default macOS bash is 3.2.57 — no `declare -A`, no
  `mapfile`. The first implementation used `[[ =~ ]]` per line and was pathologically
  slow (regex compile per line, ~35k lines); the reference pass was rewritten as one
  batched `awk` pass per file. Runtime: ~3.2s for the whole repo.
- **Container-internal refs are INFO, not violations:** `postgres://…@samay-db:5432/…`,
  `KONG_PROXY_LISTEN_SSL: 0.0.0.0:8443`, `POSTGRES_PORT=5432` all describe the
  *inside* of the docker network and legitimately keep port 5432/8443 there even after
  I-02 remaps the host side. Only `localhost`/`127.0.0.1` bindings to Juega ports are
  violations (they would actually hit Juega's stack).
- **AGENTS.md is scanned table-only** — its prose ("Juega owns 5432/54321/54323/8443",
  "5432 → 54382") is documentation, not a binding.
- **docs/ excluded** from scanning: ORCHESTRATION.md/AGENT-RULES.md/README.md/to-fix
  legitimately discuss Juega's ports.
- **Exit semantics per mission:** `--report` exit 0 (informational, even with
  violations — they are EXPECTED until I-02); `--strict` exit 1 on any violation, so the
  orchestrator can gate on it (e.g., M-30 CI wiring or V-04 verification).

## MISTAKE

- **MISTAKE:** bash 3.2 `=~` with a `[\"']` character class in the regex silently never
  matches (backslash-quote inside `[[ ]]`). Compose port lines were missed entirely
  ("mappings: 0"). Fixed by stripping `"`/`'` from each line with `tr` before matching.
  Lesson: on macOS, keep `[[ =~ ]]` regexes quote-free.
- **MISTAKE:** `while read … done <<< "$out"` with an EMPTY `$out` still executes one
  iteration (the herestring always supplies one empty line), emitting a bogus "env
  value" INFO per file. Fixed by guarding with `[ -n "$out" ]`.
- **MISTAKE:** classified `0.0.0.0:8443` (Kong's in-container SSL listener) as a
  host-bound Juega violation — wrong; 8443 inside the container is fine (host side is
  54443:8443). Removed `0.0.0.0` from the local-host set.

## Commands Run

```bash
export LOCK_ROOT=$PWD/repo-locks
tools/agent_lock.sh acquire AGENTS.md --owner D-01
tools/agent_lock.sh acquire tools/check_ports.sh --owner D-01
tools/agent_lock.sh acquire docs/history/phase-00-foundation/2026-08-09_D01-agent-orchestration-infra.md --owner D-01
chmod +x tools/check_ports.sh
bash -n tools/check_ports.sh
bash tools/check_ports.sh --report     # exit 0; 30 mappings, 149 refs, 34 violations (expected)
bash tools/check_ports.sh --strict     # exit 1; STRICT FAIL: 34 violation(s)
tools/agent_lock.sh release <path> --owner D-01
```

## Verification

- `bash -n` clean; `--report` exits 0, `--strict` exits 1 — verified on this machine
  (bash 3.2.57, darwin).
- All 34 violations cross-checked against a manual `rg` port inventory of the repo
  (1:1 match). Approved-port references (`54386` in opt-001/run_all_backend/
  client_test.go/test README, `54381/54384` in run.sh, AGENTS.md table rows) all
  reported OK.
- No code changes to `lib/`, `test/`, `cmd/`, `internal/`, `supabase/` — no flutter/go
  test runs needed.

## Issues found for I-02 (do NOT fix here — out of scope)

1. `supabase/docker-compose.yml` + `supabase-testing/docker-compose.yml`: db `5432:5432`,
   kong `54321:8000` (Juega collisions); auth `9999`, rest `3000`, realtime `4000`,
   storage `5000`, meta `8080` published to host (bypass Kong — remove or keep
   internal-only); `supabase-testing/docker-compose.mailpit.yml` publishes `8025/1025`
   (mailpit's approved host port is 54384).
2. Both `config.toml`: `[db] port = 5432` → must become 54382. Also stale
   `site_url = "http://127.0.0.1:3000"` + `additional_redirect_urls` 3000 (API gateway
   is 54386).
3. Stale host-bound refs: compose env `SUPABASE_URL`/`SUPABASE_PUBLIC_URL`/
   `PGRST_DB_OPENAPI_SERVER_PROXY_URI` = `http://localhost:54321`; `supabase/.env` +
   `supabase-testing/.env` `SUPABASE_PUBLIC_URL=http://localhost:54321`;
   `run.sh` echo lines (54321/5432); `migrate.sh` DB_URL default (5432);
   `test_runner.sh:4` (5432).
4. `test/router/app_router_test.dart:111` uses `http://localhost:54321` for
   `Supabase.initialize` — should be 54386 (test-only, safe, but inconsistent).
5. **Not detectable by regex:** `reset.sh` calls `psql -h localhost` with no `-p` flag —
   implicitly connects to host port 5432; needs `-p 54382` after the remap.
6. `tools/check_ports.sh` is owned by D-01 (creator) — FILE-OWNERSHIP.md lists
   `tools/check_ports.sh` (singular, M-30); orchestrator may want to reconcile the path
   and owner (M-30 keeps `<private-ops-repo>/`).

## Lock evidence

- `AGENTS.md` — acquired/released by D-01 (edit: heading number 150→180)
- `tools/check_ports.sh` — created under D-01 lock (new file)
- `docs/history/phase-00-foundation/2026-08-09_D01-agent-orchestration-infra.md` —
  this log (new file)

## Next steps

- I-02: apply the remap per the violation list above; then `bash tools/check_ports.sh --strict` must exit 0.
- M-30: wire `check_ports.sh --strict` into CI/Makefile and write `<private-ops-repo>/` docs.
- V-04 (doc verifier): re-run both modes at the end of the campaign.
