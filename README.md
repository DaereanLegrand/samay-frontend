# Samay

**Samay** is a disco/social-life mobile app for the 18–35 Latin American urban
demographic: plan social gatherings, invite friends, attend events (QR-verified),
earn and spend **shards**, climb group rank leaderboards, and relive the night
through photos and mini-games.

This repository is a **3-track project**:

| Track | What | Status |
|-------|------|--------|
| **Flutter app** (`lib/`, `test/`) | iOS + Android app — auth, profile, friends, groups, shard donations, rankings, events, QR, E2EE chat, feed/photos, notifications, minigames, party finder. Phase 05+ screens ship behind feature flags (most enabled; subscriptions still gated) | Phases 02–04 done; 05+ foundations landed (I-49..I-78); edge functions pending |
| **Go admin CLI** (`cmd/samay-admin/`, `internal/`) | Cobra-based operational CLI (`samay`) using the `service_role` key — users, events, groups, reports, shards, config, subs, system | Complete |
| **Self-hosted Supabase** (`supabase/`, `supabase-testing/`) | PostgreSQL 17 + GoTrue + PostgREST + Realtime + Storage + Kong gateway; Docker Compose and `config.toml` dual setups; migration-based testing | Foundation done; approved port map enforced (I-02/M-01..M-10) |

Full product spec: [`docs/specs/product/samay_mvp_spec.md`](docs/specs/product/samay_mvp_spec.md).
CLI spec: [`docs/specs/product/samay_admin_cli_spec.md`](docs/specs/product/samay_admin_cli_spec.md).

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

### Environment: compile-time `--dart-define`

The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` at **build time** via
`--dart-define` / `--dart-define-from-file=.env` (`EnvConfig` →
`String.fromEnvironment`; `flutter_dotenv` was removed by I-34 and nothing
env-related is bundled as a Flutter asset).

- **Now:** copy `.env.example` → `.env`, set the two Supabase vars, then
  `make dev` / `make build` (the Makefile injects the defines automatically),
  or pass them explicitly: `flutter run --dart-define-from-file=.env`.

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
- The port remap (I-02/M-01..M-10) is **complete**: every service declares the
  approved map above, and `tools/check_ports.sh --strict` passes with 0
  violations (re-verified 2026-08-11). Never map Samay services onto Juega's ports.
- Self-hosting details (compose layout, migration-based testing, reset flows):
  `<private-ops-repo>/SELFHOSTING.md` (D-08). Deployment URLs are placeholders in
  `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` (D-10) — e.g.
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
  main.dart                   Supabase.initialize (dart-define env) → runApp
  app.dart                    SamayApp (MaterialApp.router, dark theme)
  core/                       config/ (EnvConfig, feature_flags), design_tokens/,
                              deep_links/, errors/ (AppError), extensions/,
                              logging/ (AppLogger), models/ (freezed), providers/,
                              repositories/, router/, services/ (auth, user, group,
                              event, chat, …), telemetry/, theme/, utils/
  crypto/                     E2EE chat stack (x3dh, double ratchet, key store)
  features/                   auth/ profile/ feed/ friends/ groups/ events/ chat/ qr/
                              photos/ notifications/ shards/ cosmetics/ minigames/
                              party_finder/ subscriptions/ — screens/ providers/
                              widgets/ logic/ per feature (M-23); most real screens
                              enabled behind feature flags; subscriptions still gated
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
integration_test/             Hermetic modular Flutter integration suite — 18 flows + smoke (I-01..U-29, runner.sh)
test_runner.sh                gum-based MANUAL end-user QA runner (55 cases, phases 00–04)

docs/
  README.md                     Hub/index — where to find what (Diátaxis layout)
  process/                      How-to: DEVELOPMENT-WORKFLOW.md, FILE-OWNERSHIP.md
  specs/product/                Read-only product/CLI/web-server specs (was planification/)
  specs/steps/                  Read-only step specs + cross-references.md (was implementation/)
  history/                      Daily developer logs + *.DONE markers per phase (was development/)
  design/                       DISCO-DESIGN-SYSTEM.md, DISCO-LUXE-DESIGN-SYSTEM.md (D-11/XL-21)
  infra/                        SELFHOSTING.md, DEPLOYMENT-PLACEHOLDER.md (D-08/D-10)
  security/                     SECURITY.md, E2EE-ARCHITECTURE.md, FINAL-SECURITY-REPORT.md (D-06/D-07/S-20)
  audit/                        Audit reports + gate reports (docs↔code audit, GATE-REPORT)
  to-fix/                       Adversarial review findings (173 findings, TODO.md statuses)

tools/agent_lock.sh           File semaphore for parallel agents (see "Parallel work" below)
repo-locks/                   Held locks (gitignored, ephemeral)
```

---

