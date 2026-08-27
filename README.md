# Samay

**Samay** is a disco/social-life mobile app for the 18–35 Latin American urban
demographic: plan social gatherings, invite friends, attend events
(QR-verified), earn and spend **shards**, climb group rank leaderboards, and
relive the night through photos and mini-games.

This repository is a **3-track project**:

| Track | What | Status |
|-------|------|--------|
| **Flutter app** (`lib/`, `test/`) | iOS + Android app — auth, profile, friends, groups, shard donations, rankings, events, QR, E2EE chat (1:1 + group), feed/photos, notifications, minigames, party finder. Most screens live behind feature flags; subscriptions stay gated (RevenueCat wiring pending) | Phases 00–04 done; phase 05+ foundations landed; edge functions pending |
| **Go admin CLI** (`cmd/samay-admin/`, `internal/`) | Cobra-based operational CLI (`samay`) using the `service_role` key — users, events, groups, reports, shards, config, subs, system | Complete |
| **Self-hosted Supabase** (`supabase/`, `supabase-testing/`) | PostgreSQL 17 + GoTrue + PostgREST + Realtime + Storage + Kong gateway; Docker Compose and `config.toml` dual setups; migration-based testing | Done — approved port map enforced |

Docs hub: [`docs/README.md`](docs/README.md). DB catalog: `<private-ops-repo>/DATABASE.md`. Go CLI/API surface: `<private-ops-repo>/BACKEND.md`.

---

## Quickstart

Prerequisites: Flutter (`/opt/homebrew/share/flutter/bin/flutter` on this machine),
Go ≥ 1.26, Docker + `docker compose`.

```bash
# 1. Dart dependencies
flutter pub get

# 2. Environment
cp .env.example .env
# Fill in SUPABASE_URL / SUPABASE_ANON_KEY (local or remote)

# 3. Run the app (or: make dev TARGET=android)
flutter run

# 4. Tests
make flutter-test        # Flutter unit/widget tests
make flutter-analyze     # dart analyze
make test                # flutter-test + go test ./...
make build-cli           # builds ./samay admin CLI binary

# 5. Backend stack (self-hosted Supabase on the approved ports)
make supabase-docker-start
bash test/run_all_backend.sh   # curl backend integration tests (needs the stack)
```

### Environment: compile-time `--dart-define`

The app reads `SUPABASE_URL` and `SUPABASE_ANON_KEY` at **build time** via
`--dart-define-from-file=.env` (`EnvConfig` → `String.fromEnvironment`).
Nothing env-related is bundled as a Flutter asset and `.env` is gitignored.

### Make targets

| Target | What it does |
|--------|--------------|
| `make build` | `flutter build apk` (or `TARGET=ios` → unsigned IPA) |
| `make dev` | `flutter run` (TARGET=android/simulator/ios-adhoc/device id) |
| `make install` | Install APK/IPA to device |
| `make build-cli` / `build-linux` | Go admin CLI binaries |
| `make build-api` | Gin API server binary |
| `make flutter-test` / `flutter-analyze` | Flutter suite / static analysis |
| `make test` | Flutter + Go suites |
| `make check` | dart analyze + flutter analyze + go vet + ports gate + secrets gate |
| `make clean` | Build artifacts |
| `make supabase-*` / `supabase-docker-*` / `supabase-testing-*` | Supabase stack lifecycle |

### Supabase port map (coexists with the Juega stack)

Juega owns host ports `5432, 54321, 54323, 8443` — never map Samay onto them.
Samay's approved map:

| Service | Port |
|---------|------|
| PostgreSQL (direct) | **54382** |
| Studio | **54381** |
| Mailpit (dev email) | **54384** |
| Kong (API gateway — REST, Auth, Realtime, Storage) | **54386** |
| Analytics | **54388** |
| Kong HTTPS | **54443** |

Local API base URL: `http://127.0.0.1:54386`. Self-hosting details:
[`<private-ops-repo>/SELFHOSTING.md`](<private-ops-repo>/SELFHOSTING.md); deployment targets are
placeholders in [`<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md`](<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md)
— do not invent deployment URLs in code or docs.
Database migrations: `supabase/migrations/**` (28 SQL files across numbered
domain dirs, mirrored byte-identical into `supabase-testing/migrations/`),
applied by `supabase/migrate.sh` / `reset.sh`.

---

## Repo layout map

