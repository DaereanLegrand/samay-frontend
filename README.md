# Samay frontend

Flutter app (`samay`, `com.qallariy.samay`) — social events, shards, rankings,
QR check-in and E2EE chat.

## Make

- `make init ENV=testing` → `make start ENV=testing` (= `make dev`) — run against `ENV`.
- `ENV=testing-local|testing|staging|prod` drives **every** run/build/install verb; `staging`/`prod` are vault-gated and local-only. `ENV` is required (no default).
- `make build ENV=… TARGET=ios-adhoc|simulator|android|all` · `make install ENV=…`.
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

## License

Samay is released under the **GNU Affero General Public License, version 3**
(AGPL-3.0). The full text is in [`LICENSE`](LICENSE); third-party components and
disclosures are listed in [`NOTICE`](NOTICE). AGPL-3.0 requires that anyone who
runs a modified version of this software as a network service offers its
corresponding source to the users of that service.
