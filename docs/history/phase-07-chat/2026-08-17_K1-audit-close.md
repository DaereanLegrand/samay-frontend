# K1 — audit close: deleted_messages RLS, bundle binding, 1:1 send serialization (2026-08-17)

Agent: `K1-audit-close` · Phase 07 (chat) · No commits (working tree only). Log written by K2-docs4.

## What was built

- **deleted_messages RLS hardening** — migration `20260817000005`.
- **Bundle ik_dh ↔ pairwise-session binding** — init bundles are bound to the pairwise
  session they were created for, so a bundle minted for one peer cannot be replayed against another.
- **1:1 send-serialization test** — test covering the 1:1 send path serialization.

## Decisions made and why

- Factual close-out of the audit items; details live in the code and migration headers.

## Commands run

See the K1 agent's own notes; this log records the audit-close scope only.
