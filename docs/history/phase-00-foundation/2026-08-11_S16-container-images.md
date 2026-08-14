# 2026-08-11 — S-16: Container image CVE assessment (report)

**Agent:** S-16 (Phase 4.5 — Security) · **Mode:** report-only
**Method:** pinned-tag inventory + known-CVE cross-check + scan-tool
readiness. **Note:** a layer-level scan (Trivy/anchore) requires pulling the
images — Docker Hub was unreachable during this batch (verified: even
`hello-world` pulls stall). The scan runs when the registry is reachable;
this report pins the exact tags so the scan is reproducible.

## Pinned inventory (both stacks, verified in compose)

| Service | Tag | Service | Tag |
|---|---|---|---|
| postgres | `supabase/postgres:17.6.1.136` | storage-api | `supabase/storage-api:v1.60.4` |
| kong | `kong/kong:3.9.3` | imgproxy | `darthsim/imgproxy:v3.30.1` |
| gotrue (auth) | `supabase/gotrue:v2.189.0` | postgres-meta | `supabase/postgres-meta:v0.96.6` |
| postgrest | `postgrest/postgrest:v14.12` | studio | `supabase/studio:2026.08.03-sha-022b374` |
| realtime | `supabase/realtime:v2.102.3` | edge-runtime | `supabase/edge-runtime:v1.74.0` |
| minio | `minio/minio:RELEASE.2025-09-07T16-13-09Z` | mc | `minio/mc:RELEASE.2025-08-13T08-35-41Z` |

## Findings

1. **Full layer scan DEFERRED (registry unreachable).** Exact commands for
   the scan (run when connectivity returns):
   ```bash
   docker pull supabase/postgres:17.6.1.136 && trivy image supabase/postgres:17.6.1.136
   # repeat per tag; aggregate → docs/security/CVE-SCAN.md update
   ```
   Pin drift is already gated (opt-007 asserts the exact tags).
2. All tags are current-generation Supabase/Kong/MinIO releases (mid-2025..
   2026-08); the distro-level CVE surface is the standard Alpine/Debian
   baseline — the weekly watchlist (SECURITY.md §5.1) covers the project
   maintainers' advisories.
3. **MinIO/mc pin format** (RELEASE.2025-*) is the MinIO canonical pin —
   updates are frequent; the S-20 report will carry the update cadence.

## Verifier cross-check

Tag inventory re-grepped from compose (both stacks identical after token
normalization) · opt-007 pin asserts green.

*Samay container CVE assessment — S-16 · 2026-08-11 (layer scan deferred:
registry unreachable)*
