# 2026-08-11 — Orchestrator prep: DB volumes → /Volumes/Media, .env bootstrap fix, and the CRITICAL function-EXECUTE hardening (fix-agent + verifier loop)

**Agent:** orchestrator (prep for 4.5) · **Phase:** Step 0 of the campaign plan
**Branch:** `fixes` (no commits made yet — batch commit at the end)

---

## 1. What was built

### 1.1 PostgreSQL data moved OFF the boot disk → named volumes (all 3 stacks)

The user asked whether storage actually lives on `/Volumes/Media/Docker` (the
symlinked Docker.raw). Investigation proved: MinIO object data + all named
volumes already live there, but **PostgreSQL data was a bind mount on the boot
disk** in every stack (Samay, supabase-testing, Juega). No important data
existed in any DB (user-confirmed), so the swap is discard-and-recreate:

- `supabase/docker-compose.yml` + `supabase-testing/docker-compose.yml`:
  `./volumes/db/data` bind → `db-data` named volume (`samay_db-data` /
  `samay-testing_db-data` — resolved via `COMPOSE_PROJECT_NAME`, verified in
  both `.env` files).
- `Makefile`: `supabase-reset`, `supabase-docker-reset`,
  `supabase-testing-reset` now `docker volume rm <project>_db-data
  <project>_minio-data` instead of `rm -rf volumes/db/data`.
- `reset.sh` (both stacks): volume removal driven by `COMPOSE_PROJECT_NAME`
  from `.env` (files byte-identical modulo the documented `Samay Testing`
  tokens — M-10 parity contract preserved).
- Juega (user-authorized read-only exception): same conversion
  (`supabase_db-data`), plus `supabase/reset.sh` + root `Makefile` updated;
  Juega restored via its own `migrate.sh` (16 public tables back).
- `.gitignore`: `supabase/volumes/db/postgresql.conf` +
  `supabase-testing/volumes/db/postgresql.conf` (generated at container boot).

### 1.2 `.env` sourcing bug (latent, broke every bootstrap)

`AUTH_MAILER_SUBJECTS_*` etc. held unquoted values with spaces (`Confirma tu
correo — Samay`) → `source .env` in `migrate.sh` ran `tu` as a command and
aborted (exit 127) — migrate.sh could NEVER have run on this tree. Fixed:
- `.env` / `.env-testing`: string values quoted (docker-compose dotenv-safe
  AND shell-safe); port lines deliberately left unquoted (shell comments).
- `migrate.sh` (both stacks): `source .env` replaced with a safe KEY=VAL
  loader (committable fix for every future clone).

### 1.3 opt-test + parity drift from f181d81

- opt-001..004/006 key defaults were stale (`sb_*` placeholders) vs the real
  dev HS256 JWTs in `.env` (f181d81 regenerated them) → defaults synced
  (documented dev-only pattern, M-03 alignment).
- `supabase-testing/.env` lacked the ANON/SERVICE_ROLE keys + the testing
  compose lacked the db init-script mounts → keys synced, the 4 init SQL
  files copied to `supabase-testing/volumes/db/` + mounted, `postgresql.conf`
  mount added (was declared in env `POSTGRES_CONFIG_FILE` but never mounted).
- opt-007 allowlist: `postgresql.conf` added (runtime artifact).

### 1.4 CRITICAL: anon EXECUTE on all 17 SECURITY DEFINER functions

**Root cause:** the supabase postgres image's initdb installs
`ALTER DEFAULT PRIVILEGES` granting `anon=X` EXECUTE on every function
created by `postgres`/`supabase_admin` in `public`. Every prior per-function
`REVOKE ALL ON FUNCTION ... FROM PUBLIC` only removed the *PUBLIC* entry —
the default-ACL anon grants survived. Verified live: `anon_exec = t` on all
17, including `grant_shards`/`grant_preshards` (shard minting),
`hard_delete_expired_users` (PII-deletion cron), `fetch_prekey_bundle`
(E2EE identity keys + OPK exfiltration), `donate_shards_to_group`
(shard draining, plus a NULL-unsafe guard: `auth.uid() != p_user_id`
evaluates NULL for anon sessions and silently passes).

