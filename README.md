# Samay frontend

Flutter app (`samay`, `com.qallariy.samay`) — social events, shards, rankings,
QR check-in and E2EE chat.

## Make

- `make init` → `make start` (= `make dev`) — run against `ENV` (default `testing` reads `.env`).
- `ENV=local|testing|staging|prod` drives **every** run/build/install verb; `staging`/`prod` are vault-gated and local-only, and `ENV=prod` also needs `PROD_CONFIRM=1`.
- `make build [ENV=…] TARGET=ios-adhoc|simulator|android|all` · `make install`.
- `make analyze check secrets hooks env` · `make test`.
- Release (local-only, vault-gated): `make build ENV=prod|staging TARGET=ios|android [MODE=adhoc]` · `make deploy TARGET=… ENV=… TRACK=…` (uploads the vault-built artifact).
- Full staging (backend + app builds, ephemeral Tart): `<private-ops-repo>/STAGING.md`.

## Docs

`docs/design/DESIGN.md` · `docs/security/E2EE-ARCHITECTURE.md` ·
`docs/process/DEVELOPMENT-WORKFLOW.md` · `.opencode/DEV-SERVER.md`.

## Architecture

![Architecture](docs/diagrams/architecture.svg)

## Deployment

![Deployment](docs/diagrams/deployment.svg)
