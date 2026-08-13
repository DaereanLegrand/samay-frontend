# Samay

**Samay** is a disco/social-life mobile app for the 18–35 Latin American urban
demographic: plan social gatherings, invite friends, attend events (QR-verified),
earn and spend **shards**, climb group rank leaderboards, and relive the night
through photos and mini-games.

This repository is a **3-track project**:

| Track | What | Status |
|-------|------|--------|
| **Flutter app** (`lib/`, `test/`) | iOS + Android app — auth, profile, friends, groups, shard donations, rankings. Events (Phase 05+) and beyond are specced, with routes stubbed as "Próximamente" screens | Phases 02–04 done; 05+ foundations planned |
| **Go admin CLI** (`cmd/samay-admin/`, `internal/`) | Cobra-based operational CLI (`samay`) using the `service_role` key — users, events, groups, reports, shards, config, subs, system | Complete |
| **Self-hosted Supabase** (`supabase/`, `supabase-testing/`) | PostgreSQL 17 + GoTrue + PostgREST + Realtime + Storage + Kong gateway; Docker Compose and `config.toml` dual setups; migration-based testing | Foundation done; port remap in progress (I-02) |

Full product spec: [`docs/planification/samay_mvp_spec.md`](docs/planification/samay_mvp_spec.md).
CLI spec: [`docs/planification/samay_admin_cli_spec.md`](docs/planification/samay_admin_cli_spec.md).

---

## Quickstart (10 minutes)

Prerequisites: Flutter (`/opt/homebrew/share/flutter/bin/flutter` on this machine),
Go ≥ 1.26, Docker + `docker compose`.

```bash
# 1. Dart dependencies
flutter pub get

# 2. Environment
cp .env.example .env
# Fill in SUPABASE_URL / SUPABASE_ANON_KEY (local or remote; see "Environment" below)

# 3. Run the app (picks a device; or: make dev TARGET=android)
flutter run

# 4. Tests
make flutter-test        # Flutter unit/widget tests
make flutter-analyze     # dart analyze
make test                # flutter-test + go test ./... -v
make build-cli           # builds ./samay admin CLI binary

# 5. Backend stack (self-hosted Supabase, approved ports — see below)
make supabase-docker-start
bash test/run_all_backend.sh   # curl-based backend integration tests (needs the stack)
```

### Environment: `.env` vs `--dart-define`

The app currently reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` from a `.env`
file at startup via `flutter_dotenv` (`lib/main.dart` → `lib/core/config/env_config.dart`),
and `.env` is declared as a Flutter asset in `pubspec.yaml`.

- **Now:** copy `.env.example` → `.env`, set the two Supabase vars, run.
- **Planned:** the `.env`-as-asset approach ships keys in the bundle and is on
  the removal list (`docs/to-fix/TODO.md` M-21/M-31). The migration target is
  `--dart-define` at build time (`flutter run --dart-define=SUPABASE_URL=...`),
  owned by I-34 + M-13 in the current orchestration.

> Never commit `.env` (gitignored). Never put secrets in code or docs.

### Make targets (all verified to exist)

| Target | What it does |
|--------|--------------|
| `make build` | `flutter build apk` (or `TARGET=ios` → unsigned IPA) |
| `make dev` | `flutter run` (or `TARGET=android`/`waydroid`/`simulator`/`ios-adhoc`/device id) |
| `make install` | Install APK/IPA to device (`TARGET=ios-adhoc` → devicectl install of the fastlane-built ad-hoc IPA; `TARGET=ios` aliases it) |
| `make build-cli` | `go build -o samay ./cmd/samay-admin` |
| `make build-linux` | Cross-compile CLI for linux/amd64 → `samay-linux` |
| `make flutter-test` | `flutter test` |
| `make flutter-analyze` | `dart analyze` |
| `make test` | `flutter test` + `go test ./... -v` |
| `make lint` | `dart analyze` + `go vet` (+ `golangci-lint` if installed) |
| `make clean` | `flutter clean`, removes Go binaries + IPA dir |
| `make migrate-check` | Shows whether migrations are committed to git |
| `make supabase-*` | Supabase CLI start/stop/status/reset (ports from `supabase/config.toml`) |
| `make supabase-docker-*` | Self-hosted Compose stack start/stop/status/reset (in `supabase/`) |
| `make supabase-testing-*` | Isolated testing stack (in `supabase-testing/`) |

### Supabase stack & the approved port map

Samay's self-hosted Supabase must **coexist with the Juega stack**, which owns
host ports `5432, 54321, 54323, 8443`. Samay's approved port map
(also in `AGENTS.md`):

| Service | Port |
|---------|------|
| PostgreSQL (direct) | **54382** |
| Studio | **54381** |
| Mailpit (dev email) | **54384** |
| Kong (API gateway — REST, Auth, Realtime, Storage all route here) | **54386** |
| Analytics | **54388** |
| Kong HTTPS | **54443** |

- **Local API base URL: `http://127.0.0.1:54386`** (the curl opt-tests default to this).
- The Compose files / `config.toml` are **mid-remap** (I-02/M-01..M-10): some
  services still declare the old `5432/54321` mappings. Until the remap lands,
  do **not** `docker compose up` while Juega is running, and never map Samay
  services onto Juega's ports.
