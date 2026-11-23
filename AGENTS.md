# Samay frontend — agent rules

The Flutter app **Samay** (`com.qallariy.samay`); split from `Vive`.

## Commands
- Setup: `make init ENV=testing` (gum; writes `.env`).
- Run: `make start ENV=…` (= `make dev`). `ENV=testing-local|testing|staging|prod` selects
  the backend for **every** verb (`testing-local` reads the Docker stack;
  `testing`/`staging`/`prod` need the vault, local-only). Build:
  `make build ENV=… TARGET=ios-adhoc|simulator|android|all`.
- Release: `make deploy TARGET=ios|android|all ENV=testing|staging|prod TRACK=<tracks>`
  — it fetches the vault profile into a RAM disk (one passphrase prompt), builds
  the signed IPA/AAB, uploads and wipes. `make build …` alone also fetches/wipes
  when not under `deploy`. The fetch tooling is NOT in this repo:
  `RELEASE_SECRETS` defaults to `../../Admin/infra/tools/release-secrets.sh`
  (override via env).
- `ENV=testing` is store-grade, same path as staging/prod: vault profile
  `testing-apple`/`testing-android`, backend `samay-api-testing.qallariy.lat`,
  Android flavor `dev` (AGP reserves `test*`).
- `ENV` is required on every run/build/install verb (no default).
- Gates: `make check`, `make test`.
- Ruby toolchain: `make ruby-toolchain` self-checks the Homebrew Ruby + bundler
  the release lanes need. `brew upgrade ruby` can leave a stale bundler gemspec
  with no gem directory, killing the `bundle` shim before any project code runs;
  the gate reinstalls the pinned version and rebuilds unbuilt native extensions.
  `build`/`deploy`/`publish`/`bundle-install`/`check` depend on it.

## Rules
- Tests live in `test/` (Dart); `make test` runs `flutter test` plus the static gates.
- Never kill/restart the user's `make dev`; ask them to press `r`/`R`
  (`.opencode/DEV-SERVER.md`).
- `.env` is local + gitignored; no secrets in the repo.

## Layout
`lib/features/*`, `lib/core/*`, `lib/crypto/*` (E2EE), `docs/`, `tools/`, `.opencode/`.