**Fix** (`supabase/migrations/20260811000001_harden_function_execute_rls.sql`,
mirrored to `supabase-testing/migrations/`):
1. Default privileges: anon REVOKEd from function defaults for
   `postgres` and `supabase_admin` in `public` (the supabase_admin half
   needs a superuser connection — migrate.sh runs as non-superuser
   `postgres`, so it's wrapped in a DO block that skips gracefully with a
   NOTICE; run as `supabase_admin` for full hardening).
2. Per-function hardening: admin RPCs (5) → service_role only; client auth
   RPCs (4: donate, fetch_prekey_bundle, validate_qr_token,
   create_minigame_session) → authenticated only (service_role revoked too —
   a service_role caller has auth.uid()=NULL and would bypass the same
   guards); 6 trigger functions → no client role (RETURNS trigger —
   not directly callable, hygiene); `check_signup_email` + `is_group_member`
   keep anon (pre-auth check / RLS helper, both intended).
3. NULL-safe guard in `donate_shards_to_group`:
   `IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN RAISE ...`
   (+ `SET search_path = ''`, the I-31 pattern).
4. **New finding, same family:** the image's TABLE-level defaults
   (`arwdDxtm` to anon/authenticated) defeat the G-03 column REVOKEs —
   `has_column_privilege('authenticated', ..., 'UPDATE')` resolves true via
   the table grant. The users trigger was the only enforcement; groups/events
   had NONE (a promotor could SET `group_shards`/`featured`). Added
   `assert_safe_group_update` / `assert_safe_event_update` (SECURITY INVOKER,
   mirror the users pattern incl. INSERT normalization).
5. **New finding:** `groups_read_member` + `groups_update_promotor` were
   DEAD since 20260510000001 — `EXISTS (SELECT 1 FROM group_members WHERE
   group_id = id ...)` — the unqualified `id` resolves to the inner
   `group_members.id` → never matched → members couldn't read their groups
   and promotors couldn't update them (verified live: promotor PATCH matched
   0 rows). Recreated with explicit `groups.id` correlation.

### 1.5 pgTAP suite — first-ever green run (321/321)

The suite could never run: it used pgTAP APIs removed in 1.3.3
(`has_function_priv`, `hasnt_column_priv`, `hasnt_table_priv`,
`hasnt_function_priv`) plus version-behavior differences. Converted to the
1.3.3 equivalents / PostgreSQL builtins (kept the exact assertion
intent — the effective-privilege "not UPDATE-able" claims were corrected to
attacl facts + trigger existence, since table grants make the privilege
claims false): plan 312 → 321; new Section 48 (execute hardening) + 39g
(guard triggers). Both stack files byte-identical (M-10 contract).
`supabase db test` (CLI) still can't run here — Docker Hub pulls are stalled
(`docker pull hello-world` hangs); pgtap was `CREATE EXTENSION`d directly and
the suite runs via psql (`-v ON_ERROR_STOP=1`), the documented fallback.

### 1.6 opt-tests green

- opt-001: 40/40 — TEST H (anon donate denied — the execute hardening) +
  new TEST I (server-managed column guards: users mass-assignment rejected,
  legit bio update OK, groups.group_shards fraud rejected — with the
  promotor membership the probe needs).
- opt-006: 16/16 — the jsonb `::text` rendering greps (spaces after colons)
  fixed WITHOUT corrupting the request bodies (see MISTAKE-2), plus the
  anon-denial now enforced.
- Full `bash test/run_all_backend.sh`: 8/8 PASS.

### 1.7 Guard tests

`test/features/minigames/minigame_rpc_migration_test.dart` +
`test/features/qr/qr_rpc_migration_test.dart` (I-77/I-78 plan-consistency
parser) extended with the pgTAP 1.3.3 assertion-function prefixes
(`function_privs_are`, `table_privs_are`, `column_privs_are`,
`any_column_privs_are`, `any_sequence_privs_are`, `throws_ok`).

## 2. Validation (fix-agent) + verification (verifier agent)

