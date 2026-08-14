# I-39 — Go Backend: error handling (GO-04/H-31) + context (GO-06/M-43) + GO-08/GO-09

## Date: 2026-08-09

## Role
Implementation agent I-39 — Go backend error handling + context propagation in
`internal/db/client.go`, `internal/ops/**`, `cmd/samay-admin/**` (findings
GO-04/H-31, GO-06/M-43, GO-08, GO-09 in `docs/to-fix/categories/12-GO-BACKEND.md`).

## Coordination with parallel agents (lock timeline)
I-40 (CRUD/query-builder) and I-42 (tests) landed their passes while this agent
waited on the file semaphore; I-43 landed the stats/health rewrite. This agent
layered the error-handling + context work on top of their final tree state:

- I-40's pass already threaded `ctx` through `internal/db/crud.go` + most ops
  functions as part of GO-07/GO-12 (their M-44 note says "ops run on
  `context.Background()` pending I-39's ops ctx pass" — resolved here).
- I-43's pass already delivered GO-08 (`HealthCheck` returns error on DB
  failure) and ctx-threaded `GetSystemStats`/`HealthCheck`/`fetchAllRows`.

## What was built

### GO-06/M-43 — context.Context propagation
- `internal/db/client.go`: `request`, `Select`, `Insert`, `Update`, `Delete`,
  `RPC` take `ctx context.Context` as FIRST param (`http.NewRequestWithContext`
  + `context` import); `io.ReadAll(resp.Body)` error now checked (was `_`).
- `internal/ops/*`: every exported function that makes DB calls + helpers
  `LogAction` and `fetchAllRows` propagate `ctx` (no inline
  `context.Background()` remains in ops — verified by grep).
- `cmd/samay-admin/root.go`: `rootCtx()` — `signal.NotifyContext` (SIGINT/
  SIGTERM) wrapped in a 30s `context.WithTimeout` (`commandTimeout`); every
  network-touching `RunE` derives `ctx, cancel := rootCtx(); defer cancel()`.
- `cmd/samay-admin/system.go`: `system health` simplified to propagate the
  error from `ops.HealthCheck` (old `!report.DBConnected` duplicate check
  removed — it was output-policy dead weight).

### GO-04/H-31 — silent error swallowing eliminated
Pattern chosen (documented per function): **best-effort enrichment → partial
result + `errors.Join`**; **critical-path secondary data → hard error**.
- `users.go GetUser`: shard-ledger + group-memberships failures → `UserDetail`
  still returned + `errors.Join` naming each failing query. CLI `users get`
  renders partial JSON AND returns the error (exit 1) — usable + explicit.
- `events.go GetEvent`: same pattern for the promotores enrichment.
- `events.go CancelEvent`: promotores pool read is now a hard error (refunds
  cannot be computed otherwise); refund `Insert` failures are `errors.Join`-ed
  per user and surfaced after the status update (all promotores still get
  their refund attempt).
- `events.go DistributeShards`: RPC-result unmarshal is checked; on genuinely
  malformed JSON the RAW response body is recorded as audit details and the
  parse error is joined + returned (target type `interface{}` so valid
  object OR array responses both audit fine — kept I-41's api-server test
  suite green).
- `system.go`: I-43's fail-hard design kept; every query + unmarshal error is
  checked (no silent skips remain).
- All `details, _ := json.Marshal(...)` audit-details marshal errors are now
  checked (users/events/subs/feature_requests/config).
- **Bonus latent crash fixed (found during the sweep):** `config.go SetConfig`
  did `current, _ := GetConfig(...)` then dereferenced `current.Value` —
  nil-pointer PANIC when the key is missing or the DB read fails (noted by
  I-41 in their test comment as a "GO-04-class bug"). Now: read failure is
  reported to stderr and audit "before" falls back to "".

### GO-08 — HealthCheck returns error on DB failure
- Delivered by I-43 (error + degraded payload); this agent's contribution:
  ctx threading + `system health` caller simplification + cmd test
  `TestSystemHealthPropagatesDBError`.

### GO-09 — NewDBClient validates env
- `NewDBClient() (*DBClient, error)` — validation error when `SUPABASE_URL`
  or `SUPABASE_SERVICE_ROLE_KEY` is empty/whitespace (values `TrimSpace`d).
- `root.go createClient` (already `(client, error)`) now returns
  `db.NewDBClient()` directly; `initClient` propagates.

