# 2026-08-11 — S-06: Edge / SSRF / API-surface audit (report)

**Agent:** S-06 (Phase 4.5 — Security) · **Mode:** report-only
**Scope:** Kong gateway routes, edge runtime, `cmd/samay-api-server`, imgproxy,
outbound-fetch surface.

## Verified posture

| Surface | Verdict | Evidence |
|---|---|---|
| Kong `rest-v1` | ✅ | key-auth (apikey) + ACL allow [anon, authenticated, service_role] |
| Kong `rest-admin` | ✅ | key-auth + ACL service_role-only (PostgREST admin server) |
| Kong `meta-v1` (pg-meta — full DB introspection) | ✅ | key-auth + ACL service_role-only |
| Kong `auth-v1` / `storage-v1` / realtime | ✅ | key-auth + ACL per consumer (verified in the M-03/M-09 pass) |
| imgproxy | ✅ no SSRF | `IMGPROXY_LOCAL_FILESYSTEM_ROOT: /` + storage bind — no `IMGPROXY_SOURCE_URL`/remote fetch configured |
| Edge runtime | ⚠️ see finding 1 | boot stub only, no business functions yet |
| API server (`cmd/samay-api-server`) | ⚠️ see finding 2 | Gin; admin gate = static key placeholder |

## Findings

1. **`functions-v1` Kong route has NO auth plugin and
   `VERIFY_JWT: ${FUNCTIONS_VERIFY_JWT:-false}`** (compose `functions` env).
   No business functions exist (EEDG blocked), so there is no live exploit —
   but the default leaves every future edge function anon-open unless the
   author remembers to set `FUNCTIONS_VERIFY_JWT=true`. **Fix (recommended
   when EEDG ships):** flip the default to `true`, add key-auth + ACL to the
   kong `functions-v1` route, and document the per-function JWT policy.
2. **`requireAdmin` in `cmd/samay-api-server` is a static-key constant-time
   compare** (`ADMIN_API_KEY` env). Fail-closed when unset ✓; request
   logging is PII-free ✓; panic recovery generic ✓. **Required before any
   deployment:** real JWT/JWKS verification of `service_role` tokens +
   `admin_users` role resolution (the code comment names this exact handoff —
   S-06/M-21 scope).
3. No outbound-fetch surface: the app/CLI/api-server make no user-controlled
   HTTP fetches; edge runtime has no functions; imgproxy is filesystem-local.
   SSRF exposure: **none today**.

## Verifier cross-check

kong.yml route/plugin/ACL matrix re-read (all routes enumerated) ·
compose env grep (`VERIFY_JWT`, `IMGPROXY_*`) · api-server routes + tests
green (`go test ./...`).

*Samay API-surface audit — S-06 · 2026-08-11*
