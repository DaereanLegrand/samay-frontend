# Phase 01 — Admin CLI: Full Implementation

## Date: 2026-05-10

## What was built

### DBCL — Database Client & Models
- `internal/db/models.go` — 30 Go structs matching all DB tables, with `json` tags (snake_case), `time.Time` for timestamps, `*string` for nullable fields
- `internal/db/client.go` — PostgREST HTTP client with `service_role` auth:
  - `Select(table, filter, limit, offset)` — query with filters
  - `Insert(table, row)` — create row
  - `Update(table, filter, patch)` — update rows
  - `Delete(table, filter)` — delete rows
  - `RPC(function, params)` — call Edge Function / stored procedure
  - `buildFilter()` — helper for building URL query params

### FMTT — Output Formatters
- `internal/format/table.go` — three functions:
  - `RenderTable(headers, rows)` — terminal table via `go-pretty`
  - `RenderJSON(data)` — pretty-printed JSON
  - `Output(data, jsonFlag, tableBuilder)` — dispatches to table or JSON

### AUDT — Audit Logging
- `internal/ops/audit.go` — `LogAction()` inserts into `admin_audit_log` with admin ID, action, target, and details JSON

### ROOT — CLI Root Command
- `cmd/samay-admin/root.go` — cobra root with:
  - Persistent `--json` flag (global)
  - `initConfig()` loads `.env` via godotenv, binds env vars via viper
  - `validateEnv()` checks SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ADMIN_USER_ID
- `cmd/samay-admin/main.go` — calls `Execute()`

### Command Files (cobra wrappers)
| File | Commands |
|------|----------|
| `users.go` | `list`, `get`, `ban`, `unban`, `grant-shards`, `grant-preshards`, `delete` |
| `events.go` | `list`, `get`, `feature`, `unfeature`, `reject-feature`, `cancel`, `distribute-shards` |
| `groups.go` | `list`, `get`, `members` |
| `reports.go` | `list`, `get`, `action` (remove/dismiss/warn) |
| `shards.go` | `ledger`, `group-ledger`, `recalculate-ranks` |
| `config.go` | `list`, `get`, `set` (--confirm), `reset` |
| `subs.go` | `list`, `get`, `override`, `revoke` |
| `system.go` | `stats`, `health` |
| `feature_requests.go` | `list`, `approve`, `reject` |

### OPS — Business Logic Package
- `internal/ops/users.go` — ListUsers, GetUser, BanUser, UnbanUser, GrantShards, GrantPreshards, SoftDeleteUser
- `internal/ops/events.go` — ListEvents, GetEvent, FeatureEvent, UnfeatureEvent, RejectFeatureEvent, CancelEvent, DistributeShards
- `internal/ops/groups.go` — ListGroups, GetGroup, ListGroupMembers
- `internal/ops/reports.go` — ListReports, GetReport, ActionReport
- `internal/ops/shards.go` — GetShardLedger, GetGroupShardLedger, RecalculateRanks
- `internal/ops/config.go` — ListConfig, GetConfig, SetConfig, ResetConfig
- `internal/ops/subs.go` — ListSubs, GetSub, OverrideSub, RevokeOverride
- `internal/ops/system.go` — GetSystemStats, HealthCheck, CheckHTTP
- `internal/ops/feature_requests.go` — ListFeatureRequests, ApproveFeatureRequest, RejectFeatureRequest

### BLD1 — Build & Distribution
- `Makefile` — targets: build-cli, build-api, build-linux, test, lint, clean
- Binary built: `samay` (10.8MB ELF x86-64)
- Cross-compile: `make build-linux`

### Tests
- `internal/db/client_test.go` — TestNewDBClient, TestBuildFilter
- `internal/db/models_test.go` — TestUserStruct, TestEventStruct (JSON round-trip)
- `internal/ops/audit_test.go` — TestLogAction (param assembly)
- `cmd/samay-admin/main_test.go` — TestMainNoPanic

## Decisions
- **Ops functions take `*db.DBClient`** — testable via mock HTTP client later
- **Output formatter uses generic `interface{}`** — works for any return type; type assertions in cobra commands handle the specific type
- **All mutations log to `admin_audit_log`** — traceability requirement from spec
- **`get` commands output JSON directly** — detail views are too complex for tabular display
- **`set` and `delete` commands require `--confirm` flag** — safety measure against accidental mutations

## MISTAKE: Cobra commands referenced nonexistent ops types
The `format.Output` callbacks used type assertions like `data.([]ops.UserRow)` but `ListUsers` returns `[]db.User`. Fixed all 7 command files to use `db.*` types directly.

## MISTAKE: RLS policies used OLD/NEW references (carried from earlier step)
The `get` commands originally used `format.Output(data, jsonFlag, nil)` which would crash because `Output` calls `tableBuilder(data)` unconditionally. Fixed by using `format.RenderJSON(data)` directly for detail views.

## MISTAKE: Go dependencies not saved to go.mod
`go get` installed packages but they weren't persisted in `go.mod` until `go mod tidy` was run. Added `go mod tidy` to the workflow.

## Commands Run
```bash
go get github.com/spf13/cobra@latest github.com/spf13/viper@latest ...
go mod tidy
go build ./...
go test ./... -v
make build-cli
go vet ./...
```

## Verification
- `go build ./...` — compiles cleanly (0 errors)
- `go test ./... -v` — all tests pass (5/5)
- `go vet ./...` — no issues
- `make build-cli` — produces 10.8MB binary
- Binary runs: `./samay --help` (requires env vars for full operation)

## Deferred
- Integration tests against live Supabase (needs full `.env`)
- Edge Function RPC calls (grant_shards, grant_preshards, distribute_shards, recalculate_ranks) — Edge Functions not deployed yet
- `golangci-lint` — not installed on this machine, `go vet` used instead

## Next Steps
**Phase 02 — Flutter Foundation**: FLUT (project scaffolding), DSNG (design system), STAT (Riverpod), ROUT (GoRouter), SBAS (Supabase client), STOR (local storage)
