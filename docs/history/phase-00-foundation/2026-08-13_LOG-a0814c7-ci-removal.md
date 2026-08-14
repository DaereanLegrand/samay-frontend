# GitHub Actions Removal — No CI Workflows (2026-08-13, `a0814c7`)

**Agent:** R2-log-backfill (docs-remediation sweep) · **Branch:** `fixes` · **HEAD:** `a0814c7`

## What was built

`.github/workflows/` deleted by product decision (2026-08-14): the project runs
**no GitHub Actions**. 13 files, +50/−1031:

1. **4 workflow files removed (~1003 lines):** `ci.yml` (174), `build.yml`
   (253), `release.yml` (305), `README.md` (271).
2. **p12 cert dropped:** `AltServerData/Certificates/L9XRRUD8W7.p12`
   (3098 bytes) — AltServer path already removed 2026-08-12 (R28).
3. **DEPLOYMENT-PLACEHOLDER.md:** §3/§3.1/§3.2 get a REMOVED banner, §3.3/R25/
   §7 addendum — CI-equivalent gates are local: `make check` /
   `make test-all` / `supabase-db-test` / `supabase-backend-tests`; store
   releases via **fastlane**.
4. **to-fix categories:** `09-CODE-GENERATION-TOOLING` (TOOL-02 closed by
   decision) and `14-MAKEFILE-CICD` (MKE-07) updated; to-fix README delta
   tables refreshed.
5. **FILE-OWNERSHIP + AGENT-REGISTRY** (now `docs/process/`): M-20/M-21/M-22
   rows marked **historical** (the `build-api` Makefile target remains).
6. **phase-15 DEPL spec + PLAN:** fastlane-only store pipelines.

## Decisions

- No GitHub Actions, ever — **do NOT recreate `.github/workflows/`** (commit
  message directive). Quality gates are local (`make`/opt-tests/pgTAP), release
  pipelines are fastlane.
- The `build-api` Makefile target stays; only the CI wiring around it is
  historical.

## Commands run

```bash
git rm .github/workflows/ AltServerData/Certificates/L9XRRUD8W7.p12
git show a0814c7 --stat            # 13 files, +50/−1031
```

## Follow-ups

- Watch for docs that still reference `.github/workflows/` paths (sweep done at
  commit time; re-check after future doc edits).
- Fastlane lane stubs remain `bundle exec` surface pinned by opt-008.
