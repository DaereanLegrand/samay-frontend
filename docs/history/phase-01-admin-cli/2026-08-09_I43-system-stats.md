# Phase 01 — Admin CLI: I-43 System Stats Full Spec + GO-08 HealthCheck Error

## Date: 2026-08-09

## What was built

Extended `GetSystemStats` to populate **every** field of the `system stats` spec
(`docs/specs/product/samay_admin_cli_spec.md` §samay-system + `SYST-system-cli-ops.md`)
with the **current schema's honest capabilities**, and fixed GO-08
(`HealthCheck` never returned an error).

### `internal/ops/system.go`

- `SystemStats` gained 4 new fields (all with JSON tags):
  `UsersLast30Days`, `EventsByStatus map[string]int`, `EventsByType map[string]int`,
  `TotalShardsDistributed`. Existing fields kept their names/tags (JSON compat).
- New paginated fetch helper `fetchAllRows[T]` (generics, page size 1000) — PostgREST
  caps rows per response (`db-max-rows`), so aggregates over large tables MUST page.
  Pages via `offset` until a short page is returned; deterministic `order=id` prevents
  skips/duplicates between pages.
- **Users: ONE paginated scan** (`created_at,updated_at,personal_shards,preshards`)
  feeds six metrics: registered count, last-7d, last-30d, active-7d, shards in
  circulation, preshards in circulation. (vs. 4-6 separate filtered queries — minimal
  N+1-free, single consistent snapshot.)
- **Events: ONE query on `(status,type)`**, grouped client-side in Go → total,
  `EventsByStatus`, `EventsByType`. (No N+1, per mission directive.)
- **Total shards ever distributed:** paginated `shard_ledger` scan with
  `delta=gt.0` filter, summed in Go (option (a) from the mission — PostgREST cannot
  SUM via REST without an RPC/view; documented as accurate enough for an MVP snapshot).
- **Reports / feature requests pending:** `id` scan with `status=eq.pending`, count.
- Query failures now return a wrapped error (previously all errors were swallowed and
  stats silently under-counted).
- **GO-08 fixed:** `HealthCheck` now returns a non-nil error on DB failure
  (health payload still returned with `Status: "degraded"` + `DBConnected: false`).
  `cmd/samay-admin` health command already handled the error return.

### `cmd/samay-admin/system.go` + `system_test.go`

- `statsTableBuilder` extended to **12 rows** (was 8): adds `users_last_30_days`,
  `events_by_status`, `events_by_type`, `total_shards_distributed`. Maps render
  deterministically via new `mapSummary` helper (`draft: 1, live: 2`; `"0"` when empty).
- Tests: `TestStatsTableBuilder_AllMetrics` (row count + every value),
  `TestStatsTableBuilder_EmptyMaps`, `TestSystemStatsJSONOutput` (end-to-end
  `system stats --json` through the stub client asserting the new JSON keys).
- Note: I-39 landed ctx-first signatures (`ops.GetSystemStats(ctx, client)`,
  `ops.HealthCheck(ctx, client)`) and I-40 landed `internal/db/{crud,query_builder}.go`
  while I was waiting for locks; ops code was adapted to both conventions
  (context threading + `db.List[T]` + `QueryBuilder`).

### `docs/to-fix/TODO.md`

- GO-08 workstream note added to the tracker header (I-42's I-42 note style).
  The category-file status flip in `12-GO-BACKEND.md` is D-03/I-42's file (not in
  my lock list) — left untouched for them.

### `internal/ops/system_test.go`

- `TestGetSystemStats_Metrics` — multi-endpoint httptest fixture server
  (`newStatsServer`) serving users/events/shard_ledger/reports/feature_requests with
  realistic PostgREST semantics (pagination limit/offset, `delta>0` filter,
  `status=pending` filter). Table-driven per-metric subtests + `EventsByStatus`/
  `EventsByType` map assertions + a query-shape subtest asserting the request URIs
  (select columns, `delta=gt.0`, `status=eq.pending`).
