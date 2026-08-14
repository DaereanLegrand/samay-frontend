# 2026-08-10 — M-30 infra-close: PHASE 4.3 COMPLETION REPORT

**Agent:** M-30 (FINAL agent, Phase 4.3 — second attempt; first session stalled mid-sweep, 5 stale locks freed)
**Role:** port-map checker finalization + infra-doc final sweep + 4.3 completion gate
**Result:** ✅ **PHASE 4.3 COMPLETE** — Definition of Done met (ORCHESTRATION.md §4.3)

---

## 1. What was built

### 1.1 `tools/check_ports.sh` — final for the M-series reality

The ~77-line partial diff from the stalled first session was read, verified complete
and correct, then finished. Final behavior (all RED-probed):

1. **`CONTAINER_HOSTS` extended** with `imgproxy` + `functions` — their internal
   references (`imgproxy:5001`, `samay(-testing)-functions:9000`) are now INFO.
   Also: template-prefix hostnames (`"${pre}-functions"` in static-test string
   lists — the `-functions:9000` artifact) classify as container-internal via a
   leading-dash strip in `is_container_host` (hostnames never start with `-`).
2. **`.env` source-of-truth validation** (new): the six host-port-map keys
   (`POSTGRES_PORT`/`STUDIO_PORT`/`KONG_HTTP_PORT`/`KONG_HTTPS_PORT`/
   `MAILPIT_PORT`/`ANALYTICS_PORT`) are validated against the approved map
   **only in `.env` files** (the same key names in compose/other files are
   container-internal env → INFO). The awk KEY=VALUE pass now carries the key
   into `report_reference` as `env=KEY`.
3. **`${VAR:-PORT}` expansion fix**: the awk match-and-stitch no longer leaks
   the trailing `}` (`substr(m, ci+2, len-ci-2)` instead of `substr(m, ci+2)`),
   so `http://127.0.0.1:${KONG_HTTP_PORT:-54386}` scans as `54386`, never `54386}`.
4. **Full-line comments skipped** (prose port mentions are documentation, not
   bindings); `0.0.0.0` listen addresses explicitly INFO; `report_reference`
   comment-carried keys (`env=` branch) handled.
5. **No classifier regression**: same 19 mappings as the committed baseline;
   coverage grew 71→82 OK / 138→145 INFO / 184→202 references, 0 violations.

**RED probes (scratch tree, repo untouched):**

| Probe | Result |
|---|---|
| `.env` `POSTGRES_PORT=5432` (Juega collision) | VIOLATION + STRICT FAIL ✓ |
| `.env` `STUDIO_PORT=54444` (deviation) | VIOLATION + STRICT FAIL ✓ |
| `.env` restored to approved values | STRICT PASS ✓ |
| Compose `"${POSTGRES_PORT:-54382}:5432"` | mapping `db 54382→5432` OK ✓ |
| URL `127.0.0.1:${KONG_HTTP_PORT:-54386}` | `54386` approved, no `}` leak ✓ |

### 1.2 SELFHOSTING.md — final sweep

Header "Last verified" + M-30; deviations rows **23, 24, 25, 26** flipped ✅;
§6 "Definition of done for the remap" marked **MET** with the checkpoint note.
Every row of the §6 table is now ✅ (rows 1-28).

### 1.3 DEPLOYMENT-PLACEHOLDER.md — final sweep

Header; §1.1 rows **2** (port remap complete) + **4** (Go API server landed,
I-41); §5 Flutter-app env row (dart-define landed — stale `flutter_dotenv`
wording removed); §6 **R26** SMTP note refreshed; §7 **M-30 addendum**
reversing the three original "absent / still mapped" findings.

### 1.4 Orchestration docs

- **ORCHESTRATION.md**: Phase Budget 4.3 row → ✅ COMPLETE; new
  "M-01..M-30 — Phase 4.3" section with the locked status block, roster
  summary (25 logs + 5 folded IDs), checkpoint validation, stack-start
  checklist, and cross-phase handoffs.
- **FILE-OWNERSHIP.md**: M-30 row expanded with the DONE description.
- **TODO.md**: M-30 completion block (newest-first position).

---

