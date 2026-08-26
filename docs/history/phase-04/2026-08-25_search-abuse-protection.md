# 2026-08-25 — Search abuse protection (OWASP API4): search_users RPC + Kong limiter + prefix index

## Report

User-search was a raw PostgREST `ilike` on `user_search_view`: no server-side
length validation, no rate limit, and every query sequential-scanned `users`
(plain-btree `idx_users_username` cannot serve ILIKE prefixes). Client-side
min-length gating (landed separately, `usernameMinLength = 5`) is bypassable
with curl. This session layered three industry-standard defenses
(OWASP API4:2023 + Kong rate-limiting plugin):

1. **`search_users(p_query text)` RPC** (`supabase/migrations/130_search/01_search_rpc.sql`)
   - SECURITY DEFINER, `search_path = ''`; validates trimmed length ∈ [5, 50]
     (SR002), enforces 60 searches/rolling-minute per user via an atomic
     counter upsert (SR001), rejects anon (SR003), escapes LIKE wildcards
     (`%`, `_`, `\`), excludes the caller, deterministic username order,
     LIMIT 20.
2. **Kong route limiter** — new `rest-v1-user-search` route on
   `/rest/v1/user_search_view`, `rate-limiting` plugin: `minute: 120`,
   `policy: local`, `limit_by: ip`. Coarse per-IP flood guard with standard
   `RateLimit-*` / `Retry-After` headers; verified live.
3. **`idx_users_username_prefix`** — `username text_pattern_ops` btree so
   allowed searches are index scans.

Client: `DiscoveryService.searchUsers` now calls `.rpc('search_users',
{'p_query': ...})`; friendship enrichment unchanged. `error_mapper` maps
`SR001` and HTTP-429-as-code to `RateLimitError` ("Demasiadas solicitudes.
Espera un momento.").

## Decisions

- **No revoke of `user_search_view` SELECT** (deviation from the agreed plan):
  planning-phase greps found five non-search consumers (UserService public
  profiles, group/event/shard member joins, chat sender resolution) — a
  blanket revoke breaks them all. The view stays open; the Kong limiter covers
  the raw path and the app uses only the validated RPC. Revisit if the view
  ever becomes search-only.
- **`limit_by: ip` at the gateway, not header/JWT**: every app user shares the
  anon apikey consumer, so consumer/credential buckets would aggregate the
  entire user base into one counter; Authorization-header buckets are
  attacker-rotatable. Per-user precision lives in the DB quota instead.
- **Custom SQLSTATEs** SR001/SR002/SR003 (5-char, unused class) so
  `PostgrestException.code` carries machine-readable meaning through PostgREST.
- **Quota seeded, not hammered**: opt-test seeds `search_rate_limits` to 60 via
  service_role upsert instead of sending 61 real requests (fast + hermetic).

## MISTAKE blocks

- MISTAKE (Kong crash-loop): added `rate-limiting` to kong.yml without checking
  `KONG_PLUGINS`. Supabase's image allow-lists plugins
  (`request-transformer,cors,key-auth,acl`) → declarative parse failed,
  samay-testing-kong restart-looped. Fix: append `,rate-limiting` in BOTH
  docker-compose.yml files. Lesson: validate declarative config against the
  container's actual enabled-plugin set BEFORE restarting a shared stack
  (`docker exec <kong> grep limit_by .../rate-limiting/schema.lua` also proved
  `limit_by` support in 3.9.3 without risk).
- MISTAKE (stale generated l10n): flow_test expected the min-chars hint but
  found nothing — the arb files had been edited to "5 caracteres" earlier
  without running `flutter gen-l10n`, so generated getters still said "2".
  Regenerating fixed it. Lesson: arb edits are not complete until gen-l10n runs.
- GOTCHA: `PostgrestException` has no `statusCode` field; for non-JSON-coded
  bodies (Kong's `{"message":"API rate limit exceeded"}`) `fromJson` falls back
  to the HTTP status string, so gateway 429s surface as `code == '429'`.

## Commands

    flutter test test/core/error_mapper_test.dart test/services/discovery_service_test.dart
    bash test/opt-015-search-rpc.sh                     # 7/7 PASS
    psql -p 54382 -f supabase/migrations/130_search/01_search_rpc.sql
    make test                                           # see handoff notes
    go test ./... && go vet ./...                       # ok
    bash tools/check_ports.sh --strict                  # STRICT PASS
    bash tools/check_secrets.sh                         # PASS
    flutter gen-l10n

## Handoff (blocked by concurrent session ox-alpha-fix1's locks)

- ~~pgTAP~~ **RESOLVED same day** (locks freed): SECTION 61 appended to
  `schema_test.sql` (+ byte-identical mirror) — 31 assertions, plan 586→617,
  suite green. Gotcha: `supabase db test` needs
  `PGTAP_DB_URL='postgres://...?sslmode=disable'` against the compose DB (CLI
  defaults to SSL); the Makefile variable override avoids editing the locked
  target. Also removed three ad-hoc `tester*` rows from the testing DB — the
  suite asserts zero USER data at start ("test data is explicit only").
- ~~Docs~~ **RESOLVED same day**: SECURITY.md §2.8 + O1 partial-resolution row,
  DATABASE.md `130_search` domain row, BACKEND.md Search RPC section,
  cross-references.md fixes-table row, README pgTAP baseline → plan(617).
- Remaining: commits (owner's call) — untracked `130_search/` fails
  `migrate-check` until committed; opt-007 env-alignment noise is
  pre-existing and documented by ox-alpha-fix1.
