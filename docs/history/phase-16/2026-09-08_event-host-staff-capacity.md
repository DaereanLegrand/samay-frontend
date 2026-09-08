# 2026-09-08 — Events tab create flow, attendee capacity tiers, promotor→host/staff rename

## What was built

### Repo-wide rename: `promotor`/`co_promotor` → `host`/`staff`
Entire codebase (DB, Go, Flutter, opt-tests, pgTAP, docs):

- DB enums `event_role` + `group_role` values now `host`/`staff`
  (`group_role`: `member`/`host`/`staff`).
- `event_promotores` table → **`event_hosts`** (constraints, indexes, FKs,
  policies `ep_insert_host`/`events_update_host`, chat/photos/notifications/
  lifecycle references).
- Group leadership functions/policies: `transfer_host`,
  `reassign_group_host`, `group_members_{delete,insert,update}_host`,
  `groups_update_host`.
- SQL comments, RPC error literals (`not_host`), Go types/fields
  (`EventHost`, `Hosts`, `--host` CLI flag, `/api/v1/host/*` reserved
  namespace), Dart services/providers/screens/l10n keys
  (`getEventHosts`, `eventHostsProvider`, `eventRoleHost`, `eventRoleStaff`),
  opt-tests + `schema_test.sql` pgTAP assertions.
- Migrations edited **in place** (squashed pre-release tree) and mirrored
  byte-identical into `supabase-testing/`; DB is reset afterwards (no data).

### Stage 1 — Events-tab "Crear evento" + per-tier attendee capacity
- `users.entitlement_tier` (new enum `entitlement_tier`:
  `free`/`t2`/`t1`/`t0`), default `'free'`, protected alongside
  `subscription_tier` in `assert_safe_user_update` +
  `create_my_profile`. Billing webhooks NOT built (deferred) — only
  service_role / Go admins can raise it.
- `app_config`: `events.{free,t2,t1,t0}_max_attendees` = **7/14/56/1120**
  (seed-config + mirror).
- `events.capacity` (integer NOT NULL, CHECK 1..1120) — total people
  incl. host+staff+guests, frozen server-side. `assert_event_capacity`
  BEFORE trigger (tier lookup + UPDATE never below used seats) +
  `event_seats_used()` SECURITY DEFINER helper.
- `create_event(...)` SECURITY DEFINER RPC: atomic `events` +
  `event_hosts` host row + event `chats` insert. `EventService.createEvent`
  now calls the RPC (client no longer does the 3-table insert).
- Flutter: new `/events/create` route (plural — avoids `/event/:id`
  shadowing) opens `CreateEventScreen` standalone from the Events tab;
  capacity stepper bounded to the creator's entitlement tier; static
  "¿Quieres más? Contáctanos" upsell; list invalidation after create;
  `Event`/`UserProfile` models + freezed regeneration.

## Tests
- `test/opt-024-events-capacity.sh` (new, auto-discovered): free cap 7
  reject/accept, t2 cap 14 reject/accept, svc-default-capacity insert,
  `event_seats_used` = 1 (host seat). Requires the stack (Kong
  `127.0.0.1:54386`).
- Static gates run: `opt-005-seeds-static.sh` (45 ✅), `opt-008-makefile-static.sh`
  ✅; `opt-007-compose-static.sh` shows the pre-existing 5-key
  SERVICE_KEY-vs-`.env` drift on opt-001..006 (unchanged baseline, README-documented).
- `go test ./...` ✅, `dart analyze` 0 issues.
- pgTAP assertions updated in place (names only; `plan` unchanged).

## Commands run (reproducibility)
- `python3 /tmp/rename_promotor.py <files>` ordered token mapping
  (co_promotor→staff before promotor→host; plural `promotores`→`hosts`).
- `cp` edited migration/seed files to `supabase-testing/`; `diff -rq`
  confirms byte-identical mirrors.
- `flutter gen-l10n`, `dart run build_runner build`, `dart analyze`,
  `go test ./...`, `bash test/opt-005-seeds-static.sh`,
  `bash test/opt-008-makefile-static.sh`.

## Gotchas
- `agent_lock.sh acquire` takes one path per call — a zsh `for` loop over an
  unquoted string variable acquires a single space-joined lock (zsh does not
  word-split). Use zsh arrays.
- PostgREST RPC params must use the function's `p_*` argument names (the
  first opt-024 draft used `name`/`type` keys and would 4xx).
- `assert_event_capacity` reads the tier from `app_config` via a scalar
  subquery; guard `v_allowed IS NULL` → 7 so an unseeded key never yields a
  NOT NULL violation.

## Follow-ups (NOT in this session)
- Staff designation UI (host adds staff), event guest invites reusing the
  minigame invite mechanism, host/staff swirl attendance codes — later stages.
- Daily event-limit enforcement (`events.*_daily_limit`) still open (ECRT gap).
