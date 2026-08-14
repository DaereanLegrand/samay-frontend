# Phase 01 — Admin CLI: C-07 CLI Entry Point Restoration

## Date: 2026-07-30

## What was built

Recreated the missing `cmd/samay-admin/` entry point (finding C-07 in `docs/to-fix/TODO.md`), verified against `docs/history/phase-01-admin-cli/2026-07-30_C07-CLI-entry-point-test-plan.md`.

| File | Purpose |
|------|---------|
| `cmd/samay-admin/main.go` | Bare entry point calling `Execute()`; exits 1 on error (cobra prints the error) |
| `cmd/samay-admin/root.go` | Root `samay` command, persistent `--json` flag, `initConfig()` (godotenv + viper bind), `validateEnv()` fail-fast, lazy client init via `PersistentPreRunE`, `Version` "1.2.0" |
| `cmd/samay-admin/users.go` | `list/get/ban/unban/grant-shards/grant-preshards/delete` |
| `cmd/samay-admin/events.go` | `list/get/feature/unfeature/reject-feature/cancel/distribute-shards` |
| `cmd/samay-admin/groups.go` | `list/get/members` |
| `cmd/samay-admin/reports.go` | `list/get/action` |
| `cmd/samay-admin/shards.go` | `recalculate-ranks/ledger/group-ledger/event-summary` |
| `cmd/samay-admin/config.go` | `list/get/set/reset` |
| `cmd/samay-admin/subs.go` | `list/get/override/revoke` |
| `cmd/samay-admin/system.go` | `stats/health` |
| `cmd/samay-admin/feature_requests.go` | `list` |
| `cmd/samay-admin/*_test.go` (9 files) | 40 new tests (82 total in module) |

Design notes:
- All commands are thin wrappers over `internal/ops`; no business logic added. Client created lazily via a package-level `createClient` var (overridable in tests with an httptest-backed `*db.DBClient`).
- `validateEnv()` runs in `PersistentPreRunE`, so `--help`/`--version` work without env, but any real command fails fast naming the missing variables. Cobra checks help/version before pre-run hooks, so validation never blocks them.
- Detail commands (`users get`, `events get`, `groups get`, `reports get`, `config get`, `subs get`, `shards event-summary`) use `format.RenderJSON` directly per the 2026-05-10 daily log MISTAKE #2 (nil tableBuilder crashes `format.Output`).
- Mutations require explicit safety flags: `users delete`/`config set`/`events distribute-shards` → `--confirm`; `events cancel`/`users ban`/`reports action`/`events feature`/`subs override` → required `--reason`/`--action`/`--expires`/`--tier`.
- Audit logging is NOT duplicated in the CLI — ops functions call `LogAction` internally.

## Decisions

- **`shards event-summary` wired to `ops.GetEvent` + JSON output.** `ops` has no `GetEventShardSummary` (only `GetShardLedger`, `GetGroupShardLedger`, `RecalculateRanks`), and the task forbade inventing new ops functions or tables. `GetEvent` returns pool size, distribution status, and promotores — the closest existing coverage. `confirmed_attendees` in `EventDetail` is never populated by ops (always 0). If a real per-event summary is needed, it belongs in `internal/ops` later.
- **`system health` returns an error (exit 1) when `db_connected` is false.** `ops.HealthCheck` never returns an error — it reports `degraded`. The test plan requires "clean error, exit non-zero (no panic)" for an unreachable URL, so the command prints the report table and then errors. This is output policy in the wrapper, not ops logic.
- **`--reason` defaults to `admin_grant`** for `grant-shards`/`grant-preshards` (per USRS spec: ledger reason = `admin_grant`).
- **Rank bracket enum** `b0_20|b20_40|b40_60|b60_80|b80_90|b90_100` matches the DB enum exactly (verified against `20260510000001_full_schema.sql`; the first implementation pass wrongly used `b80_100` — caught by the independent verification pass and fixed).
- **`createClient` var** (defaults to `db.NewDBClient()`) keeps commands testable without network; tests override it with httptest clients.
- `feature-requests` group has only `list` — `ApproveFeatureRequest`/`RejectFeatureRequest` exist in ops but the spec/step docs define no CLI commands for them (feature/unfeature handle the lifecycle).

## MISTAKE: pflag values persist across `Execute()` calls in tests

Cobra re-parses args per `Execute()`, but flags NOT mentioned in the args retain their previous values (`flag.Changed` too). Test A running `--tier gold` leaked into test B that ran the same command without `--tier`, failing the enum validation. Fixed with `resetAllFlags(rootCmd)` in `setupTestEnv` (and explicit resets in `main_test.go`).