- Self-hosting details (compose layout, migration-based testing, reset flows)
  land in `<private-ops-repo>/SELFHOSTING.md` (planned, D-08). Deployment URLs are
  placeholders in `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` (planned, D-10) — e.g.
  `https://samay-api.example.com`. **Do not invent deployment URLs in code or docs.**
- Database migrations: `supabase/migrations/*.sql` (applied by
  `supabase/migrate.sh`, `supabase/reset.sh`, or `make supabase-docker-reset`),
  tested with pgTAP in `supabase/tests/schema_test.sql`.

---

## Repo layout map

```
AGENTS.md                     Development methodology (TDD, phases, ports, agent protocol)
Makefile                      All build/dev/test/supabase targets
pubspec.yaml                  Flutter deps (Riverpod, GoRouter, Supabase, Hive, …)
go.mod                        Go module github.com/samay-app/samay

lib/                          Flutter app
  main.dart                   dotenv load → Supabase.initialize → runApp
  app.dart                    SamayApp (MaterialApp.router, dark theme)
  core/                       config/ (EnvConfig), errors/ (AppError hierarchy),
                              extensions/ (toAppError), providers/ (auth, config, user),
                              router/ (app_router, auth_guard, route_paths),
                              services/ (supabase_service, storage_service),
                              theme/ (app_theme, samay_durations)
  features/                   auth/ profile/ feed/ friends/ groups/
                              (events/, qr/, chat/, … planned — routes render VComingSoonScreen)
  shared/                     providers/ (realtime), widgets/ (v_button, v_input, v_card,
                              v_chip, v_badge, v_shard_icon, rank_badge, v_coming_soon)

cmd/samay-admin/              Cobra CLI entry (users, events, groups, reports, shards,
                              config, subs, system, feature-requests) — thin wrappers
internal/ops/                 All CLI business logic (importable by future API server)
internal/db/                  PostgREST HTTP client (service_role) + Go models
internal/format/              Table/JSON output formatters

supabase/                     Self-hosted stack: config.toml, docker-compose*.yml,
                              migrations/ (17 files), seed.sql, run.sh, reset.sh,
                              migrate.sh, tests/schema_test.sql (pgTAP), volumes/
supabase-testing/             Isolated testing stack (same layout, mailpit, separate volumes)

test/                         Flutter unit/widget tests + backend curl opt-tests
  opt-NNN-*.sh                curl integration tests (self-contained, exit 0/1)
  run_all_backend.sh          Runs every opt test against http://127.0.0.1:54386
  README.md                   Full testing guide
integration_test/             Modular Flutter integration suite — PLANNED (I-01)
test_runner.sh                gum-based MANUAL end-user QA runner (63 cases, phases 00–04)

docs/
  planification/              Read-only product/CLI/web-server specs
  implementation/             Read-only step specs + cross-references.md (dependency graph)
  development/                Daily developer logs + *.DONE markers per phase
  agents/                     Orchestration: ORCHESTRATION.md, AGENT-RULES.md,
                              FILE-OWNERSHIP.md, AGENT-REGISTRY.md
  to-fix/                     Adversarial review findings (173 findings, TODO.md statuses)
  design/                     DISCO-DESIGN-SYSTEM.md — PLANNED (D-11)
  infra/                      SELFHOSTING.md, DEPLOYMENT-PLACEHOLDER.md — PLANNED (D-08/D-10)
  security/                   SECURITY.md, E2EE-ARCHITECTURE.md — PLANNED (D-06/D-07)

tools/agent_lock.sh           File semaphore for parallel agents (see "Parallel work" below)
repo-locks/                   Held locks (gitignored, ephemeral)
```

---

## The 180-agent orchestration (read before contributing)

The repo is being driven by a **180-agent campaign** (`docs/agents/ORCHESTRATION.md`):
documentation (D-01..D-12) → implementation (I-01..I-78) → modifications (M-01..M-30)
→ disco UI (U-01..U-30) → security (S-01..S-20) → verification (V-01..V-10).

- **Every agent must read `docs/agents/AGENT-RULES.md` first** — it defines the
  repo-wide read mandate, the file-semaphore protocol, test conventions, and the
  report format.
- **File ownership:** `docs/agents/FILE-OWNERSHIP.md` maps every path to its
  owning agent. Don't modify a file owned by another agent unless your
  assignment requires it (and hold its lock).
- The design language (black background, disco colors, Playfair Display, pink
  glow) is being standardized in **`docs/design/DISCO-DESIGN-SYSTEM.md` (planned,
  D-11)** — reference it for tokens/typography/palette once it lands.

### Parallel work: `tools/agent_lock.sh` (for humans too)

The repo is edited by many agents at once; humans working in parallel use the
same file-semaphore. **Acquire a lock before editing a file, release after.
If someone else holds it, wait — never edit under a held lock.**