## 2. M-roster — what actually ran (M-01..M-30)

Sources: `docs/process/FILE-OWNERSHIP.md` + `docs/to-fix/TODO.md` + the daily
logs in `docs/history/phase-00-foundation/`. 25 agents shipped evidence
logs; 5 agent IDs were consolidated (no separate log — work folded into the
listed agents): **M-04+M-05 → M-01/M-06** (compose overrides scope),
**M-14 → M-15** (fastlane stub targets), **M-16 → M-15** (install/deploy
placeholder targets), **M-19 → M-17/M-18** (Gemfile + fastlane README;
`Gemfile.lock` committed at the first `bundle install`).

| ID | Deliverable | Log |
|---|---|---|
| M-01 | Compose base overhaul: pinned official tags, healthchecks/`depends_on`/`restart`, env compat for pinned images | ✅ `2026-08-10_M01-compose-base.md` |
| M-02 | Env-driven `${VAR:-default}` host ports + `.env` port map source of truth (DKR-03) | ✅ `2026-08-10_M02-env-compose.md` |
| M-03 | Kong key-auth `$VAR` templating + opt-test key alignment | ✅ `2026-08-10_M03-kong-keys.md` |
| M-04 | Compose overrides — folded → M-01/M-06 | — |
| M-05 | Compose overrides — folded → M-01/M-06 | — |
| M-06 | pg17/s3/mailpit override layer (DKR-02/08), MinIO pinned, `COMPOSE_FILE` | ✅ `2026-08-10_M06-overrides.md` |
| M-07 | imgproxy + edge-runtime services, Kong `/functions/v1/` route, supavisor deferred | ✅ `2026-08-10_M07-services.md` |
| M-08 | Storage-buckets migration + storage.objects RLS (S-09 gap) | ✅ `2026-08-10_M08-storage-buckets.md` |
| M-09 | Kong entrypoint mount fix + realtime WS route | ✅ `2026-08-10_M09-kong.md` |
| M-10 | Stack parity (byte-identity contract, script drift fix) | ✅ `2026-08-10_M10-parity.md` |
| M-11 | Makefile flutter half (test split, dart-defines, macvm quoting) | ✅ `2026-08-10_M11-makefile-flutter.md` |
| M-12 | Makefile docker/supabase half (pgTAP `--db-url`, backend-tests, stack-check, minio volume on reset) | ✅ `2026-08-10_M12-makefile-docker.md` |
| M-13 | Makefile env sourcing + `secrets-check` gate (MKE-02/03/08) | ✅ `2026-08-10_M13-makefile-env.md` |
| M-14 | Makefile fastlane targets — folded → M-15 | — |
| M-15 | Makefile finalization: lane-name contract, `migrate-check` extraction, deploy placeholders, `bundle-install` | ✅ `2026-08-10_M15-makefile-final.md` |
| M-16 | Install/deploy placeholder targets — folded → M-15 | — |
| M-17 | Fastlane iOS (lanes + fail-fast guard, Appfile, Gemfile) | ✅ `2026-08-10_M17-fastlane-ios.md` |
| M-18 | Fastlane Android (lanes + full credential guard) | ✅ `2026-08-10_M18-fastlane-android.md` |
| M-19 | Gemfile + fastlane README — folded → M-17/M-18 | — |
| M-20 | `.github/workflows/ci.yml` (analyze/go/backend-static jobs) | ✅ `2026-08-10_M20-ci.md` |
| M-21 | `.github/workflows/build.yml` (build + stack-tests job) | ✅ `2026-08-10_M21-ci-build.md` |
| M-22 | `.github/workflows/release.yml` (16-secret registry, placeholders only) | ✅ `2026-08-10_M22-ci-release.md` |
| M-23 | `lib/features/**` restructure (58 files, screens/providers/widgets/logic) | ✅ `2026-08-10_M23-restructure.md` |
| M-24 | `lib/core/**` restructure (feature_flags → config/, ARC-03) | ✅ `2026-08-10_M24-core-restructure.md` |
| M-25 | `.opencode/` project config + 4 agents (ARC-08/TOOL-05/L-02) | ✅ `2026-08-10_M25-opencode.md` |
| M-26 | Lint rules (CQ-08) + pre-commit hooks (TOOL-04) | ✅ `2026-08-10_M26-lints-hooks.md` |
| M-27 | Android platform contract (keystore fail-fast, wrapper, manifest) | ✅ `2026-08-10_M27-android.md` |
| M-28 | iOS platform contract (pod fix, min-iOS 16, privacy keys) | ✅ `2026-08-10_M28-ios.md` |
| M-29 | web/macos/linux/windows cleanup | ✅ `2026-08-10_M29-platforms.md` |
| **M-30** | Port checker finalization + infra-doc sweep + completion gate | ✅ **this report** |

