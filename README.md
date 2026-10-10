# Samay frontend

Flutter app (`samay`, `com.qallariy.samay`) — social events, shards, rankings,
QR check-in and E2EE chat.

## Make

- `make init` → `make start` (= `make dev`) — run against the backend chosen at init.
- `make build TARGET=ios-adhoc|simulator|android|all` · `make install`.
- `make analyze check secrets hooks env` · `make test`.
- Release (local-only, vault-gated): `make build PROD=true [ENV=prod|staging] TARGET=ios|android [MODE=adhoc]` · `make deploy TARGET=… ENV=… TRACK=…` · `make ios-beta|ios-release|android-alpha|android-release`.
- Full staging (backend + app builds, ephemeral Tart): `<private-ops-repo>/STAGING.md`.

## Docs

`docs/design/DESIGN.md` · `docs/security/E2EE-ARCHITECTURE.md` ·
`docs/process/DEVELOPMENT-WORKFLOW.md` · `.opencode/DEV-SERVER.md`.

## Architecture

![Architecture](docs/diagrams/architecture.svg)

## Deployment

![Deployment](docs/diagrams/deployment.svg)