## MISTAKE: `flag.Set()` marks flags as Changed

The first reset helper used `cmd.Flags().Set(name, defValue)`, which sets `Changed = true` — defeating `MarkFlagRequired` (cobra checks `Changed`, not the value). `users ban` without `--reason` proceeded to the network instead of rejecting. Fixed by calling `f.Value.Set(f.DefValue)` directly and resetting `f.Changed = false`.

## MISTAKE: nil error dereference in a test

`TestUsersDeleteWithConfirmProceeds` called `err.Error()` after already asserting `err == nil` — segfault in the test (not the CLI). Removed the dead check.

## MISTAKE: short user IDs panic in `ops.SoftDeleteUser`

`internal/ops/users.go` did `userID[:8]` — a short ID (e.g. `"xyz"`) panics before the HTTP call. First implementation pass used a realistic UUID in tests and left ops untouched (out of scope); the independent verification pass flagged it as a real crash vector (`users delete xyz` → panic). Fixed: `SoftDeleteUser` now rejects IDs shorter than 8 chars, and the CLI validates UUID format (`parseUUID`) on `users delete` so the operator gets a clean error instead of a panic.

## MISTAKE: `grant-shards`/`grant-preshards` ran without confirmation

Spec says "Prompts for confirmation before executing". The first pass had no confirmation at all. Fixed by requiring `--confirm` on both grant commands (flag-based instead of an interactive prompt, so the CLI stays scriptable; non-interactive default is the safer choice).

## MISTAKE: `users list` printed full UUIDs

Spec: "id (truncated)". Table output now truncates IDs to 8 chars.

## Commands Run

```bash
go mod tidy
go build ./...
go vet ./...
go test ./... -v                      # 82 tests, all pass
make build-cli                        # samay (10.4MB)
make build-linux                      # samay-linux (10.9MB, linux/amd64)
gofmt -w cmd/samay-admin/ internal/ops/users.go internal/ops/users_test.go
```

## Smoke Tests (test plan §3, run from temp dir with no .env)

```bash
./samay --help                                    # exit 0, all 9 groups listed
./samay users --help                              # list/get/ban/unban/grant-shards/grant-preshards/delete
./samay users list                                # exit 1: "missing required environment variable(s): SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, SUPABASE_ADMIN_USER_ID"
./samay users delete <uuid>                       # exit 1: "required flag(s) \"confirm\" not set"
./samay users delete not-a-uuid --confirm         # exit 1: "invalid id ...: must be a UUID"
./samay users grant-shards <uuid> 10              # exit 1: "required flag(s) \"confirm\" not set"
./samay groups list --bracket b80_100             # exit 1: "invalid value ... must be one of b0_20, b20_40, b40_60, b60_80, b80_90, b90_100"
./samay groups list --bracket b80_90              # validation passes (proceeds to network)
./samay system health                             # degraded table + "health check failed", exit 1, no panic
./samay config list --json (stub server)          # valid JSON on stdout, exit 0
```

## Verification

- `go build ./...` — zero errors
- `go vet ./...` — zero issues
- `go test ./...` — 82/82 pass (40 new in `cmd/samay-admin` + 1 in `internal/ops`)
- `go.mod` direct deps: `cobra v1.10.2`, `viper v1.21.0`, `godotenv v1.5.1`, `go-pretty v6.7.10`; `go.sum` generated and un-ignored in `.gitignore`
- C-08 verified: module builds under installed go1.26.5 (go.mod directive `go 1.26.2` no longer blocks compilation)
- Changes to `internal/ops`: `users.go` short-ID guard + `users_test.go` regression test (only)
- Independent verification pass (second agent) executed the full test plan: 39/39 checks PASS, 1 confirmed bug (rank_bracket enum, fixed), 2 WARNs (event-summary stopgap, recalculate-ranks unaudited — both pre-existing ops gaps, documented), hygiene items fixed (binaries gitignored, test count corrected)
- No changes to `lib/`, `supabase/`, `internal/db/`, `internal/format/`

## Deferred

- Live integration tests (test plan §4) — require running Supabase + service_role env
- `golangci-lint` gate — not installed; `go vet` used (same as 2026-05-10 log)
- `ops.GetEventShardSummary` (real `shards event-summary`) — ops follow-up, CLI wired to `GetEvent` stopgap
- Audit entry for `shards recalculate-ranks` — `RecalculateRanks` signature lacks `adminUserID`; pre-existing ops gap