## The 180-agent orchestration (completed 2026-08-11)

The repo was driven by a **180-agent campaign** (documentation D-01..D-12 →
implementation I-01..I-78 → modifications M-01..M-30 → disco UI U-01..U-30 →
security S-01..S-20 → verification V-01..V-10), which **COMPLETED at STOP-180**
(gate record: `docs/audit/GATE-REPORT.md`). The campaign's per-agent docs
(`ORCHESTRATION.md`, `AGENT-RULES.md`, `AGENT-REGISTRY.md`) were removed; the
standing protocol for any future parallel work is **`docs/process/DEVELOPMENT-WORKFLOW.md`**:

- **File ownership:** `docs/process/FILE-OWNERSHIP.md` maps every path to its
  owning agent. Don't modify a file owned by another agent unless your
  assignment requires it (and hold its lock).
- The design language (black background, disco colors, Playfair Display, pink
  glow) is standardized in **`docs/design/DISCO-DESIGN-SYSTEM.md`** (D-11; LUXE v2
  in `DISCO-LUXE-DESIGN-SYSTEM.md`) — reference it for tokens/typography/palette.

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
| Flutter unit/widget | `make flutter-test` | `test/` — mirrors `lib/` layout. Full suite green — **2209/2209** (re-verified 2026-08-13) |
| Flutter modular integration | `bash integration_test/runner.sh` (hermetic) / `-d <device>` | `integration_test/` — **18 flows + `ui_smoke_test.dart`**: auth, ban, error, profile, theme, cosmetics, events, photos, chat, QR, realtime, notifications, feed, party finder, subscriptions, minigames, telemetry (I-01 + per-feature agents, U-29); hermetic by default (`support/fake_supabase.dart`), each file runs standalone |
| Backend (curl) | `bash test/run_all_backend.sh` | Runs every `test/opt-*.sh` against Kong at `http://127.0.0.1:54386`; requires the stack up + `make supabase-docker-reset` |
| Go | `go test ./...` | 182 tests, 5 packages (re-verified 2026-08-13; CLI flag/validation tests + ops business logic with `httptest` mocks) |
| SQL (pgTAP) | `supabase db test` | `supabase/tests/schema_test.sql` — **385 assertions** (plan 385, I-77/S-03 + 20260814 migrations): extensions, enums, tables, triggers, RPCs, RLS policies, seed data |
| Manual end-user QA | `bash test_runner.sh` | gum-based manual runner (55 cases, auth → leaderboard), writes a timestamped results markdown |

See [`test/README.md`](test/README.md) for the full test matrix and the curl
test-writing guide.

---

## How to add a feature

One paragraph, the short version: **build in layers so the next feature slots in
without a rewrite** — put data shapes in typed freezed models (`lib/core/models/`,
I-10), business logic in feature-scoped services or `internal/ops` (Go) rather
than screens, state in Riverpod providers, UI in `lib/shared/widgets/` using the
design tokens (`lib/core/design_tokens/` + `SamayThemeExtension`, I-16; specs in
`docs/design/DISCO-DESIGN-SYSTEM.md` / `DISCO-LUXE-DESIGN-SYSTEM.md`), routes
registered in `lib/core/router/route_paths.dart` + `app_router.dart`, and new
behavior behind a **feature flag** (`lib/core/config/feature_flags.dart`,
`AppFeatureFlag`, I-49/M-24) so it can ship dark and be released by config.
Write the failing test first (widget test in
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
  I-01..I-78, modifications M-01..M-30, disco UI U-01..U-30 + LUXE XL-01..XL-22,
  security S-01..S-20 — gate record: `docs/audit/GATE-REPORT.md`).
- **Foundations shipped (feature-flagged):** ECRT/EDET/CHAT/QR/FEED/PHUP/PFND
  screens, notification center, paywall/cosmetics/minigames/shard-ledger, deep
  links, storage, realtime, telemetry and crash-reporting seams (I-49..I-78) —
  most real screens are now enabled behind `AppFeatureFlag` toggles;
  **subscriptions stay gated** (RevenueCat service shipped, store wiring pending).
- **Planned / remaining:** edge functions (EEDG/QEDG/PUSH — `supabase/functions/`
  does not exist yet), subscriptions end-to-end, web servers (APIS Gin scaffold
  landed, I-41), and the full phase 05–15 flows per
  `docs/specs/steps/cross-references.md`.
- **Known issues:** `docs/to-fix/TODO.md` (statuses re-verified by R-3,
  2026-08-13); `docs/specs/steps/cross-references.md` (step-by-step
  dependency graph, campaign rows updated by V-01).
- **Security:** audit series closed 6 live issues incl. one CRITICAL
  (anon EXECUTE on all SECURITY DEFINER functions) — see
  `docs/security/FINAL-SECURITY-REPORT.md` (S-20).
