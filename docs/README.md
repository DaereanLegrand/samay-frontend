# Samay — Documentation Hub

The repo's docs are organized around the **Diátaxis** model — four documentation
needs (how-to, reference, explanation, records) — so the layout stays legible and
grows predictably. New docs: put them where the table says, not in new top-level dirs.

## Where things live

| Area | Path | Contents | Put new docs here if… |
|---|---|---|---|
| **Hub** | `docs/README.md` | This index | — |
| **How-to (process)** | `docs/process/` | `DEVELOPMENT-WORKFLOW.md` (the standing protocol for agents/humans: TDD loop, locks, baselines, ports, commit policy), `FILE-OWNERSHIP.md` (path → owner map) | It tells people *how to do work* in this repo |
| **Reference (specs)** | `docs/specs/product/` | `samay_mvp_spec.md`, `samay_admin_cli_spec.md`, `samay_web_servers_spec.md` — read-only product/CLI/web-server specs | It specifies *what* a product/CLI/server is |
| **Reference (steps)** | `docs/specs/steps/` | `phase-00..15/` step specs + `cross-references.md` (dependency graph) — read-only implementation specs | It specifies *how a feature step behaves* |
| **Explanation** | `docs/design/` | `DISCO-DESIGN-SYSTEM.md`, `DISCO-LUXE-DESIGN-SYSTEM.md` | It explains the visual system |
| **Explanation** | `docs/security/` | `SECURITY.md`, `E2EE-ARCHITECTURE.md`, `MASVS-AUDIT.md`, `CVE-SCAN.md`, `FINAL-SECURITY-REPORT.md` | It explains the threat model / crypto / audit results |
| **Explanation** | `<private-ops-repo>/` | `SELFHOSTING.md`, `DEPLOYMENT-PLACEHOLDER.md` | It explains the stack / deployment |
| **Records (history)** | `docs/history/` | `phase-00..15/` daily developer logs + `*.DONE` markers, `PHASE-INVENTORY.md` | It records *what was built when* (dated log) |
| **Records (audits)** | `docs/audit/` | `2026-08-13_DOCS-vs-CODE-AUDIT.md`, `GATE-REPORT.md`, `GATE-REPORT-LUXE.md` | It's a one-shot verification/gate report |
| **Records (tracker)** | `docs/to-fix/` | `TODO.md`, 17 category files, `README.md`, `LESSONS_FROM_JUEGA.md` | It tracks an open finding/follow-up |

## Why this layout

Diátaxis (diataxis.fr) separates docs by *user need* instead of by authoring time:

- **process/** answers "how do I work here?" (how-to)
- **specs/** answers "what exactly does X do?" (reference — read-only)
- **design/ security/ infra/** answer "how does this system work?" (explanation)
- **history/ audit/ to-fix/** record what happened and what's left (records)

The old names mapped 1:1: `planification/` → `specs/product/`, `implementation/`
→ `specs/steps/`, `development/` → `history/`, `agents/` → `process/` (campaign
docs deleted post-180-agent orchestration), gate reports → `audit/`. `tool/` was
merged into `tools/` (single tools directory).

## Quick navigation

- **New to the repo:** root [`README.md`](../README.md) → `docs/process/DEVELOPMENT-WORKFLOW.md`
- **Building a feature:** find the phase step spec in `docs/specs/steps/phase-XX/`,
  check its status in `cross-references.md`, then follow the TDD loop in
  `docs/process/DEVELOPMENT-WORKFLOW.md`
- **Baseline numbers:** `docs/process/DEVELOPMENT-WORKFLOW.md` §3.6 (test/analyze
  counts) — keep them in sync with reality
- **What's done / what's left:** `docs/history/PHASE-INVENTORY.md` +
  `docs/specs/steps/cross-references.md` + `docs/to-fix/TODO.md`