- `TestGetSystemStats_PaginatesLargeTables` — 1001 users → exactly 2 users requests,
  second page offset=1000, counts/sums correct.
- `TestGetSystemStats_ReturnsErrorOnQueryFailure` — 500 on any query → error.
- `TestHealthCheck_ReturnsErrorOnFailure` — replaces the old
  `TestHealthCheck_DegradedOnError` (which asserted the GO-08 buggy no-error behavior).

## Decisions

- **Active users proxy (spec gap, documented in code comment):** the `users` table has
  **no `last_login_at` column**, so "Active users (logged in last 7 days)" is not
  directly queryable. Used `updated_at >= now()-7d` as the proxy. Honest limitation:
  `updated_at` is touched on **profile edits**, NOT logins — the metric over-counts
  (users who only edited profiles) and misses users who log in without editing.
  **FLAG:** a `last_login_at timestamptz` column + auth-boundary write (GoTrue
  `custom_access_token_hook` or `auth.users.last_sign_in_at` mirror) is the correct
  fix — tracked for a future migration (S-03/EEDG scope).
- **Combined users scan** instead of per-metric filtered queries: 6 metrics from 1
  paginated query; server-side `created_at=gte.<ts>` filters were rejected because
  they'd need 4 full users queries for no accuracy gain.
- **SUM via fetch-all (option a) over an RPC (option b):** no new SQL object needed;
  a stats RPC/view would also require search_path hardening + RLS decisions owned by
  the data track. Documented in code that the sum is exact but unbounded in rows.
- **Fail loud:** stats queries now return errors instead of silently zero-filling.
  A partial stats table with silently missing shards/reports is worse than an error.
- `order=id` on every paginated scan keeps offset pagination stable (a uuid order is
  deterministic).

## MISTAKE: test handler filtered in-memory fixture maps, not the JSON

The fixture server's `keep` closure asserted `row["delta"].(float64) > 0` — but the
rows being filtered are the Go-side `statRow` fixtures (int values), not the decoded
request body. Panic: `interface conversion: interface {} is int, not float64`.
Fixed by asserting `.(int)`. The filter semantics are what PostgREST would apply.

## MISTAKE: offset assertion assumed offset=0 is sent

`client.Select` omits `offset` when 0 (client.go: `if offset > 0`), so the first page
request has no offset param. The pagination test initially expected `[0 1000]`; now
it counts users requests (must be 2) and asserts the second carries `offset=1000`.

## Commands Run

```bash
go test ./internal/ops/ -run 'TestGetSystemStats|TestHealthCheck' -v   # RED → GREEN
gofmt -w internal/ops/system.go internal/ops/system_test.go cmd/samay-admin/system.go cmd/samay-admin/system_test.go
go test ./... -count=1 # full suite, 5 packages green
go build ./... && go vet ./...
```

## Verification

- `go test ./... -count=1` green — all 5 Go packages
  (cmd/samay-admin, cmd/samay-api-server, internal/db, internal/format, internal/ops).
- `go build ./...`, `go vet ./...` clean.
- `gofmt` clean on all 4 modified Go files (ops + cmd).
  (Pre-existing gofmt diffs in `internal/ops/events.go`/`feature_requests.go`/`subs.go`
  are I-39/I-40 territory — not touched.)

## Coordination notes

- I-39 landed ctx-first ops signatures + 30s command timeout; I-40 landed
  `internal/db/crud.go` + `query_builder.go` mid-session. My ops code follows both
  conventions (context threading, `db.List[T]` + `QueryBuilder`) — no stringy
  `"id=eq."+x` regressions introduced.
- I-39 held `cmd/samay-admin/system.go` + `system_test.go` locks for ~90 min
  (claimed 19:50:27Z, released ~21:21Z after multiple 9-min acquire cycles, well past
  the 30-min rule). All other work was completed first while waiting.
- GO-08's category-file status flip (❌ → ✅ addressed by I-43) is D-03/I-42's
  tracking job since they own `12-GO-BACKEND.md`.
