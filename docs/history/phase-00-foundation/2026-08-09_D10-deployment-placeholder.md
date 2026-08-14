# 2026-08-09 — D-10: Deployment Target Architecture Placeholders (`<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md`)

**Agent:** D-10 (Phase 4.1 — documentation gap closure)
**Role:** Author of `<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md` — target deployment topology,
environment matrix, release-pipeline plan (reference for M-17..M-22, I-41, DASH/PORT),
backup/rollback strategy, and the placeholder registry. Deployment URLs are skipped by
directive — placeholders everywhere.

---

## What was built

1. **`<private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md`** (new; `<private-ops-repo>/` directory created):
   - **§1 Target topology** — 11-component map (Flutter app, self-hosted Supabase, Go CLI,
     planned Go API server `cmd/samay-api-server` (I-41/M-21), React Admin Dashboard +
     Promotor Portal (post-MVP per `samay_web_servers_spec.md`), Samay Venue, Pusher Beams,
     RevenueCat, PostHog, Culqi) with repo status per component. Canonical placeholder
     domain set (`*.samay.example.com`): `app.`, `api.`, `supabase.`, `studio.`, `db.`,
     `dashboard.`, `portal.`, `posthog.`, `privacy.`, `tos.`. Port map (54382/54381/54384/
     54386/54388/54443) and a traffic diagram showing the app → Kong gateway → VPS flow.
   - **§2 Environment matrix** — all 11 `.env.example` keys with dev/staging/prod
     semantics, "ships in app bundle?" flags (5 server-side secrets that must NEVER ship:
     `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ADMIN_USER_ID`, `SYSTEM_ADMIN_USER_ID`,
     `PUSHER_BEAMS_SECRET_KEY`, `REVENUECAT_WEBHOOK_SECRET`), and the dart-define
     migration plan (I-34/M-13, Juega-pattern flags, `--dart-define-from-file` option).
   - **§3 Release pipeline (plan, not implementation)** — versioning scheme (pubspec
     `1.0.0+1`, iOS/Android derive from `FLUTTER_BUILD_NAME/_NUMBER`, git tags `v1.0.0+1`),
     GitHub Actions workflow shapes for M-20 (`ci.yml`), M-21 (`build.yml` + `build-api`),
     M-22 (`release.yml` — placeholders only, no creds), fastlane lane shapes for M-17/M-18
     (iOS: beta_testflight/release_appstore; Android: alpha_firebase/release_play) with the
     **exact placeholder values** M-17..M-19 must adopt (`$IOS_EXPORT_METHOD=app-store`,
     `APP_STORE_CONNECT_API_KEY_ID=AAAAAAAAAA`, `ANDROID_KEYSTORE_PASSWORD=CHANGE_ME`,
     `MATCH_GIT_URL=git@github.com:samay-app/samay-match.git`, etc. — no keystore
     credentials anywhere), and the full store-prep checklist from MVP spec §12 as a
     release gate.
   - **§4 Rollback & backup** — `pg_dump` via 54382 (daily full + hourly WAL + 30-day
     retention + off-server storage, per INFR), volume snapshots (`volumes/db/data`,
     `volumes/storage`), 4-level rollback procedure (app/feature-flag → schema →
     pinned-images → full disaster).
   - **§6 Placeholder registry** — 29 rows (R01..R29) mapping every URL/key/credential
     that must be replaced before real deployment, each with the owning agent
     (I-34/M-13, M-01..M-05, M-13, M-16, M-17/M-18, M-20/M-21/M-22, I-41, I-53/I-61/I-66/I-68,
     RCBH, PLAT, EEDG-future, S-08/S-17 audit hooks).
   - **§7 Verification ledger** — every claim cross-checked against the working tree.

## Decisions made and why

- **Canonical subdomain set defined by D-10** — README (D-05) used `https://samay-api.example.com`
  as an illustrative example; this doc defines the authoritative set (`api.`, `supabase.`,
  `app.`, …) and records the README divergence in §0 so V-09/V-04 can reconcile.
- **One gateway URL for the app** — the app's `SUPABASE_URL` must be the Kong HTTPS URL
  (`https://supabase.samay.example.com`, host port 54443), not the Go API server URL;
  the Go server is a separate tier for admin/promotor/venue routes (web-servers spec §4).
- **`db.samay.example.com` is SSH-only maintenance** — direct Postgres (54382) is never
  exposed publicly; backups/migrations happen over SSH. CLI/API keep using PostgREST
  via Kong, matching `internal/db/client.go` today.
