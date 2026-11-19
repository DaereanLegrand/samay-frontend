# Samay — Documentation Hub

Docs describe the codebase **as it is right now**. Historical records live in
git history; `docs/history/` holds dated session logs.

## Where things live

| Area | Path | Contents |
|---|---|---|
| **Hub** | `docs/README.md` | This index |
| **Process (how-to)** | `docs/process/` | `DEVELOPMENT-WORKFLOW.md` (task cycle, locks, tests, ports, commit policy), `FILE-OWNERSHIP.md` (path ownership map) |
| **Design** | `docs/design/DESIGN.md`, `docs/design/AUTH-BUTTONS.md` | The current minimal design language (token source of truth is code, `lib/core/design_tokens/`); the social sign-in button rules (Apple HIG logo-only + Google branding) and how the login controls satisfy them |
| **Security** | `docs/security/` | `SECURITY.md` (precautions applied now + why + open items), `E2EE-ARCHITECTURE.md` (multiplayer answer crypto spec) |
| **Diagrams** | `docs/diagrams/` | `architecture.mmd` / `.svg` — the app's layers and its backend/services boundaries |
| **History** | `docs/history/phase-XX/` | Dated session logs (`YYYY-MM-DD_<slug>.md`, MISTAKE blocks) |

Deployment, credentials and release-signing operations are not documented in
this repository. Building a staging or production artifact requires release
material supplied by the operator (see the `Makefile` release targets).

## Quick navigation

- **New to the repo:** root [`README.md`](../README.md) →
  `docs/process/DEVELOPMENT-WORKFLOW.md`
- **Building a feature:** check the dependency notes in
  `docs/process/DEVELOPMENT-WORKFLOW.md`, then follow the TDD cycle.
- **Testing:** root `README.md` §Testing.
- **Security posture:** `docs/security/SECURITY.md` §6 open items.

## Rules

- New docs go into an existing area above — do not create new top-level dirs.
- When code changes behavior described here, change the doc in the same commit.
- No secrets in docs — ever.
