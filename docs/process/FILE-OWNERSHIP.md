# FILE OWNERSHIP MAP — Samay

How file ownership works in this repo, and which paths need coordination
before an edit. There is no lock tool in this repo; coordinate through the
human — see `docs/process/DEVELOPMENT-WORKFLOW.md` §2.

## Rules

1. **Default:** every path not listed below is free for any agent/human with a
   legitimate need.
2. **Always coordinate (⚙️) before editing** the paths in the table below: tell
   the human and check `git status` first, so you never edit over another
   session's in-flight work.
3. **Read-only for everyone (🔒)** except through an explicit human decision:
   `.git/**`.
4. Creating/renaming/deleting a file: announce it so concurrent work is not
   clobbered.

## Coordination-sensitive paths (⚙️)

| Path | Why it needs coordination |
|---|---|
| `AGENTS.md`, `docs/process/**` | Standing protocol — changes affect every session |
| `docs/README.md` | Docs hub — keep the map accurate |
| `README.md` | Baseline numbers — update in the same commit as count changes |
| `lib/core/router/app_router.dart`, `route_paths.dart`, `route_extras.dart` | Central routing; many features depend on it |
| `lib/core/providers/auth_provider.dart` | Auth state machine; auth flows across features depend on it |
| `lib/main.dart` | Bootstrap order (Supabase init, Hive, handlers) |
| `lib/core/design_tokens/**`, `lib/core/theme/**` | Token/theme layer |
| `lib/shared/widgets/**` | Shared component contracts |
| `lib/crypto/**` | E2EE primitives used by the multiplayer answer cipher (`lib/features/minigames/logic/minigame_cipher.dart`) |
| `pubspec.yaml` (+ generated lockfiles) | Dependency contract |
| `Makefile` | Gate definitions (`make check` / `make test`) |
| `tools/check_secrets.sh`, `tools/hooks/pre-commit` | Repo gates — loosening them requires explicit human sign-off |
| `test/opt-008-makefile-static.sh` | The only opt script in this repo — the Makefile static gate |

Migrations and pgTAP live in the backend repo (single stack), not here.

## Dead paths

Do not recreate: `docs/to-fix/`, `docs/audit/`, campaign-era docs,
`DISCO-*` design docs (replaced by `docs/design/DESIGN.md`).

Dart unit tests live in `test/*.dart` and are welcome — Q16 rescinded the old
2026-08-31 ban. `test/support/`, `test/meta/conventions_test.dart`,
`test_driver/` and `integration_test/` remain absent by convention.