---

## 3. Validation matrix (final counts)

| Gate | Result | Counts |
|---|---|---|
| `tools/check_ports.sh --strict` | ✅ **STRICT PASS** | 19 mappings · 202 references · 82 OK · 145 INFO · **0 VIOLATIONS** |
| `tools/check_ports.sh --report` | ✅ exit 0 | same scan, informational |
| `bash test/opt-007-compose-static.sh` | ✅ green | **365 checks**, all 9 compose combos parse (`docker compose config --quiet`) |
| `make check` | ✅ green | secrets-check PASS · `dart analyze` 0 issues · `flutter analyze` 0 issues · `go vet` ok · port gate PASS |
| `dart analyze` | ✅ 0 issues | — |
| `go test ./...` | ✅ green | 5/5 packages ok |
| `flutter test` (baseline, re-measured M-29) | ✅ 1642/0 | unchanged by M-30 (docs + shell only) |
| Integration flows | ✅ 17/17 | `integration_test/runner.sh` (I-78) |
| pgTAP plan consistency | ✅ 25/25 | qr + minigame plan(312) dart tests |
| Baseline classifier comparison | ✅ no regression | committed version: 19 mappings / 184 refs / 71 OK / 138 INFO / 0 VIOL |

---

## 4. Checkpoint stack-start checklist (handoff to the orchestrator)

Runs at the STOP-100 checkpoint (stack currently NOT started — live gates
were not run per AGENT-RULES; everything below is static-verified):

```bash
# 1. Start the stack on the approved map (pg17 + s3 layering via .env COMPOSE_FILE)
make supabase-docker-start                      # cd supabase && docker compose up -d --wait
#    pre-flight: tools/check_ports.sh --strict → STRICT PASS (proven above)

# 2. Migrate + seed (compose up does NOT migrate — volumes/db/init is empty)
bash supabase/migrate.sh                        # 24 migrations (idempotent) + seed.sql

# 3. Schema tests — FIRST RUN PULLS the supabase/pg_prove:3.36 docker image
make supabase-db-test                           # supabase db test --db-url …54382… → 312 pgTAP assertions

# 4. Backend integration tests (Kong 54386)
make supabase-backend-tests                     # bash test/run_all_backend.sh — live opt-001..006 + static 005/007
```

**Release-time ops items (reported, NOT repo defects — do NOT block 4.4):**

| # | Item | Owner |
|---|---|---|
| 1 | **Kong keys provisioning**: dev keys live in tracked `supabase/.env.local` + `.env.example` placeholders; real per-env keys provisioned at release (DEPLOYMENT-PLACEHOLDER §6 R25, 16 GitHub secrets) | release owner / S-08 |
| 2 | **Minio-volume handling**: `reset.sh` does NOT clear the `minio-data` named volume; `make supabase-docker-reset` does (M-12). Use the make target for full teardowns | ops |
| 3 | **Branding drift** (M-29 report): `Makefile:14 APP_NAME := samay_app` (cosmetic IPA name); `android:label="samay"` vs iOS/web "Samay" (one branding decision); `.flutter-plugins-dependencies` tracked at root (suggest gitignore, S-08) | release owner / U-track |
| 4 | `README.md:238` stale `lib/core/feature_flags/` path (pre-I-49 wording) | D-05 / V-09 |
| 5 | `MediaService.uploadEventCover` → `getPublicUrl` on the PRIVATE events bucket | S-09 |
| 6 | SMTP real relay creds + H-21 key rotation | S-08 / release ops |
| 7 | iOS Hive-dir backup exclusion + `first_unlock_this_device` keychain (optional) | S-18 |
| 8 | `[auth.smtp]` config.toml section (compose `GOTRUE_SMTP_*` already carries placeholders) | MKE-01 / S-08 |

