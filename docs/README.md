# Samay — Documentation Hub

Docs describe the codebase **as it is right now**. Historical records live in
git history, not in the docs tree; `docs/history/` holds dated session logs.

## Where things live

| Area | Path | Contents |
|---|---|---|
| **Hub** | `docs/README.md` | This index |
| **Process (how-to)** | `docs/process/` | `DEVELOPMENT-WORKFLOW.md` (task cycle, locks, tests, ports, commit policy), `FILE-OWNERSHIP.md` (path ownership map) |
| **Step specs (pending work)** | `docs/specs/steps/` | Specs for steps NOT yet implemented + `cross-references.md` (dependency graph + statuses). Implemented steps have no spec — their behavior is documented by code and tests |
| **Design** | `docs/design/DESIGN.md` | The current minimal design language; token source of truth is code (`lib/core/design_tokens/`) |
| **Security** | `docs/security/` | `SECURITY.md` (precautions applied now + why + open items), `E2EE-ARCHITECTURE.md` (chat crypto spec) |
| **Infra** | `<private-ops-repo>/` | `SELFHOSTING.md` (stack runbook), `BACKEND-SERVER-VM.md` (<base-os> AArch64 backend VM: UTM + Docker Engine static + RustFS + launchd), `DEPLOYMENT-PLACEHOLDER.md` (deployment targets as placeholders), `DATABASE.md` (DB catalog: tables/RPCs/triggers/realtime/cron/storage), `BACKEND.md` (Go CLI command tree + API routes + internals) |
| **History** | `docs/history/phase-XX/` | Dated session logs (`YYYY-MM-DD_<slug>.md`, MISTAKE blocks) — already populated (`docs/history/phase-16/…`) |

## Quick navigation

- **New to the repo:** root [`README.md`](../README.md) →
  `docs/process/DEVELOPMENT-WORKFLOW.md`
- **Building a feature:** find the step spec in `docs/specs/steps/` (if the
  step has no spec, it's already built — read the code), check dependencies in
  `cross-references.md`, then follow the TDD cycle.
- **Baseline numbers:** root `README.md` §Testing summary.
- **What's done / what's left:** `cross-references.md` status columns +
  root README "Status & known gaps".
- **Security posture:** `docs/security/SECURITY.md` §6 open items.

## Rules

- New docs go into an existing area above — do not create new top-level dirs.
- When code changes behavior described here, change the doc in the same commit.
- No secrets in docs — ever.
