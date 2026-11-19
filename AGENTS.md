# Samay frontend — agent rules

The Flutter app **Samay** (`com.qallariy.samay`); split from `Vive`.

## Commands
- Setup: `make init ENV=testing` (gum; writes `.env`).
- Run: `make start ENV=…` (= `make dev`). `ENV=testing-local|testing|staging|prod` selects
  the backend for **every** verb (`testing` reads `.env`; `staging`/`prod` need
  operator-supplied release material, local-only). Build: `make build ENV=… TARGET=ios-adhoc|simulator|android|all`.
- Release: `make build ENV=prod|staging TARGET=ios|android [MODE=adhoc]` · `make deploy TARGET=… ENV=… TRACK=…`.
- `ENV` is required on every run/build/install verb (no default).
- Gates: `make check`, `make test`.

## Rules
- Testing is backend-only; do not recreate Dart tests.
- Never kill/restart the user's `make dev`; ask them to press `r`/`R`
  (`.opencode/DEV-SERVER.md`).
- `.env` is local + gitignored; no secrets in the repo.

## Layout
`lib/features/*`, `lib/core/*`, `lib/crypto/*` (E2EE), `docs/`, `tools/`, `.opencode/`.
