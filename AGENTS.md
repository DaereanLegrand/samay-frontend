# Samay frontend — agent rules

The Flutter app **Samay** (`com.qallariy.samay`); split from `Vive`.

## Commands
- Setup: `make init` (gum; writes `.env`, picks local/tunnel/prod backend).
- Run: `make start` (= `make dev`). Build: `make build TARGET=ios-adhoc|simulator|android|all`.
- Release: `make build PROD=true [ENV=prod|staging] TARGET=ios|android [MODE=adhoc]` · `make deploy TARGET=… ENV=… TRACK=…`.
- Gates: `make check`, `make test`.
- Release (local-only, vault-gated): `make ios-beta|ios-release|android-alpha|android-release`.

## Rules
- Testing is backend-only; do not recreate Dart tests.
- Never kill/restart the user's `make dev`; ask them to press `r`/`R`
  (`.opencode/DEV-SERVER.md`).
- `.env` is local + gitignored; no secrets in the repo.

## Layout
`lib/features/*`, `lib/core/*`, `lib/crypto/*` (E2EE), `docs/`, `tools/`, `.opencode/`.