| Gate | Result |
|---|---|
| pgTAP (`psql -v ON_ERROR_STOP=1`) | **321/321, 0 failures** |
| `bash test/run_all_backend.sh` | **8/8** (001: 40/40 · 006: 16/16 · 005/007/008 static) |
| `bash supabase/migrate.sh` (as postgres, full re-run) | EXIT 0, idempotent |
| `go test ./...` | ok (all packages) |
| `dart analyze` / `flutter analyze` | **0 issues** |
| `flutter test` | **2032/2032** |
| `make check` (secrets + analyzers + vet + ports) | PASS, ports STRICT (19/205/0) |
| ACL re-audit (verifier) | 15/17 anon-denied; 2 intended anon (check_signup_email, is_group_member); defaults anon-free in public for both roles |
| NULL-uid guard | throws_ok in Section 48 + live anon denial (opt-001 H1) |
| groups RLS correlation | live promotor UPDATE now matches (opt-001 I3) |
| integration_test/runner.sh | **HOST FLAKE, not a regression:** this machine has no usable iOS
  destination today — the only simulator is shut down (booted one: Xcode
  reports "Unable to find a destination matching ... {id}"), the physical
  iPhone needs signing, and the directory-run launch flake is already
  documented (U-29). The suite is hermetic (fake Supabase) and untouched by
  this batch's SQL/test changes. 18/18 evidence stands from the U-29 run. |

**Residuals reported for S-03 (not gate blockers):**
- pgTAP extension lives in `public` (its ~1000 helper functions are
  anon-executable via PostgREST — inert/test-only, but should move to its own
  schema or be dropped after tests).
- Image TABLE-level default grants (`arwdDxtm` to anon/authenticated) remain
  — the triggers + RLS are the enforcement today; column-grant model cleanup
  (revoke table UPDATE + grant editable columns per table) is the S-03 deep
  item with app-regression risk.
- Image-managed schemas (storage, supabase_functions, graphql) still carry
  anon function-execute defaults — out of scope, image-owned.

## 3. MISTAKE blocks

**MISTAKE-1 (sed corrupting request bodies):** the jsonb-space fix used
`sed` with escaped quotes; it matched INSIDE the curl `-d` bodies of
opt-006, inserting ` * ` into the JSON (`"identity_key": *"$IK"`) → the
bundle publish returned PGRST102 and 8 tests failed cascade. Detected only
by running the suite. **Lesson:** when fixing grep patterns in shell tests,
anchor to the `grep -q` context or use `python` replacements on the exact
line; always re-run the file after a sed pass.

**MISTAKE-2 (over-quoting .env):** the .env quoting pass quoted the PORT
lines (`POSTGRES_PORT="54382    # comment"`) — broke opt-007 (grep) AND
would have broken compose port parsing on the next `up`. Restored the port
lines to unquoted form (shell-safe via the trailing comment).

**MISTAKE-3 (zsh special vars):** `$GID`/`$UUID`-style probe variables in
zsh one-liners hit zsh's readonly special parameters ("bad math expression").
Use `python` for ad-hoc API probes in this repo's shell.

**MISTAKE-4 (pgTAP API swap, two passes):** the `has_function_priv` → 
`function_privs_are` conversion dropped the ROLE argument (the 6-arg form is
`schema, fn, args, role, privs[], desc`) — one failed run, fixed by
reconstructing the role per function. Re-verify the full signature before
bulk-editing test files.

**MISTAKE-5 (idempotency):** the hardening migration's `CREATE TRIGGER`
failed on re-apply ("already exists") — `DROP TRIGGER IF EXISTS` added.
Migrations must be re-runnable (migrate.sh re-applies every file).

## 4. Commands run (reproducibility)

```bash
# volume conversion
cd supabase && docker compose down && docker compose up -d --wait   # after compose edits
bash supabase/migrate.sh
# hardening (apply as superuser for the supabase_admin defaults)
PWP=$(grep -E '^POSTGRES_PASSWORD=' supabase/.env | head -1 | cut -d= -f2- | tr -d '"')
PGPASSWORD="$PWP" psql -h localhost -p 54382 -U supabase_admin -d postgres \
  -v ON_ERROR_STOP=1 -f supabase/migrations/20260811000001_harden_function_execute_rls.sql
# gates
PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres \
  -v ON_ERROR_STOP=1 -f supabase/tests/schema_test.sql
bash test/run_all_backend.sh
go test ./... && dart analyze && flutter test
make check
```