## Decisions
- `errors.Join` (Go 1.20+; module is on go 1.26) is the partial-data carrier:
  `(result, errors.Join(detailErrs...))` lets callers render primary data
  while every secondary failure stays explicit.
- CancelEvent refund failures are joined, not aborted: all promotores still
  get their refund attempt; the operator sees every failure in one error.
- `rootCtx()` = signal-aware + 30s deadline per command; `signal.NotifyContext`
  unregisters on cancel so tests leak nothing.
- Stats (`GetSystemStats`) keeps I-43's fail-hard semantics (error when any
  query fails) — stricter than my original best-effort+stderr plan, but
  "never silent" is satisfied either way; noted for the orchestrator.

## Files modified (all under `tools/agent_lock.sh acquire ... --owner I-39`)
- `internal/db/client.go` (lock 19:50:26Z) + `internal/db/client_test.go` (19:55:08Z)
- `internal/ops/users.go`, `events.go`, `groups.go`, `reports.go`, `shards.go`,
  `subs.go`, `config.go`, `feature_requests.go`, `audit.go` (acquired after
  I-40 released, ~20:27Z)
- `internal/ops/users_test.go` (~21:15Z), `config_test.go` (20:25Z)
- `cmd/samay-admin/root.go`, `root_test.go`, `users.go`, `events.go`,
  `groups.go`, `reports.go`, `shards.go`, `subs.go`, `config.go`,
  `system.go`, `feature_requests.go`, `system_test.go` (new) (19:50:27Z)
- `docs/to-fix/TODO.md` + `docs/to-fix/categories/12-GO-BACKEND.md`
  (~21:10Z): H-31/M-43 → ✅ (I-39); GO-04/GO-06/GO-08/GO-09 → ✅
- NEW `docs/history/phase-01-admin-cli/2026-08-09_I39-go-errors-ctx.md`

## Tests added/updated
- `internal/db/client_test.go`: `TestNewDBClient_ValidationError` (table-driven
  missing/whitespace env), `TestRequest_CancelledContext` (canceled ctx →
  `context.Canceled`, fast return), `TestRequest_ContextTimeout`
  (`context.DeadlineExceeded`), `TestRequest_ErrorResponseRead`.
- `internal/ops/users_test.go`: NEW `TestGetUser_SecondaryFailuresJoined`
  (ledger + members 500 → partial detail + joined error naming both).
- `internal/ops/config_test.go`: NEW `TestSetConfig_MissingKeyDoesNotPanic`
  (regression for the nil-deref fix); ctx threaded.
- `cmd/samay-admin/system_test.go` (new): `TestSystemHealthPropagatesDBError`,
  `TestSystemHealthOK`.
- `cmd/samay-admin/root_test.go`: `createClient` restore updated for the
  `NewDBClient()` 2-value signature.

## Commands run
```bash
go build ./...
go vet ./...
go test ./... -count=1
gofmt -l cmd/ internal/
```
Results: build clean · vet clean · gofmt clean · **179 tests green across
5 packages** (`cmd/samay-admin` 41, `cmd/samay-api-server` 17, `internal/db`
31, `internal/format` 4, `internal/ops` 86 — full-suite run).

## Issues found / reported
- **I-43 lock retention:** `internal/ops/system.go` + `system_test.go` were
  held by I-43 for 90+ minutes with no file changes in the last hour; their
  in-tree version is complete and green. This agent proceeded without editing
  those two files (nothing left to change except `CheckHTTP`'s missing ctx
  param — an HTTP helper, not a DB call; left for I-43). Locks may be stale.
- **Pre-existing (fixed):** `SetConfig` nil-pointer panic (see above).
- **Pre-existing (noted, out of scope):** `CheckHTTP(url)` has no ctx param;
  `ShardLedgerParams` struct unused; `ListSubsParams.ExpiringWithin` unused by
  ops (CLI flag dead weight) — worth a future cleanup pass.

## MISTAKE (documented for future devs)
- `config.go SetConfig` dereferenced `current.Value` after ignoring the
  `GetConfig` error → nil-pointer panic on `config set <missing-key>` or DB
  read failure. Fixed with stderr note + nil guard.
- First draft of `DistributeShards` used `map[string]interface{}` as the
  unmarshal target — valid JSON ARRAY responses (I-41's api-server test stub
  returns `[{"id":"x"}]`) errored and broke the api-server suite. Changed to
  `interface{}`: only genuinely malformed JSON hits the error path.