```
lib/                          Flutter app
  main.dart                   Supabase.initialize (dart-define env) → runApp
  app.dart                    SamayApp (MaterialApp.router, dark theme)
  core/                       config/, design_tokens/, deep_links/, errors/,
                              extensions/, logging/, models/ (freezed),
                              providers/, repositories/, router/, services/,
                              telemetry/, theme/, utils/
  crypto/                     E2EE chat stack (X3DH, double ratchet,
                              group sender keys, key store) — see
                              docs/security/E2EE-ARCHITECTURE.md
  features/                   auth/ chat/ cosmetics/ events/ feed/ friends/
                              groups/ minigames/ notifications/ party_finder/
                              photos/ profile/ qr/ shards/
                              social/ (serves the `/main/groups` bottom tab:
                              Grupos + Amigos pills, global user ranking)
                              subscriptions/ — each nests screens/ providers/
                              widgets/ logic/
  l10n/                       ARB localizations — Spanish-first (`app_es.arb`
                              template), English secondary; generated classes
  shared/                     shared widgets (v_button, v_input, v_card, …)

cmd/samay-admin/              Cobra CLI entry — thin wrappers
cmd/samay-api-server/         Gin API scaffold (admin routes + health)
internal/db|ops|format|validate   PostgREST client, business logic,
                              formatters, shared validation
                              — surface: <private-ops-repo>/BACKEND.md

supabase/                     Self-hosted stack: config.toml, docker-compose*.yml,
                              migrations/**, seed-*.sql, run/reset/migrate scripts,
                              tests/schema_test.sql (pgTAP), volumes/
supabase-testing/             Isolated testing stack (same layout)

test/                         Flutter unit/widget tests + backend curl opt-tests
  opt-NNN-*.sh                curl integration tests (self-contained, exit 0/1)
  run_all_backend.sh          Runs every opt test against http://127.0.0.1:54386
integration_test/             Hermetic modular integration suite (21 flows,
                              runner.sh)
test_runner.sh                gum-based MANUAL end-user QA runner

docs/                         See docs/README.md for the map
tools/                        check_secrets/check_ports/check_migrations,
                              agent_lock.sh, seed_dev_data.sh, hooks
```

---

## Testing summary

Baseline numbers below are re-verified whenever docs change; if you change
code, update them in the same commit.

| Layer | Command | Baseline (2026-08-27) |
|-------|---------|----------------------|
| Static analysis | `dart analyze` | **0 issues** |
| Flutter unit/widget | `make flutter-test` | **2471 pass / 0 fail** |
| Go | `go test ./...` | green — **188 tests**, 6 packages |
| Integration flows | `bash integration_test/runner.sh` (hermetic) | **21 registered flows** |
| Backend (curl) | `bash test/run_all_backend.sh` | **16 opt-tests** (needs the stack up; opt-007 static gate reports SERVICE_KEY-vs-.env alignment drift on opt-001..006 — local `.env` rotated after the 2026-08-25 baseline; runtime runs pass — see docs/history/phase-13/2026-08-26_monochrome-refactor.md) |
| SQL (pgTAP) | `supabase db test` | **plan(661)** assertions (needs the stack; verified 661/661 on 2026-08-27) |
| Manual end-user QA | `bash test_runner.sh` | gum-based manual runner |

See [`test/README.md`](test/README.md) for the full test matrix and the curl
test-writing guide.

---

## How to add a feature

Build in layers so the next feature slots in without a rewrite:

1. Data shapes → typed freezed models in `lib/core/models/`.
2. Business logic → feature services (`lib/core/services/`) or repositories
   (`lib/core/repositories/`) — screens stay dumb; Go side goes in
   `internal/ops`.
3. State → Riverpod providers co-located with the feature (cross-cutting ones
   in `lib/core/providers/`).
4. UI → `lib/shared/widgets/` + design tokens (`docs/design/DESIGN.md`);
   loading/error/empty via `VStateView` family; lists via builders.
5. Routes → constants/builders in `lib/core/router/route_paths.dart`; no raw
   path strings elsewhere.
6. New behavior ships behind a feature flag (`lib/core/config/feature_flags.dart`).
7. Tuneable values go in `app_config` (`./samay config set <key> <value>
   --confirm`) — never hardcode economy/QR/limit constants.
8. Write the failing test first at every touched layer (widget test in
   `test/features/`, flow file in `integration_test/`, curl opt-test
   `test/opt-NNN-*.sh` for backend, pgTAP case in `supabase/tests/schema_test.sql`
   for SQL), implement the minimum, then run `make check` + `make test`.

---

## Status & known gaps

- **Done:** foundation, admin CLI, auth/profiles, friends/groups (+ donations +
  rankings), events creation/detail, QR attendance/scanner (SQL RPC backing),
  E2EE chat 1:1 + group, feed/photos foundations, notification center,
  minigames, party finder, paywall shell, self-hosted infra + test stacks.
- **Pending:** Edge Functions (`supabase/functions/` is a boot stub — QR/rank/
  notify mechanics ship as SQL RPCs + pg_cron meanwhile), server-side rate
  limiting, RevenueCat webhook + subscription wiring, event invites/status
  server flows, cosmetics purchase flow, wager full-flow, collage PNG export,
  video souvenir/music library, alpha/beta launch phases, post-MVP web servers.
  Authoritative per-step statuses: `docs/specs/steps/cross-references.md`;
  open work items: specs kept under `docs/specs/steps/` for unimplemented steps.
- **Security posture + open items:** [`docs/security/SECURITY.md`](docs/security/SECURITY.md).
