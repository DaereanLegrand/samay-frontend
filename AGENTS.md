# Samay frontend — agent rules

The Flutter app **Samay** (`com.qallariy.samay`); split from `Vive`.

## Commands
- Setup: `make init` (gum; writes `.env`).
- Run: `make start` (= `make dev`) `[ENV=…]`. `ENV=local|testing|staging|prod` selects
  the backend for **every** verb (default `testing` reads `.env`; `staging`/`prod`
  are vault-gated, local-only). Build: `make build [ENV=…] TARGET=ios-adhoc|simulator|android|all`.
- Release: `make build ENV=prod|staging TARGET=ios|android [MODE=adhoc]` · `make deploy TARGET=… ENV=… TRACK=…`.
- `ENV=prod` dev/simulator/install requires `PROD_CONFIRM=1` (live backend).
- Gates: `make check`, `make test`.

## Rules
- Testing is backend-only; do not recreate Dart tests.
- Never kill/restart the user's `make dev`; ask them to press `r`/`R`
  (`.opencode/DEV-SERVER.md`).
- `.env` is local + gitignored; no secrets in the repo.

## Layout
`lib/features/*`, `lib/core/*`, `lib/crypto/*` (E2EE), `docs/`, `tools/`, `.opencode/`.
