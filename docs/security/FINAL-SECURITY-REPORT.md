# Samay — Final Consolidated Security Report (S-20)

**Agent:** S-20 (Phase 4.5 — Security) · **Date:** 2026-08-11 · **Branch:** `fixes`
**Scope:** consolidates S-01..S-19 + the Step-0 security fixes. Companion
docs: `MASVS-AUDIT.md`, `CVE-SCAN.md` (S-01/S-02), the per-agent daily logs
(`docs/history/phase-00-foundation/2026-08-11_S0X-*.md`), SECURITY.md.

---

## 0. Headline

The Step-0 verification gate surfaced and **closed one CRITICAL and two HIGH
live vulnerabilities**, plus two pre-existing functional/security RLS bugs.
The 4.5 audit series then re-verified every surface; no new open criticals.

## 1. Fixed in this campaign (with verification)

| # | Severity | Issue | Fix | Verified by |
|---|---|---|---|---|
| F1 | CRITICAL | Image default privileges granted **anon EXECUTE on all 17 SECURITY DEFINER functions** (shard minting, PII hard-delete cron, E2EE prekey-bundle exfiltration, QR validation, minigame sessions) — every prior `REVOKE FROM PUBLIC` was defeated by the defaults | `20260811000001`: default-privilege revoke + per-function REVOKE/GRANT (admin→service_role, client→authenticated, triggers→none) | `anon_exec=f` on 15/17 (2 intended); opt-001 H; pgTAP §48 |
| F2 | HIGH | `donate_shards_to_group` NULL-unsafe guard (`auth.uid() != p_user_id` passes for anon sessions) + SECURITY DEFINER → anon could drain any user's shards | `auth.uid() IS NULL OR ...` guard + `search_path=''` | pgTAP throws_ok; live denial |
| F3 | HIGH | `groups_read_member`/`groups_update_promotor` RLS policies dead since the original schema (unqualified `id` = `group_members.id`) — members couldn't read groups, promotors couldn't update them | explicit `groups.id` correlation | live promotor UPDATE; opt-001 E/I3 |
| F4 | HIGH | groups/events server-managed columns (group_shards, rank_bracket, featured…) writable by clients (table grants defeat G-03 column REVOKEs) | `assert_safe_group_update`/`assert_safe_event_update` triggers (users trigger existed) | opt-001 I; pgTAP 39g |
| F5 | HIGH | Refresh-token rotation not wired in the compose stack (stolen refresh tokens replayable indefinitely) | `GOTRUE_SECURITY_REFRESH_TOKEN_ROTATION_ENABLED=true` + reuse interval + token rate limits (both stacks) | live replay → 400 |
| F6 | MEDIUM | Password minimum 6 (below NIST 800-63B) in the running stack + client | `GOTRUE_PASSWORD_MIN_LENGTH: 8` + config.toml + client policy/ARB/tests | live 6-char → 422 |

## 2. Open findings (ranked) — post-4.5 handoffs

| # | Severity | Finding | Owner / when |
|---|---|---|---|
| O1 | MEDIUM | Kong has **no rate-limit plugin**; `security.*` app_config thresholds unenforced (FLMT blocked on EEDG) | S-10 / EEDG chain (FLMT) |
| O2 | MEDIUM | API server admin gate is a static-key placeholder — real JWT/JWKS + `admin_users` before any deployment | S-06/M-21 |
| O3 | MEDIUM | `functions-v1` Kong route unauth'd + `VERIFY_JWT` default false (no functions yet — flip when EEDG ships) | EEDG |
| O4 | MEDIUM | Event-cover serving broken: `uploadEventCover` returns a public URL on the private events bucket | ✅ **closed 2026-08-13** — `MediaService.uploadEventCover` uploads to the public `groups` bucket (`media_service.dart:45-57`, S-09/M-08 handoff); covers servable for the event's lifetime |
| O5 | MEDIUM | No certificate pinning / no Android network-security-config | S-05/S-18, pre-prod domain |
| O6 | MEDIUM | No screenshot protection / OS-integrity checks (E2EE surfaces) | S-18, pre-wide-E2EE |
| O7 | LOW | quic-go GO-2026-5676 reachable (fixed v0.59.1) — `go get github.com/quic-go/quic-go@v0.59.1` | S-02 / next dep pass |
| O8 | LOW | No server-side length CHECKs on user text columns (client sanitizer only) | S-13 / S-03 follow-up |
| O9 | LOW | Image-default TABLE grants (`arwdDxtm`) remain — triggers+RLS are the enforcement; column-grant model cleanup | S-03 follow-up, pre-Alpha |
| O10 | LOW | pgTAP harness functions live in `public` (anon-callable, inert) — move to a private schema | S-03 / CI infra |
| O11 | LOW | No data-export feature (store-review risk); H-21 historical anon key rotation (ops); DB_ENC_KEY/JWT_SECRET prod rotation | S-14 / release checklist |
| O12 | INFO | `govulncheck` CI job recommended; Gemfile.lock to commit at first fastlane run | S-15 — premise changed 2026-08-13: **`.github/workflows/*` removed by product decision (a0814c7)**; re-add govulncheck when CI is reintroduced. Gemfile.lock **committed** (M-19) |

## 3. What held up under audit (no action needed)

- **MASVS v2.0:** STORAGE (secure storage + backups + E2EE keys) ✅ ·
  CRYPTO (approved algorithms, CSPRNG, domain-separated HKDF) ✅ · AUTH
  (PKCE, rotation, secure persistence) ✅ · NETWORK (TLS defaults) ✅ ·
  PLATFORM (minimal permissions, no WebView) ✅ · DATA (consent, deletion) ✅
  · CODE (injection-free queries, RLS primary layer, fail-closed errors) ✅.
- **CVE scan:** Dart 194 pkgs clean per OSV; Go: 1 reachable (O7) + 24
  non-reachable; images pinned (layer scan deferred — registry unreachable,
  S-16 has the exact re-run commands).
- **E2EE crypto:** implementation matches E2EE-ARCHITECTURE.md
  (X3DH/Double Ratchet/envelope/key lifecycle); **125** tests green (was 116 at report time).
- **Live attack probes:** OTP enumeration, signup flood, refresh replay,
  cross-user RPC, mass-assignment, anon matrix — all held (S-19).
- **Gate matrix:** pgTAP 321/321 · opt-tests 8/8 (001: 40/40, 006: 16/16) ·
  `flutter test` 2032/2032 · `dart analyze` 0 · `go test ./...` green ·
  `make check` PASS (secrets + ports STRICT).

## 4. Release checklist additions (from this series)

1. Rotate H-21 historical anon key; provision real JWT_SECRET + DB_ENC_KEY +
   SMTP before any non-local deployment.
2. Flip `VERIFY_JWT` default + Kong auth on `/functions/v1` when EEDG ships.
3. Real API-server auth (JWT/JWKS + admin_users) before `deploy-api`.
4. Quic-go bump; add govulncheck when CI is reintroduced.
5. Apply the Kong rate-limit plugin with the `security.*` thresholds.
6. ~~Address O4 (event-cover serving)~~ — **closed 2026-08-13** (groups bucket).

---

*Samay Final Security Report — S-20 · 2026-08-11 · refreshed 2026-08-13 · gate: STRONG (no open
critical/high in the shipped surface; 11 tracked follow-ups, 5 release-gated)*