- **Placeholder contract for M-17..M-22** — exact placeholder strings specified
  (§3.3/§6 R20–R25) so fastlane/CI agents copy the same tokens; no invented credentials.
- **Store-prep checklist reproduced verbatim** from MVP §12 (mapped to owners) so the
  release gate is single-source.

## MISTAKEs / gotchas

- **MISTAKE (avoided):** first draft had the app pointing at `https://api.samay.example.com`
  for its Supabase traffic — corrected: mobile app talks to Kong (`supabase.` subdomain),
  `api.` is only the Go/Gin tier (web-servers spec §Deployment diagram).
- **Gotcha:** `<private-ops-repo>/` didn't exist; created it. D-08 is writing `SELFHOSTING.md`
  in the same directory in parallel — lock protocol confirmed no conflict (different files).
- **Gotcha:** pubspec version `1.0.0+1` vs CLI `Version: "1.2.0"` (`cmd/samay-admin/root.go:29`)
  — documented as intentionally independent (semver for each artifact).
- **Gotcha:** Android release build currently signs with **debug keys**
  (`android/app/build.gradle.kts` "TODO: Add your own signing config") — recorded as the
  reason M-18/M-27 keystore placeholders must be wired before any real Play release.

## Commands run (reproducibility)

```bash
git log --oneline -8 && git status --short | head -30
rg -o '^[A-Z_]*=' .env.example                 # 11 keys verified
grep '^version' pubspec.yaml                   # 1.0.0+1
grep -o 'PRODUCT_BUNDLE_IDENTIFIER = [^;]*' ios/Runner.xcodeproj/project.pbxproj | sort -u
grep -o 'DEVELOPMENT_TEAM = [^;]*' ios/Runner.xcodeproj/project.pbxproj | sort -u | head -3
ls .github fastlane Gemfile                    # all absent → M-17..M-22 create them
ls <private-ops-repo>                                  # absent → created
tools/agent_lock.sh list                       # D-08 holds SELFHOSTING.md locks; no overlap
tools/agent_lock.sh acquire <private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md --owner D-10
tools/agent_lock.sh acquire docs/history/phase-00-foundation/2026-08-09_D10-deployment-placeholder.md --owner D-10
# (wrote both files)
tools/agent_lock.sh list                       # D-10 holds exactly its 2 files
tools/agent_lock.sh release <private-ops-repo>/DEPLOYMENT-PLACEHOLDER.md --owner D-10
tools/agent_lock.sh release docs/history/phase-00-foundation/2026-08-09_D10-deployment-placeholder.md --owner D-10
```

## Verification

- [x] Every `.env.example` key (11) appears in the environment matrix and registry.
- [x] Every Makefile target referenced (build/dev/install/build-cli/build-linux, supabase-*) exists in `Makefile` (verified by full read).
- [x] Ports match AGENTS.md (54382/54381/54384/54386/54388/54443); Juega ports never used.
- [x] Spec sections cross-checked: `samay_web_servers_spec.md` §Deployment, `samay_admin_cli_spec.md` §Build & Distribution, `samay_mvp_spec.md` §10/§12, INFR, DEPL, PUSH, APIS, BLD1, PLAT.
- [x] No real URLs, no secrets, no keystore credentials — placeholders only.
- [x] No commits; no Juega files touched; working tree only.
- [x] Lock evidence: acquire + release on both files (see Commands run; `list` output captured while held).

## Issues found (reported, NOT fixed — out of scope)

1. **`.env.example:4-5` contains real dev values** (domain + anon key) — H-21/SEC-03,
   owned by I-34/M-13; registry row R12 says "rotate first".
2. **`supabase/docker-compose.yml`/`supabase-testing/docker-compose.yml` still map
   5432/54321** (Juega conflicts) — I-02/M-01..M-10. Deployment doc assumes the remapped
   target state; must not be started until then.
3. **`android/app/build.gradle.kts` release build signs with debug keys** — M-27/M-18
   must wire the placeholder keystore path before any Play release.
4. **`cmd/samay-api-server/` absent** — APIS/I-41; `build-api` Makefile target missing
   (BLD1) — M-21 adds it.
5. **README.md example URL `samay-api.example.com`** diverges from this doc's canonical
   subdomain set — reconciliation belongs to V-09/V-04 (docs verification phase).
6. **`supabase-testing/migrations/` missing `20260724000002`** (parity gap, known) —
   M-10/I-02; affects any pgTAP gate in CI (M-20 note).