```bash
tools/agent_lock.sh list                                     # who holds what
tools/agent_lock.sh status lib/core/router/app_router.dart   # LOCKED/FREE + owner

tools/agent_lock.sh acquire lib/core/services/supabase_service.dart --owner my-name
# ... edit the file ...
tools/agent_lock.sh release lib/core/services/supabase_service.dart --owner my-name

# One-shot: acquire → run → auto-release
tools/agent_lock.sh run lib/core/router/app_router.dart --owner my-name -- \
  bash -c 'echo editing; sleep 1'
```

- Locks live in `repo-locks/` (gitignored); each lock is an atomic directory
  created with `mkdir`, so they're crash-safe.
- `acquire` polls every 2s and times out after 1800s by default
  (`--timeout` to change). Exit codes: 0 acquired, 2 timeout, 3 usage error.
- For multi-file edits: acquire all locks first, edit, then release all.
- If your acquire times out, report "BLOCKED on <path> by <owner>" and move on.

---

## Testing summary

| Layer | Command | Notes |
|-------|---------|-------|
| Flutter unit/widget | `make flutter-test` | `test/` — mirrors `lib/` layout. Baseline: **176 pass / 23 documented pre-existing fail** (Supabase-not-initialized harness tests + brittle `structure_test.dart`; fixing is I-47) |
| Flutter modular integration | `flutter test integration_test/<module>_test.dart -d <device>` | `integration_test/` — **being created by I-01**; intended layout: one file per module (`auth_flow_test.dart`, `groups_flow_test.dart`, …), each independently runnable, plus a `run_all.sh` orchestrator |
| Backend (curl) | `bash test/run_all_backend.sh` | Runs every `test/opt-*.sh` against Kong at `http://127.0.0.1:54386`; requires the stack up + `make supabase-docker-reset` |
| Go | `go test ./...` | 82 tests (CLI flag/validation tests + ops business logic with `httptest` mocks) |
| SQL (pgTAP) | `supabase db test` | `supabase/tests/schema_test.sql` — 125 assertions: extensions, 21 enums, 30+ tables, triggers, RPCs, RLS policies, seed data |
| Manual end-user QA | `bash test_runner.sh` | gum-based manual runner (63 cases, auth → leaderboard), writes a timestamped results markdown |

See [`test/README.md`](test/README.md) for the full test matrix and the curl
test-writing guide.

---

## How to add a feature

One paragraph, the short version: **build in layers so the next feature slots in
without a rewrite** — put data shapes in typed models (`lib/core/models/`,
freezed planned under I-10; raw `Map<String, dynamic>` is today's stopgap),
business logic in feature-scoped services or `internal/ops` (Go) rather than
screens, state in Riverpod providers, UI in `lib/shared/widgets/` using the
design tokens (today: `SamayTheme` + `SamayDurations`; tokens land in
`lib/core/design_tokens/` under I-16 and the disco spec in
`docs/design/DISCO-DESIGN-SYSTEM.md`), routes registered in
`lib/core/router/route_paths.dart` + `app_router.dart`, and new behavior behind
a **feature flag** once `lib/core/feature_flags/` lands (I-49) so it can ship
dark and be released by config. Write the failing test first (widget test in
`test/features/`, curl opt-test in `test/opt-NNN-*.sh` for backend, pgTAP case
in `supabase/tests/schema_test.sql` for SQL), implement the minimum, then run
`make test` + `dart analyze` before calling it done. Tuneable values go in
`app_config` (admin: `./samay config set <key> <value> --confirm`) — never
hardcode economy/QR/limit constants.

---

## Status & known gaps

- **Done:** Phases 00–04 (foundation, admin CLI, auth/profile, friends/groups,
  shard donations, rankings), H-01/H-02 fixes, C-07 CLI restoration, the
  180-agent campaign through Phase 4.5 (implementation foundations
  I-01..I-78, modifications M-01..M-30, disco UI U-01..U-30, security
  S-01..S-20 — see `docs/agents/ORCHESTRATION.md`).
- **Foundations shipped (feature-flagged):** ECRT/EDET/CHAT/QR/FEED/PHUP/PFND
  screens, paywall/cosmetics/minigames/shard-ledger, deep links, telemetry
  and crash placeholders (I-49..I-78) — Phase 05+ features land on these
  bases; several routes still render `VComingSoonScreen` until the full
  flows ship.
- **Planned:** full phases 05–15 (events end-to-end, QR attendance, E2EE chat
  UX, feed/photos, notifications, subscriptions, party finder, web servers)
  — routes exist; the dependency graph lives in
  `docs/implementation/cross-references.md`.
- **Known issues:** `docs/to-fix/TODO.md` (statuses re-verified by V-02,
  2026-08-11); `docs/implementation/cross-references.md` (step-by-step
  dependency graph, campaign rows updated by V-01).
- **Security:** audit series closed 6 live issues incl. one CRITICAL
  (anon EXECUTE on all SECURITY DEFINER functions) — see
  `docs/security/FINAL-SECURITY-REPORT.md` (S-20).