---

## 5. Cross-phase handoffs

- **4.4 UI (U-01..U-30):** disco theme lands on the restructured tree (M-23/M-24
  conventions: `screens/ providers/ widgets/ logic/` per feature, `design_tokens/`
  + `config/` — no `constants/` dir by decision). Branding drift items above are
  U-track's to resolve. `test/opt-008-makefile-static.sh` §6-§8 + M-26 lint rules
  gate any platform/theme drift.
- **4.5 Security (S-01..S-20):** keystore/signing placeholders (M-17/M-18/M-27) to
  re-audit; SMTP creds + H-21 rotation (S-08); storage signed-URL issuance-vs-
  retrieval RLS nuance + `uploadEventCover` (S-09); platform backup/backup-
  exclusion decisions (S-18); `.flutter-plugins-dependencies` hygiene; MKE-01.
- **4.6 Verifiers (V-01..V-10):** V-04 re-runs `tools/check_ports.sh --strict`
  (now also validates `.env` source-of-truth keys) + V-05 the test matrix; V-03
  checks this report's roster table against the daily logs; V-02 re-verifies the
  TODO.md statuses (M-30 block + category-file flips stay D-03's).

---

## 6. Files modified (lock evidence)

| File | Lock | Status |
|---|---|---|
| `tools/check_ports.sh` | acquire 2026-08-11T01:53:46Z (`2b2cdcc…`) | modified (finalized M-30 diff) |
| `<private-ops-repo>/SELFHOSTING.md` | acquire 2026-08-11T01:53:46Z (`a00c2a0…`) | modified (rows 23-26 + DoD + header) |
| `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` | acquire 2026-08-11T01:53:47Z (`1de0a50…`) | modified (§1.1/§5/§6/§7 + header) |
| `docs/to-fix/TODO.md` | acquire 2026-08-11T01:53:47Z (`b802f89…`) | modified (M-30 block) |
| `docs/process/DEVELOPMENT-WORKFLOW.md` | acquire 2026-08-11T01:53:47Z (`644dbb2…`) | modified (4.3 COMPLETE + roster section) |
| `docs/process/FILE-OWNERSHIP.md` | acquire 2026-08-11T01:53:47Z (`718c5e9…`) | modified (M-30 row DONE) |
| `docs/history/phase-00-foundation/2026-08-10_M30-infra-close.md` | new file (creator-owned) | **this report** |

All 6 locks held by `M-30-infra-close`; release verified after the final gate.
No commits made (AGENT-RULES §0.4); the orchestrator commits at the checkpoint.

## 7. Issues found (reported, NOT fixed — out of scope)

1. Pre-existing (M-29 report, unchanged): `APP_NAME := samay_app` cosmetic drift;
   Android label vs display-name drift; `.flutter-plugins-dependencies` tracked.
2. `README.md:238` stale feature_flags path (D-05/V-09 scope).
3. `uploadEventCover` private-bucket public-URL mismatch (S-09 scope).
4. MKE-01 `[auth.smtp]` config.toml section absent (compose env covers it with
   placeholders) — S-08/release ops.
5. First `make supabase-db-test` pulls `supabase/pg_prove:3.36` (network) — by
   design (SELFHOSTING §3.2), noted for the checkpoint.
6. The stale M-23 TODO note about pgTAP plan-consistency failures is superseded
   (I-78/M-08 fixed it; verified 25/25 green today) — category files stay D-03's.

## 8. Sources

- Repo: AGENTS.md Port Convention, docs/process/{AGENT-RULES,FILE-OWNERSHIP,ORCHESTRATION}.md,
  docs/to-fix/TODO.md, <private-ops-repo>/{SELFHOSTING,DEPLOYMENT-PLACEHOLDER}.md, Makefile,
  test/opt-007-compose-static.sh, .github/workflows/ci.yml, supabase/{.env,docker-compose.yml,config.toml,tests/schema_test.sql}
- No external URLs consulted this session (port map + repo contracts only).
