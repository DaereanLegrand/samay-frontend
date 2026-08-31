# FILE OWNERSHIP MAP — Samay

How file ownership works in this repo, and which paths need coordination
before an edit. Ownership is enforced by the **file semaphore**
(`tools/agent_lock.sh`) — see `docs/process/DEVELOPMENT-WORKFLOW.md` §2.

## Rules

1. **Default:** every path not listed below is free for any agent/human with a
   legitimate need — take its lock first.
2. **Always coordinate (⚙️) before editing** the paths in the table below:
   acquire all locks you need up front, edit, release. If someone else holds a
   lock, wait — never edit under a held lock, never delete another lock.
3. **Read-only for everyone (🔒)** except through an explicit human decision:
   `repo-locks/*`, `tools/agent_lock.sh` itself, `.git/**`.
4. Creating/renaming/deleting a file: lock the path too (both paths on rename).

## Coordination-sensitive paths (⚙️)

| Path | Why it needs coordination |
|---|---|
| `AGENTS.md`, `docs/process/**` | Standing protocol — changes affect every session |
| `docs/README.md` | Docs hub — keep the map accurate |
| `README.md` | Baseline numbers — update in the same commit as count changes |
| `docs/specs/steps/cross-references.md` | Dependency graph + statuses — single writer at a time |
| `lib/core/router/app_router.dart`, `route_paths.dart`, `route_extras.dart` | Central routing; many features depend on it |
| `lib/core/providers/auth_provider.dart` | Auth state machine; auth flows across features depend on it |
| `lib/main.dart` | Bootstrap order (Supabase init, Hive, handlers) |
| `lib/core/design_tokens/**`, `lib/core/theme/**` | Token/theme layer |
| `lib/shared/widgets/**` | Shared component contracts |
| `lib/core/services/chat_service.dart`, `lib/crypto/**` | E2EE chat stack — crypto changes must pair with opt-tests |
| `pubspec.yaml` (+ generated lockfiles) | Dependency contract — testing deps were removed (directive 2026-08-31) |
| `Makefile` | Gate definitions (`make check` / `make test`) |
| `tools/check_secrets.sh`, `tools/check_ports.sh`, `tools/hooks/pre-commit` | Repo gates — loosening them requires explicit human sign-off |
| `supabase/migrations/**` ↔ `supabase-testing/migrations/**` | Byte-identical mirror rule; move both or neither |
| `supabase/tests/schema_test.sql` ↔ `supabase-testing/tests/schema_test.sql` | pgTAP parity; keep `plan(N)` == assertion count |
| `test/opt-NNN-*.sh` + `test/run_all_backend.sh` | Backend curl test suite — register new opt-tests in the runner |

## Dead paths

Do not recreate: `docs/to-fix/`, `docs/audit/`, campaign-era docs,
`DISCO-*` design docs (replaced by `docs/design/DESIGN.md`). Also dead
(directive 2026-08-31): the Flutter/Dart test trees — `test/*.dart`,
`test/support/`, `test/meta/conventions_test.dart`, `test_driver/`,
`integration_test/` (flows + `runner.sh`). Testing is backend-only.
