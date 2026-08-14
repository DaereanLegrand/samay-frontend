# 2026-08-11 — S-15: Supply-chain security audit (report)

**Agent:** S-15 (Phase 4.5 — Security) · **Mode:** report-only
**Scope:** lockfile hygiene, toolchain pinning, CI gates, image pinning,
reproducibility.

## Verified posture

| Check | Verdict | Evidence |
|---|---|---|
| Dart lockfile | ✅ committed | `pubspec.lock` (194 packages, deterministic builds) |
| Go lockfile | ✅ committed | `go.sum` + `go.mod` |
| Ruby/Gemfile lock | ⚠️ missing | `Gemfile.lock` absent — M-19 planned "commit at first `bundle install`"; fastlane hasn't run yet. Lock before the first CI/real fastlane run |
| Toolchain pinning | ✅ | CI pins Flutter + Go 1.26.5 (setup-go@v7); go.mod `go 1.26.2` is a minimum (documented in ci.yml) |
| Container images | ✅ pinned | 10 services + 2 overrides pin exact tags (supabase/postgres 17.6.1.136, Kong 3.9.3, GoTrue v2.189.0, PostgREST v14.12, realtime v2.102.3, storage-api v1.60.4, imgproxy v3.30.1, meta v0.96.6, edge-runtime v1.74.0, MinIO RELEASE.2025-09-07) — enforced by opt-007 |
| Pre-commit gates | ✅ | `core.hooksPath → tools/hooks` — analyze + test smoke + secrets + ports + opt-008 on every commit |
| CI dependency scan | ⚠️ | `ci.yml` runs analyze/test/secrets/ports; **no `govulncheck`/`osv-scanner` job yet** — add one (the S-02 scan is the first evidence) |
| Build reproducibility | ⚠️ | No SBOM produced; the CLI cross-build (make build-linux) is the only artifact pipeline today |

## Findings

1. **Add `govulncheck` (+ optional osv-scanner for Dart) to CI** — the S-02
   scan found 1 reachable advisory (quic-go, fixed v0.59.1); CI should catch
   the next one. Recommended job: `go run
   golang.org/x/vuln/cmd/govulncheck@latest ./...` on the Go track.
2. Commit `Gemfile.lock` at the first fastlane run (M-19 handoff).
3. Optional: SBOM (syft) + signed release artifacts when the release pipeline
   becomes real (M-22 is placeholder-only today).

## Verifier cross-check

Lockfiles/`core.hooksPath`/CI pins verified · image tags cross-checked with
opt-007's pin asserts (green).

*Samay supply-chain audit — S-15 · 2026-08-11*
