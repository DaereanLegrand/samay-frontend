# 2026-08-11 — Self-hosted Supabase stack: full clean boot (official pattern)

## Context

The Samay self-hosted Supabase stack (`supabase/docker-compose.yml`) had been
bootstrapping incorrectly since the first start: every service that needed the
baked-in Supabase database (auth, storage, realtime, PostgREST) crashed on
startup. Goal: get all 12 containers healthy with a clean, reproducible boot.

## What was built / fixed

1. **Removed the `./volumes/db/init:/docker-entrypoint-initdb.d` mount.**
   The host dir was empty, so it *hid* the supabase/postgres image's baked-in
   bootstrap (`migrate.sh`, `init-scripts/`, `migrations/`). The official
   compose only mounts individual files *into* that dir, never a dir over it.

2. **`POSTGRES_USER: postgres` → `supabase_admin`.**
   The image's default user is `supabase_admin`; initdb created `postgres`
   instead, so every baked-in script that does `ALTER USER supabase_admin`
   failed and the whole bootstrap silently aborted.

3. **`POSTGRES_DB: supabase` → `postgres`.**
   `migrate.sh` runs all init scripts against `$POSTGRES_DB`, while every
   service connects to `/postgres`. Schemas (auth, extensions, _realtime,
   graphql_public) were being created in the wrong database.

4. **Official init files added** (fetched from supabase repo
   `self-hosted/v0.8.0/docker/volumes/db/`):
   - `roles.sql` → `/docker-entrypoint-initdb.d/init-scripts/99-roles.sql`
     (sets `authenticator`, `supabase_auth_admin`, `supabase_storage_admin`,
     etc. passwords to `$POSTGRES_PASSWORD`)
   - `jwt.sql` → `init-scripts/99-jwt.sql` (`app.settings.jwt_secret/exp`)
   - `realtime.sql` → `migrations/99-realtime.sql` (`_realtime` schema + owner)
   - `webhooks.sql` → `init-scripts/98-webhooks.sql` (pg_net webhooks)
   - Added `JWT_SECRET` / `JWT_EXP` env on the db service.

5. **Service DB credentials switched to the official roles** (all password =
   `postgres`, matching `POSTGRES_PASSWORD`):
   - auth: `postgres://supabase_auth_admin:postgres@samay-db:5432/postgres`
   - rest: `postgres://authenticator:postgres@...` (already had
     `PGRST_DB_ANON_ROLE: anon`)
   - storage: `postgres://supabase_storage_admin:postgres@...`
   - realtime: `DB_USER: supabase_admin`

6. **realtime `DB_ENC_KEY`** must be exactly 16 chars → `supabaserealtime`
   (was 44 chars → `Bad key size` crash loop).

7. **storage healthcheck** `localhost:5000` → `storage:5000` (container-DNS
   name resolves to IPv4; `localhost` hit the IPv6 side, `Connection refused`).

8. **Auth:** `GOTRUE_MAILER_AUTOCONFIRM: true` so local signups complete
   without a real SMTP.

9. **API keys:** the repo mixed legacy JWTs and the new opaque
   `sb_publishable_...` keys. PostgREST only validates legacy JWTs, so Kong's
   key-auth keys (`.env` → `SUPABASE_ANON_KEY` / `SUPABASE_SERVICE_ROLE_KEY`)
   are now real HS256 JWTs signed with `JWT_SECRET` (roles `anon` /
   `service_role`, 1-year expiry). storage/studio read them from `.env` too.
   `.env` stays gitignored — no key material committed.

## Verification

- `docker compose up -d --wait` → **all 12 containers healthy**
  (db, auth, rest, realtime, storage, imgproxy, meta, studio, functions, kong,
  minio, minio-createbucket).
- Bootstrap log: `migrate.sh` runs 00-schema → initial-schema → auth-schema →
  storage-schema → post-setup → 98-webhooks → 99-jwt → 99-roles → all
  migrations (00-extension … 20250402…), zero errors.
- Schemas present: `auth`, `storage`, `extensions`, `_realtime`,
  `graphql_public` (+ `supabase_realtime` publication).
- Smoke tests through Kong (:54386):
  - `POST /auth/v1/signup` → `access_token` (autoconfirm).
  - `GET /rest/v1/` with anon JWT → 200 swagger.
  - `POST /storage/v1/bucket` with service JWT → `{"name":"smoke"}`.
  - realtime healthy (tenant `realtime-dev` seeded in `_realtime.tenants`;
    Kong route is websocket-only, so HTTP 404 through Kong is expected).

## Decisions

- Keep Kong (not the new Envoy gateway) — works, repo already configured.
- Keep inline compose values + `.env` overrides; no `.env.example` churn.
- Storage stays on `STORAGE_BACKEND: file` (official default now) with minio
  still running; revisit if macOS bind-mount xattr issues appear.

## MISTAKE blocks (for future devs)

> **MISTAKE (root cause chain):** three separate compose deviations each broke
> the bootstrap: (1) mounting a host dir over `/docker-entrypoint-initdb.d`;
> (2) overriding `POSTGRES_USER` to `postgres`; (3) `POSTGRES_DB: supabase`
> while services connect to `/postgres`. The image's `migrate.sh` aborts
> silently on the first failing psql (`set -eu` + `ON_ERROR_STOP`) and the
> entrypoint proceeds → "healthy" DB with no auth/storage schemas. Symptom:
> gotrue `schema auth does not exist`, storage "role anon does not exist".

> **MISTAKE:** earlier "fix" session ran the image's init scripts manually via
> psql on top of a half-bootstrapped DB → permanent `already exists` conflicts.
> Lesson: never hand-apply the image bootstrap; wipe `volumes/db/data` and let
> `migrate.sh` run once.

## Commands run

```bash
docker compose up -d --wait
docker compose ps
docker compose logs db | grep -E "running /docker-entrypoint-initdb.d|ERROR"
docker exec samay-db psql -U postgres -c "\dn+"
docker compose logs auth/storage/realtime/rest
curl -s -X POST http://127.0.0.1:54386/auth/v1/signup -H "apikey: $ANON" \
  -H "Content-Type: application/json" -d '{"email":"smoke@test.dev","password":"testpass123"}'
curl -s http://127.0.0.1:54386/rest/v1/ -H "apikey: $ANON"
curl -s -X POST http://127.0.0.1:54386/storage/v1/bucket -H "apikey: $SVC" \
  -H "Authorization: Bearer $SVC" -H "Content-Type: application/json" \
  -d '{"id":"smoke","name":"smoke","public":true}'
```
