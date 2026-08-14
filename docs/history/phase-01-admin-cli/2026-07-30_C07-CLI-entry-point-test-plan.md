# Test Plan — C-07: `cmd/samay-admin` CLI Entry Point (+ C-08 verification)

## Date: 2026-07-30

## Scope

Verify the new `cmd/samay-admin/` cobra CLI wires the existing `internal/ops` layer
into a runnable binary per `docs/specs/product/samay_admin_cli_spec.md`, and that the
Go toolchain can build the module (C-08).

## Environment

- Go toolchain: go1.26.5 darwin/arm64 (via Homebrew)
- Module: `github.com/samay-app/samay`, `go 1.26.2` directive

## 1. Build & Static Checks

- [ ] `go mod tidy` succeeds and `go.sum` is generated; `go.mod` lists
      `cobra`, `viper`, `godotenv`, `go-pretty` as direct deps again
- [ ] `go build ./...` compiles with zero errors
- [ ] `go vet ./...` reports zero issues
- [ ] `make build-cli` produces a `samay` binary
- [ ] `make build-linux` cross-compiles for linux/amd64
- [ ] `golangci-lint run ./...` passes (if installed; otherwise `go vet` is the gate)

## 2. Unit Tests

- [ ] `go test ./...` — all existing internal tests still pass
- [ ] New `cmd/samay-admin` tests pass:
  - root help lists all 9 command groups (users, events, groups, reports,
    shards, config, subs, system, feature-requests)
  - `--json` persistent flag parses on a subcommand
  - missing `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` / `SUPABASE_ADMIN_USER_ID`
    → clear error, non-zero exit (no panic)
  - `users delete <id>` without `--confirm` → rejected
  - `users grant-shards <id> <amt>` with non-numeric amount → rejected
  - `events feature <id>` without `--expires` → rejected
  - arg-count validation (e.g. `users get` with no args → error)
  - table vs JSON output dispatch (`--json` emits valid JSON)

## 3. Binary Smoke Tests (no Supabase required)

- [ ] `./samay --help` exits 0 and shows all 9 groups
- [ ] `./samay users --help` shows `list/get/ban/unban/grant-shards/grant-preshards/delete`
- [ ] `./samay users list` with env unset → error message naming the missing variable
- [ ] `./samay users delete <uuid>` without `--confirm` → rejected with message
- [ ] `./samay system health` with env set to unreachable URL → clean error, exit non-zero (no panic)
- [ ] `./samay config list --json` (with env set) → valid JSON on stdout

## 4. Live Integration (optional — requires running Supabase + service_role env)

Only if a working `.env` with `SUPABASE_SERVICE_ROLE_KEY` is available:
- [ ] `./samay system health` → `db_connected: true`
- [ ] `./samay system stats` → renders stats table
- [ ] `./samay config list` → renders 37 keys
- [ ] `./samay users list` → renders users table or empty state

## 5. Regression

- [ ] No changes outside `cmd/`, `go.mod`, `go.sum`, `.gitignore`, `Makefile`, docs
- [ ] `dart analyze` / `flutter test` untouched and green (no Dart changes made)

## 6. Documentation

- [ ] `docs/to-fix/TODO.md`: C-07 and C-08 marked ✅
- [ ] Daily log written to `docs/history/phase-01-admin-cli/2026-07-30_C07-CLI-entry-point.md`
      covering what was built, decisions, mistakes, commands run
