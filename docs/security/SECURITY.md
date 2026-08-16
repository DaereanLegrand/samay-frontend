# Samay — Security Architecture & Threat Model

**Owner:** D-06 (security architecture doc) · **Reviewed:** 2026-08-13 · **Status:** living document — update at every security change (RLS hardening, E2EE rollout, release checklist)

> Companion docs: `docs/security/E2EE-ARCHITECTURE.md` (D-07, planned — X3DH + Double Ratchet spec), `docs/security/MASVS-AUDIT.md` (S-01), `docs/security/CVE-SCAN.md` (S-02), `docs/security/FINAL-SECURITY-REPORT.md` (S-20), `docs/to-fix/categories/08-SECURITY.md` and `06-SUPABASE-BACKEND.md` (findings), `docs/specs/steps/phase-00-foundation/SECU-rls-policies.md` (RLS design).

---

## 0. Sources & References

Industry standards this document is aligned with (all claims below cite these):

| # | Source | URL |
|---|--------|-----|
| R1 | OWASP MASVS v2 (Mobile Application Security Verification Standard) | https://mas.owasp.org/MASVS/ |
| R2 | OWASP MASTG (Mobile App Security Testing Guide) — crypto, storage, network, auth chapters | https://mas.owasp.org/MASTG/0x04e-Testing-Authentication-and-Session-Management/, https://mas.owasp.org/MASTG/0x04f-Testing-Network-Communication/, https://mas.owasp.org/MASTG/0x04g-Testing-Cryptography/, https://mas.owasp.org/MASTG/0x05d-Testing-Data-Storage/ |
| R3 | OWASP API Security Top 10 — 2023 | https://owasp.org/API-Security/editions/2023/en/0x11-t10/ |
| R4 | Signal — X3DH Key Agreement Protocol (rev 1, 2016) | https://signal.org/docs/specifications/x3dh/ |
| R5 | Signal — Double Ratchet Algorithm (rev 4, 2025) | https://signal.org/docs/specifications/doubleratchet/ |
| R6 | Supabase — Row Level Security guide (publishable-key safety, `auth.uid()`, roles, policy patterns) | https://supabase.com/docs/guides/database/postgres/row-level-security |
| R7 | Supabase — Securing your data (service_role never client-side) | https://supabase.com/docs/guides/database/secure-data |
| R8 | PostgreSQL — 5.9 Row Security Policies (`FORCE ROW LEVEL SECURITY` semantics, table-owner bypass) | https://www.postgresql.org/docs/current/ddl-rowsecurity.html |
| R9 | PostgreSQL — CREATE FUNCTION (`SECURITY DEFINER` + `SET search_path` guidance) | https://www.postgresql.org/docs/current/sql-createfunction.html |
| R10 | NIST SP 800-63B — Digital Identity Guidelines: Authentication & Lifecycle Mgmt (OTP verifier, session mgmt) | https://pages.nist.gov/800-63-3/sp800-63b.html |
| R11 | NIST SP 800-124 Rev 2 — Guidelines for Managing the Security of Mobile Devices | https://csrc.nist.gov/pubs/sp/800/124/r2/final |
| R12 | NVD (National Vulnerability Database) | https://nvd.nist.gov/ |
| R13 | OSV — Open Source Vulnerability Database | https://osv.dev/ |
| R14 | Dart / pub.dev security advisories | https://dart.dev/tools/pub/security-advisories |
| R15 | GitHub Security Advisories | https://github.com/advisories |
| R16 | Go vulnerability database | https://vuln.go.dev/ |

---

## 1. Threat Model

### 1.1 Assets (what we protect)

| Asset | Where it lives | Sensitivity | Notes |
|-------|---------------|-------------|-------|
| A1 — User identity | `auth.users` (GoTrue), `public.users`, `signup_tracker` | High | email, date_of_birth (PII), username (permanent) |
| A2 — E2EE chat keys | Device only (`lib/crypto/`, I-37/I-38/81722ef) | Critical | X25519 identity + ratchet keys; **never on server**; ciphertext-only server (R4/R5) |
| A3 — Shard balances | `users.personal_shards`, `users.preshards`, `shard_ledger`, `preshard_ledger`, `groups.group_shards` | Critical | economy integrity = app integrity; double-spend = top risk |
| A4 — PII & UGC | `users` (bio, DoB), `messages`, `event_photos`, `event_qr_tokens`, `notifications` | High | photos in Storage; chat ciphertext (E2EE, I-37/81722ef) |
| A5 — Session tokens | Client (in-memory / platform secure storage), GoTrue refresh tokens | Critical | access JWT (1 h) + refresh token; rotation enabled |
| A6 — Admin credentials | `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ADMIN_USER_ID` (env) | Critical | bypasses RLS (R7); CLI-only, never in app |
| A7 — RevenueCat/Pusher/PostHog secrets | `.env` / env (unused at MVP) | High | webhook signature + idempotency required (FLMT spec) |
| A8 — Audit trail | `admin_audit_log` | Medium | non-repudiation of admin actions |

### 1.2 Actors

| Actor | Capabilities | Trust |
|-------|-------------|-------|
| Anonymous (`anon` role) | Reads public catalog (app_config, cosmetics, leaderboard), public events, `user_search_view`; calls `check_signup_email` RPC; sends OTP | Untrusted — RLS + GoTrue rate limits only |
| Authenticated user | Full client surface via PostgREST/Realtime with own JWT | Semi-trusted — scoped by RLS policies |
| Malicious authenticated user | Attempts: cross-user reads (RLS blocks), own-row mass assignment, OTP abuse, search enumeration, QR replay, shard manipulation | Primary adversary |
| Compromised backend role | service_role / table owner / `postgres` credentials theft (CLI machine, leaked `.env`) | **Defense:** FORCE RLS on all 34 RLS-enabled tables closes the table-owner bypass (I-31 → 20260809000001; K1 → 20260817000005) |
| Network attacker | Passive TLS interception / MITM, Realtime WS sniffing | Mitigated by HTTPS (Kong 54443); no cert pinning yet |
| Insider admin | Full service_role access via CLI; audit-logged | Mitigated by `admin_audit_log` (A8) + least-privilege roles |

### 1.3 STRIDE table (mapped to Samay components)

| Threat | Samay component exposed | Current status | Primary mitigation | Owner |
|--------|------------------------|----------------|-------------------|-------|
| **S — Spoofing identity** | Auth (OTP), JWT handling, session persistence | ✅ PKCE pinned on init (`lib/main.dart:118`); `refreshSession()` wired through `AuthService` + `tokenRefreshed` handler (auth_provider.dart); session + PKCE verifier persisted in flutter_secure_storage (`SecureSessionStorage`/`SecurePkceStorage`, M-33); GoTrue `enable_refresh_token_rotation` (config.toml:58) | I-30, I-25 ✅ |
| **T — Tampering (data)** | PostgREST writes; RLS policies; triggers | ✅ `users_update_own` mass-assignment closed (G-03): `20260809000002` `REVOKE UPDATE` on the 7 economy/subscription columns + `assert_safe_user_update()` BEFORE trigger (SECURITY INVOKER, one-way `deleted_at` preserved) | I-32 ✅ |
| **T — Tampering (privileged)** | SECURITY DEFINER functions | ✅ all SECURITY DEFINER functions carry `SET search_path = ''` (I-31 hardening migration `20260809000001` redefined all 12; every later SD function follows — evidence §2.2) | I-31 ✅ |
| **R — Repudiation** | Admin operations | ✅ `admin_audit_log` row per CLI mutation (internal/ops/audit.go; policy denies client access full_schema.sql) | S-17 |
| **I — Information disclosure** | `user_search_view` (security barrier, id/username/avatar_url only — 20260520000001:217-222); `users` read-own (full_schema.sql); messages/events/group policies | ✅ scoped; `.env.example` anon key rotated to placeholder (I-34/H-21) | I-34 ✅ |
| **I — Information disclosure (E2EE)** | Chat `messages.content` | ✅ ciphertext in Postgres — X3DH + Double Ratchet landed (I-37/81722ef: replay protection, session convergence, SPK expiry); keys client-only → E2EE-ARCHITECTURE.md | I-37, I-38 ✅ |
| **D — Denial of service** | OTP sending (GoTrue `email_sent = 2` config.toml:65); search `.ilike` prefix enumeration; RPC `donate_shards_to_group` (no rate limit); Realtime channels; photo upload 50 MiB (config.toml:42) | ⚠️ auth-level limits exist + client OTP cooldown/attempt caps (I-29); no Kong rate-limit plugin, no server-side RPC limiting (FLMT blocked on Edge Functions — EEDG ❌) | I-29 ✅, S-10, M-09 |
| **E — Elevation of privilege** | RLS bypass: table owner bypasses RLS without FORCE (R8) | ✅ FORCE RLS on all 34 RLS-enabled tables (`20260809000001` ×31 + `20260724000001` + `20260809000003` e2ee_identity_keys + `20260817000005` deleted_messages) | I-31 ✅ |

---

## 2. Security Architecture

### 2.1 RLS strategy + FORCE RLS

**Design (from `docs/specs/steps/phase-00-foundation/SECU-rls-policies.md`):** RLS is the *primary* security layer (spec §4). Every table in the exposed `public` schema carries `ENABLE ROW LEVEL SECURITY`; the `authenticated` role is gated per-table; `service_role` is the privileged path for CLI/Edge Functions; admin tables (`admin_users`, `admin_audit_log`, `subscription_overrides`, `processed_webhooks`) are `FOR ALL USING (false)` (defense-in-depth, full_schema.sql:783-787).

**Verified current status (evidence):**

| Claim | Evidence | Status |
|-------|----------|--------|
| RLS enabled on all 34 base + post-gate tables | `supabase/migrations/20260510000001_full_schema.sql:578-607` (30× `ENABLE ROW LEVEL SECURITY`) + `20260513000002` (signup_tracker) + `20260810000007` (storage-era) + `20260809000003` (e2ee_identity_keys) + `20260817000005` (deleted_messages) | ✅ 34 |
| RLS enabled on `signup_tracker` | `supabase/migrations/20260513000002_fix_signup_tracker.sql:13` | ✅ |
| **FORCE RLS on every RLS-enabled table** | `20260809000001_harden_rls_search_path.sql:39-69` (31× `ALTER TABLE ... FORCE ROW LEVEL SECURITY`) + `20260724000001_fix_signup_tracker_rls.sql:73` + `20260809000003_e2ee_tables.sql:62` + `20260817000005_deleted_messages_rls.sql:30-31` → **34 FORCE statements** (was 1/31 pre-I-31; +1 K1 2026-08-16) | ✅ 34/34 |
| signup_tracker policies email-scoped (own-email only) | `20260724000001_fix_signup_tracker_rls.sql:57-68` (`email = auth.jwt() ->> 'email'`) — replaces the original wide-open `USING (true)` policies (`20260513000002:15-30`) | ✅ (C-01, commit b02090e) |
| Pre-auth email check via hardened RPC | `check_signup_email` — `SECURITY DEFINER`, `SET search_path = ''`, explicit `REVOKE/GRANT` (`20260724000001:15-44`) | ✅ pattern reference |
| RLS recursion bugs fixed post-hoc | `20260512000006_fix_group_members_rls_recursion.sql`, `20260512000008_fix_events_rls_recursion.sql` (42P17) | ✅ history |
| `user_search_view` exposes only id/username/avatar_url | `20260520000001_admin_rpc_and_rls.sql:217-222` (`security_barrier` view, `deleted_at IS NULL`) | ✅ |
| `donate_shards_to_group` RPC requires auth + own-user check | `20260724000002_fix_donate_shards_rpc.sql:17-19` (`auth.uid() != p_user_id` → exception), `:36-37` (`REVOKE ... FROM PUBLIC; GRANT ... TO authenticated`) | ✅ |
| RLS verified by integration tests | `test/opt-001-rls-security.sh` — anon/auth/service role matrix (A–H sections) | ✅ (run via `test/run_all_backend.sh`) |
| pgTAP asserts email-scoped signup_tracker policies + FORCE | `supabase/tests/schema_test.sql` Sections 6/15/37 (both stacks, byte-identical) — no "Anyone can …" assertions remain (G-17) | ✅ |

**Post-gate hardening (2026-08-11..14):**
- `20260811000001_harden_function_execute_rls.sql` — anon EXECUTE revoked on 17 functions (F-1, MASVS §F1); adds `assert_safe_group_update`/`assert_safe_event_update` triggers.
- `20260814000001_chat_direct_rls.sql` — direct-chat membership RLS (CHPT); `20260814000002_user_views_block_exclusion.sql` — blocked users excluded from search/profile views (S-03).
- `20260814000003_rank_recalc_decay_cron.sql` — rank recalc + decay cron honoring `ranks.update_cron`; `20260814000004_qr_token_rotate_rpc.sql` — QR rotation RPC with `pg_advisory_xact_lock`.
- `20260814000005_notification_triggers.sql` — 8 `notify_*` SECURITY DEFINER triggers (NTRG subset). All new SD functions carry `SET search_path = ''`.

### 2.2 SECURITY DEFINER search_path hardening (I-31)

Postgres executes `SECURITY DEFINER` functions with the *creator's* privileges, so an attacker-controllable `search_path` can hijack unqualified object references → arbitrary SQL with elevated rights (R9). Fix: `SET search_path = ''` + fully-qualified `public.` references.

**Verified inventory — all SECURITY DEFINER functions hardened (I-31 done 2026-08-09; zero unhardened remain):**

The 12 original functions were redefined by `20260809000001_harden_rls_search_path.sql:85-427` with `SET search_path = ''` + fully-qualified `public.` references; every post-gate SD function carries the same hardening:

| Function | Migration : line | search_path |
|----------|------------------|-------------|
| `update_group_size_tier` | 20260510000001_full_schema.sql:469 (redefined 20260809000001) | ✅ `''` |
| `set_dynamic_qr_enabled` | 20260510000001_full_schema.sql:482 (redefined 20260809000001) | ✅ `''` |
| `enforce_message_cap` | 20260510000001_full_schema.sql:513 (redefined 20260809000001) | ✅ `''` |
| `increment_group_shards` | 20260510000001_full_schema.sql:527 (redefined 20260809000001) | ✅ `''` |
| `update_photo_likes_count` | 20260510000001_full_schema.sql:551 (redefined 20260809000001) | ✅ `''` |
| `dispatch_shard_distribution` | 20260510000001_full_schema.sql:567 (redefined 20260809000001) | ✅ `''` |
| `hard_delete_expired_users` | 20260510000002_cron.sql:32 (redefined 20260809000001) | ✅ `''` |
| `donate_shards_to_group` | 20260512000001:13 / 20260724000002:14 (redefined 20260809000001) | ✅ `''` |
| `grant_shards` | 20260520000001_admin_rpc_and_rls.sql:15 (redefined 20260809000001) | ✅ `''` |
| `grant_preshards` | 20260520000001_admin_rpc_and_rls.sql:40 (redefined 20260809000001) | ✅ `''` |
| `distribute_shards` | 20260520000001_admin_rpc_and_rls.sql:65 (redefined 20260809000001) | ✅ `''` |
| `recalculate_ranks` | 20260520000001_admin_rpc_and_rls.sql:165 (redefined 20260809000001 + 20260814000003) | ✅ `''` |
| `check_signup_email` | 20260724000001_fix_signup_tracker_rls.sql:19 | ✅ `''` (original pattern) |
| `assert_safe_user_update` | 20260809000002_rls_audit_fixes.sql | ✅ `''` |
| `validate_qr_token` | 20260809000005_qr_validate_rpc.sql | ✅ `''` |
| `submit_minigame_score` | 20260809000006_minigame_rpc.sql | ✅ `''` |
| `create_direct_chat` | 20260814000001_chat_direct_rls.sql | ✅ `''` |
| `rotate_qr_token` | 20260814000004_qr_token_rotate_rpc.sql | ✅ `''` |
| `assert_safe_group/event_update` | 20260811000001_harden_function_execute_rls.sql | ✅ `''` |
| 8× `notify_*` | 20260814000005_notification_triggers.sql | ✅ `''` |
| `handle_signup` (dropped) | 20260513000001:9 had `SET search_path = public` | 🔴 history — dropped by 20260513000002:4 |

### 2.3 Auth: JWT, PKCE, session handling (I-30)

**Verified current status:**

| Claim | Evidence |
|-------|----------|
| JWT expiry 1 h, refresh-token rotation ON, reuse-interval 10 s | `supabase/config.toml:57-59` |
| GoTrue rate limits configured (email_sent=2, token_refresh=150, token_verifications=30, …) | `supabase/config.toml:64-71` |
| OTP: 6 digits, 1 h expiry; email max_frequency 1s | `supabase/config.toml:79-80`, `:78` |
| PKCE pinned on init | `lib/main.dart:118` (`authFlowType: AuthFlowType.pkce`) |
| `refreshSession()` wired | `AuthService.refreshSession()` → `tokenRefreshed` handler in `lib/core/providers/auth_provider.dart` (null-session handling, I-30) |
| Session + PKCE verifier in SecureStorage | `SecureSessionStorage`/`SecurePkceStorage` (flutter_secure_storage, I-25/M-33) |
| `secure_password_change = false`, password min length 8 | `supabase/config.toml:62` (8 ≥ NIST SP 800-63B §5.1.1 minimum) |
| Auth guard redirect logic | `lib/core/router/auth_guard.dart:13-36` (`if (auth.loading) return null;` — SEC-12 loading flash, open M-34) |

**Plan (I-30):** DONE — PKCE, explicit refresh, SecureStorage persistence all landed 2026-08-09 (G-04). Remaining: ban-enforcement server hook when Edge Functions land (AUTH spec §ban).

### 2.4 E2EE chat (I-37/I-38 — spec lives in `docs/security/E2EE-ARCHITECTURE.md`, owned by D-07)

- Protocol: **X3DH** key agreement (R4) + **Double Ratchet** message ratchet (R5) — "as secure as Signal": identity keys and ratchet state client-only, server stores ciphertext only.
- Parameters (per X3DH §2.1): curve **X25519**, hash **SHA-256**, AEAD via AES-256-GCM; per-message keys from HKDF chains; `MAX_SKIP` bounds skipped-key storage (Double Ratchet §3.1, §8.4).
- Prekey management per X3DH §3.2: signed prekey rotation (with server-side `signed_prekey_expires_at`) + one-time prekey replenishment.
- **Landed 2026-08-09..13 (I-37 + 81722ef):** 10 modules in `lib/crypto/` (x3dh, ratchet, session, envelope, prekey store, key store…); replay-protection blacklist; session convergence (≤ 2 inactive sessions bound); failed-init restore; persisted `init-marker`; chat route live (`app_router.dart:414-420` ChatScreen); `messages.content` holds **ciphertext only** (full_schema.sql:251-260). Deviations from the E2EE spec are recorded in E2EE-ARCHITECTURE.md errata.

### 2.5 Storage buckets + signed URLs (S-09)

| Claim | Evidence |
|-------|----------|
| Event photos: private bucket, 1 h signed URLs | `lib/core/services/media_service.dart:116-119` (`createSignedUrl(storagePath, 3600)`); bucket design: SECU-rls-policies.md:51-55; bucket public=false via `20260810000007_storage_buckets.sql` (M-08) |
| Group covers: public bucket + public URL | `lib/features/groups/create_group_screen.dart:77-80` (`uploadBinary` + `getPublicUrl`); `groups` bucket public=true via `20260810000007_storage_buckets.sql` (M-08) |
| Avatars: public bucket + public URL | `lib/core/services/media_service.dart:62-68` (`uploadUserAvatar` → `getPublicUrl`); `avatars` bucket public=true via `20260810000007_storage_buckets.sql` (M-08) |
| No image size/resizing on upload (full-res files) | `lib/core/services/media_service.dart` + `lib/core/utils/image_processor.dart` (I-22 image_processor — client-side downscale landed PERF-03/M-36) |
| Storage file-size cap 50 MiB | `supabase/config.toml:42` |
| **Bucket rows + storage.objects RLS policies** ✅ (M-08, 2026-08-10 — closes the I-36/I-59 bucket-creation gap) | `supabase/migrations/20260810000007_storage_buckets.sql` (×2): `avatars`/`groups` public=true, `events` public=false; 5 objects policies: public SELECT avatars/groups, events SELECT gated on `event_photos` visibility (eph_read_access), own-row INSERT/UPDATE/DELETE on `owner_id` = `auth.jwt()->>'sub'` (avatars INSERT also requires the `{user_id}/` path prefix). Column verified against storage-api v1.60.4 tenant migrations: `storage.objects.owner_id` (text, since 0018) — NOT `owner` |
| **Signed-URL/RLS interplay — verified + handoff stays S-09** | v1.60.4 source check (M-08): signing (`signObjectUrl`) runs `findObject` through the caller's RLS session → a SELECT policy matching event access is REQUIRED (this is why `storage_objects_events_select_access` exists); signed-URL retrieval (`getSignedObject`) runs `asSuperUser()` → RLS-independent. ✅ `MediaService.uploadEventCover` now uploads to the **public `groups` bucket** (`media_service.dart:45-57`) — event covers are servable (O4 closed) |

Plan (S-09/I-59): path-prefix ownership (`{user_id}/...`) — done for avatars INSERT, groups/events paths do not embed a user id (own-row `owner_id` check instead); signed URL expiry ≤ 1 h — app uses 1 h (media_service.dart); event-cover serving — **closed** (groups bucket, see above); rate-limit URL generation — open (S-09/S-10).

### 2.6 Input sanitization (I-27 — ✅ DONE 2026-08-09)

**Current:** shared `InputSanitizer` at `lib/core/utils/input_sanitizer.dart` applied at every write boundary: trim → strip Unicode `\p{Cc}\p{Cf}` (control + format incl. zero-width/bidi overrides) → optional NFKC (`unorm_dart` ^0.3.2, Unicode 17.0 — Dart has no built-in normalizer) → grapheme-cluster length cap (`characters`, emoji-safe). Helpers: `sanitizeUsername` (case-preserving, NFKC always on, strips whitespace/`@`, cap 20), `sanitizeAmount` (digits-only, cap 9), `sanitizeOptional` (null-if-empty). Wired at: username (profile_setup_screen + auth_service.createUserProfile), bio (edit_profile_screen, 160), group name/desc (create_group_screen + group_service.createGroup, 50/250), search queries (invite/search screens), donate amount, chat `sendMessage` (500). 29 unit tests (`test/utils/input_sanitizer_test.dart`); idempotent — valid input unchanged. **Remaining:** server-side length caps via DB CHECK constraints (I-31 track); `TextField.maxLength` UX (U-05+).

### 2.7 Rate limiting (Kong + app_config + GoTrue)

| Layer | Status | Evidence |
|-------|--------|----------|
| GoTrue auth rate limits | ✅ configured | config.toml:64-71; docker-compose.yml:86 (`GOTRUE_RATE_LIMIT_EMAIL_SENT: 2`) |
| Kong gateway plugins | ⚠️ key-auth + ACL + CORS only — **no rate-limit plugin** | supabase/volumes/api/kong.yml:22-32 (rest-v1), :34-49 (rest-admin service_role-only) |
| app_config abuse thresholds | ✅ seeded, **not enforced** (FLMT blocked — no Edge Functions) | seed.sql (`security.max_events_per_minute=3`, `max_concurrent_event_invites=50`, `max_qr_token_rotations=20`, `max_failed_qr_validations=5`); docs/specs/steps/phase-00-foundation/FLMT-edge-functions-rate-limiting.md |
| OTP client-side cooldown / attempt caps | ✅ (I-29) | `lib/features/auth/otp_verification_screen.dart:27-33` (60 s cooldown, 5-attempt cap) |
| Search enumeration | ⚠️ `.ilike('username', '$query%')` prefix search, limit 20, authenticated-only view (block-exclusion via `20260814000002`) | media/user repositories |

### 2.8 Secrets management (I-34 / M-13)

| Claim | Evidence | Status |
|-------|----------|--------|
| `.env` bundled as Flutter asset | **No** — `pubspec.yaml` has no `assets:` entry; config injected via `--dart-define-from-file` (Makefile build/dev targets, I-34) | ✅ |
| Env consumed via `String.fromEnvironment` | `lib/core/config/env_config.dart` (dart-define, no `flutter_dotenv` dep) | ✅ |
| `.env.example` uses placeholders only | `.env.example:18` `your_supabase_anon_key_here` (H-21/SEC-03 closed — key rotated) | ✅ |
| Service role / admin IDs via env only, never in app | `internal/db/client.go:21-22`, `cmd/samay-admin/root.go:19, 52-57` | ✅ |
| Compose uses placeholder secrets (no real creds committed) | `supabase/docker-compose.yml` ("your-…-change-in-production") | ✅ (M-01..M-05) |
| Makefile passes `APPLE_PASSWORD` as plaintext var | ~~AltServer sideload path removed 2026-08-12~~; iOS device installs use fastlane `adhoc_local` + `devicectl` (enrolled team from gitignored `.env.local`) | ✅ |
| Dev test script embeds local dev keys | `test/opt-001-rls-security.sh` (local-stack dev keys only — acceptable for dev, must never be prod) | ⚠️ |
| Post-gate migrations carry no secrets | `20260814000001..05` + `20260811000001` — RLS/RPC/trigger only, no keys | ✅ |

Rule: **no secrets in code, tests, or docs — placeholders only** (docs/process/DEVELOPMENT-WORKFLOW.md §4.2). Build-time injection via `--dart-define` (Makefile `build`/`dev` targets, M-11/M-13).

### 2.9 Network transport

- HTTPS in prod via Kong TLS (`54443`, AGENTS.md port map); PostgREST/GoTrue behind Kong (kong.yml). Self-hosted dev is HTTP on localhost only.
- No certificate pinning implemented (S-05 scope); keep OS trust store + enforce TLS 1.2+ (R11).
- Realtime: WebSocket with JWT; channel names embed user/entity ids (`lib/core/providers/realtime_provider.dart` / `realtime_service.dart`) — Realtime row access is governed by table RLS; channel-existence enumeration is a residual risk (S-11).

---

## 3. Cryptography Policy

### 3.1 Approved primitives (align R2 MASTG crypto chapter, R5 §7.2)

| Purpose | Algorithm | Parameters | Notes |
|---------|-----------|-----------|-------|
| E2EE key agreement (chat) | **X25519** (RFC 7748) | 32-byte keys | X3DH curve (R4 §2.1) |
| E2EE prekey signature | **Ed25519** (or XEdDSA per R4) | 64-byte sig | signature over `Encode(SPKB)` (R4 §3.2) |
| E2EE message encryption | **AES-256-GCM** | 256-bit key, 96-bit random nonce, 128-bit tag | AEAD w/ header + AD (R5 §3.1) |
| Key derivation (ratchets + X3DH SK) | **HKDF-SHA256** | RFC 5869; app-specific `info` strings for domain separation (R5 §7.2) | distinct `info` per use |
| Hashing (fingerprints, integrity) | **SHA-256 / SHA-512** | — | NIST-approved (R2) |
| Hive-at-rest encryption (future, I-26) | AES-256 (GCM mode) via Hive cipher | key in flutter_secure_storage | SEC-10/M-32 |
| TLS | TLS 1.2+ (platform defaults) | — | R11 |

### 3.2 NOT allowed

- **MD5 / SHA-1** for integrity, signatures, or fingerprints (R2; broken collisions).
- **ECB mode** (no diffusion), **CBC without a MAC** (padding-oracle), **RC4/DES/3DES**, RSA < 2048 for any signing purpose.
- **Hardcoded keys or secrets** of any kind (MASWE-0013 / R2); keys must be generated at runtime with a **CSPRNG** (never `Random()` — use `Random.secure()` / platform crypto RNG) (MASTG-BEST-0001).
- **Custom crypto / home-brewed protocols** — only standard, reviewed constructions (X3DH/Double Ratchet as specced in E2EE-ARCHITECTURE.md).
- Nonce/IV reuse; fixed nonces in AEAD without a per-key nonce scheme (R5 §3.1).

### 3.3 Key lifecycle (E2EE, per R4/R5)

1. **Generation** — on device at first run/account creation: X25519 identity keypair + signed prekey + one-time prekey batch; ratchet keypairs per session.
2. **Storage** — private keys only in `flutter_secure_storage` (iOS Keychain / Android Keystore, R11); never in Hive, logs, or backups (MASTG-BEST-0004).
3. **Publishing** — identity key once; signed prekey rotated periodically (e.g. weekly, R4 §3.2); one-time prekeys replenished when server store runs low; prekey bundle fetch rate-limited (R4 §4.7).
4. **Rotation** — DH ratchet per message round-trip (R5 §2.3); signed prekey rotation; old chain/message keys deleted (R5 §8.1, §8.4).
5. **Wipe on account delete** — on soft-delete and on hard-delete cron: purge all local key material + ratchet state; server holds no keys (ciphertext only) — wipe = delete server copy of messages.
6. **Audit** — S-07 crypto audit validates the implementation (I-37/I-38 output) before chat ships.

---

## 4. Compliance

### 4.1 Peru — Ley N° 29733 (Ley de Protección de Datos Personales)

Required by MVP spec §2 (privacy policy at signup, right to deletion, data security):

| Requirement | Implementation | Evidence |
|-------------|---------------|----------|
| Privacy Policy + ToS shown and accepted at signup | Privacy & Terms screen with mandatory checkboxes (not pre-checked) | `lib/features/auth/privacy_terms_screen.dart:36-59` |
| Age gate 18+ (block underage) | DoB picker, birth-date cutoff check | `lib/features/auth/age_gate_screen.dart:21-25, 68-85` |
| Right to request deletion of personal data | In-app delete-account flow (email confirm + confirm dialog) | `lib/features/profile/delete_account_screen.dart:41-72` |
| Data stored with appropriate security | RLS everywhere (primary layer), FORCE RLS hardening in flight (I-31) | §2.1 of this doc |
| PII minimized on hard delete | anonymization (username → `deleted_user_{id}`, avatar/bio nulled, messages `[deleted]`, ledgers `user_id` NULLed) | `lib/core/services/user_service.dart` (soft delete), `20260510000002_cron.sql:7-32` |

Legal source: Law N° 29733 (Peru) — https://www.gob.pe/institucion/congreso-de-la-republica/normas-legales/243470-29733

### 4.2 Apple App Store / Google Play

| Obligation | Implementation | Evidence |
|------------|---------------|----------|
| In-app account deletion (App Store 5.1.1(v); Play data-deletion policy) | Soft-delete (immediate, reversible 30 d) + hard-delete cron (permanent) | `delete_account_screen.dart` → `auth_provider.dart:385` → `auth_service.dart:93` → cron `20260510000002_cron.sql:47-52` |
| UGC reporting mechanism (chat, photos, users) | `reports` table + `reportContent()` | `lib/core/services/moderation_service.dart:14`; table `full_schema.sql:329-337` |
| Age rating 17+ / Mature | Declared in spec §2 (age-gated signup) | spec §2; age_gate_screen.dart |
| Data Safety form (Play) | Declare: account data, approximate location, photos/videos, messages, app activity | spec §2 (filing before release) |
| Privacy Policy URL (both stores) | Required at release; text lives in app | spec §2 / release checklist §12 |
| Subscriptions via StoreKit 2 / Play Billing (RevenueCat) | planned I-61, RCBH (post-MVP) | spec §6.12 |

### 4.3 Account deletion flow — code map

```
User taps "Eliminar mi cuenta"           lib/features/profile/settings_screen.dart:53-55
  → DeleteAccountScreen (email match check)  lib/features/profile/delete_account_screen.dart:32-39, 41-49
  → confirmation dialog                       delete_account_screen.dart:50-66
  → authProvider.deleteAccount()              lib/core/providers/auth_provider.dart:186-190
  → softDeleteUser():                         lib/core/services/auth_service.dart:93
      deleted_at = now, username = deleted_user_{id}, avatar_url/bio = NULL
  → signOut()                                 auth_service.dart (via auth_provider.dart:379)
Recovery window (30 days): admin CLI clears deleted_at  internal/ops/users.go (SoftDeleteUser counterpart) / docs/specs/steps/phase-03-auth-profiles/DELE-account-deletion.md
Hard delete (daily 03:00):                    supabase/migrations/20260510000002_cron.sql:47-52
  hard_delete_expired_users()                 cron.sql:7-32
    anonymize shard_ledger/preshard_ledger (user_id = NULL)   cron.sql:15-16
    anonymize messages (sender_id NULL, content '[deleted]')  cron.sql:19
    remove group_members / event_promotores / event_invites   cron.sql:22-26
    delete users row (cascade)                cron.sql:29
```

---

## 5. Incident Response & CVE Monitoring

### 5.1 Vulnerability watchpoints (subscribe + review weekly)

| Source | Watch | URL |
|--------|-------|-----|
| NVD | CVE feeds for GoTrue/PostgREST/Postgres/Storage/Kong images, Flutter/Dart | https://nvd.nist.gov/ (R12) |
| OSV | Go + Dart package ecosystems | https://osv.dev/ (R13) |
| pub.dev advisories | all pubspec.yaml deps (supabase_flutter, go_router, hive, flutter_secure_storage, image_picker, …) | https://dart.dev/tools/pub/security-advisories (R14) |
| GitHub advisories | dart-lang, supabase/supabase, signalapp repos | https://github.com/advisories (R15) |
| Go vuln DB | go.sum deps | https://vuln.go.dev/ (R16) |

**Initial scan:** S-02 agent runs the first full dependency CVE scan → `docs/security/CVE-SCAN.md` (pubspec.lock, go.sum, docker image tags in `supabase/docker-compose*.yml`).

### 5.2 Triage & response runbook

1. **Triage (SLA):** CRITICAL/HIGH (CVSS ≥ 7) in a shipped dependency or infra image → patch within 7 days; MEDIUM → next release; LOW → backlog. Sources per §5.1.
2. **Fix:** `flutter pub upgrade` / `go get -u` / bump pinned compose image; regression run: `flutter test`, `go test ./...`, `bash test/run_all_backend.sh`, `supabase db test`.
3. **Disclosure:** security advisories are published to repo docs/security/ after fix (S-20 consolidates).
4. **Active incident (e.g. credential leak, abuse wave):**
   - Contain: rotate keys (`SUPABASE_SERVICE_ROLE_KEY`, anon key, JWT secret, SMTP creds) via env, revoke sessions (`enable_refresh_token_rotation` already on — config.toml:58), freeze affected accounts via CLI ban (`internal/ops/users.go:73-89`).
   - Investigate: `admin_audit_log`, shard/preshard ledgers, Realtime/API access logs (Analytics 54388), GoTrue audit.
   - Recover: patch + redeploy migration; document in `docs/security/` with a dated incident note.
5. **Reporting:** notify store compliance if user data involved (Ley 29733 obligations).

---

## 6. Known Gaps & Owners

| # | Gap | Severity | Owner agent(s) | Reference |
|---|-----|----------|----------------|-----------|
| G-01 | `FORCE RLS` on 30/31 tables (only signup_tracker) | ✅ (I-31, 2026-08-09 — migration `20260809000001`: 31× `FORCE ROW LEVEL SECURITY`; `20260809000003` adds e2ee_identity_keys → **33 FORCE total**; `20260817000005` adds deleted_messages → **34 FORCE total** (K1, 2026-08-16); pgTAP §15/37/56e assert them) | I-31 | SUP-02, H-19/H-25, SEC-13 |
| G-02 | `SET search_path = ''` missing on 11 SECURITY DEFINER functions | ✅ (I-31, 2026-08-09 — `20260809000001` redefines all 12 with `SET search_path = ''`; every post-gate SD function follows) | I-31 | SUP-03, H-20/H-26, SEC-14 |
| G-03 | `users_update_own` allows mass-assignment of economy/subscription columns (self-elevation) | ✅ (I-32, 2026-08-09 — migration `20260809000002`: `REVOKE UPDATE` on the 7 protected columns from authenticated/anon + `assert_safe_user_update()` BEFORE INSERT OR UPDATE trigger (SECURITY INVOKER, one-way `deleted_at` soft-delete preserved); pgTAP §39a/39b) | I-32 | API3:2023 (R3) |
| G-04 | Token refresh never invoked; no PKCE on init; tokens not in SecureStorage | ✅ (I-30 + I-25, 2026-08-09 — `authFlowType: AuthFlowType.pkce` pinned in `lib/main.dart`; `tokenRefreshed` null-session handling + `AuthNotifier.refreshSession()` wired through `AuthService.refreshSession()`; session + PKCE code verifier persisted in flutter_secure_storage via `SecureSessionStorage`/`SecurePkceStorage` (SEC-04/SEC-11 closed, H-22) | I-30, I-25 | SEC-04, SEC-11, H-22 |
| G-05 | OTP rate limiting: no client cooldown, no attempt caps | ✅ (I-29, 2026-08-09 — client-side OTP UX guards: 60 s resend cooldown, 5-consecutive-failure block, signup double-tap guard, `RateLimitError` surfaced (SEC-05 client half, H-23). Server-side DB `rate_limits` caps remain S-10/I-31) | I-29 | SEC-05, H-23 |
| G-06 | `permission_handler` missing (camera/gallery runtime permission) | ✅ (I-28, 2026-08-09 — `permission_handler: ^12.0.3` in pubspec.yaml; camera/gallery/notification permission flows wired in qr_scanner/photo pickers) | I-28 | SEC-07, M-29 |
| G-07 | No input sanitization (NFKC, control chars, length caps) | ✅ (I-27, 2026-08-09 — shared `InputSanitizer` at every write boundary, 29 unit tests) | I-27 ✅ | SEC-06, H-24 |
| G-08 | `.env` bundled as asset + `flutter_dotenv`; `.env.example` leaks real anon key | ✅ (I-34, 2026-08-09 — no `assets:` in pubspec, dart-define injection, `.env.example` placeholder; M-13/S-08) | I-34, M-13 ✅ | SEC-03, SEC-09, H-21, M-31, SUP-05 |
| G-09 | E2EE chat: no crypto code, plaintext `messages.content`, no key lifecycle | ✅ (I-37/81722ef, 2026-08-09..13 — `lib/crypto/` 10 modules: X3DH + Double Ratchet, replay protection, session convergence, SPK expiry, secure key store; chat live; server stores ciphertext only. Key lifecycle hooks wired 2026-08-15: publish on `createProfile` + heal on session restore (`handleMissingSession`). Residual: `prekey_fetch_log` rate limit deferred to S-10) | I-37, I-38 ✅ | SEC-10/M-32 (Hive), E2EE-ARCHITECTURE.md |
| G-10 | Unencrypted Hive caches (config/photo/message) | ✅ (I-26, 2026-08-09 — `HiveService` opens all 4 boxes with `HiveAesCipher` (AES-256); 32-byte key in flutter_secure_storage (`samay.hive.key`), never on disk beside data; `crashRecovery: false` + zone-guarded opens; wrong-key → `HiveError` → delete + re-create (SEC-10/M-32 closed) | I-26 | SEC-10, M-32 |
| G-11 | Kong has no rate-limit plugin; app-level limits unenforced (FLMT blocked on Edge Functions) | 🟠 | M-09, S-10 (FLMT: EEDG) | SEC-05, FLMT doc |
| G-12 | Storage bucket policies not created; no signed-URL access check (client calls `createSignedUrl` directly) | ✅ (M-08, 2026-08-10 — buckets + storage.objects RLS shipped in `20260810000007_storage_buckets.sql`: avatars/groups public SELECT, events SELECT gated on event access via `event_photos` visibility, own-row INSERT/UPDATE/DELETE on `owner_id`; pgTAP Section 47. **Remaining:** client-side signed-URL issuance stays (no server-side signing RPC — edge functions blocked), event-cover serving on the private events bucket, signed-URL generation rate limiting — S-09/S-10) | S-09, I-59 | SECU-rls-policies.md §storage |
| G-13 | No crash/error reporting (Sentry placeholder) | 🟡 | I-70, I-05 | SEC-08, M-30 |
| G-14 | AuthGuard loading flash (`return null`) | 🟡 | I-03 | SEC-12, M-34 |
| G-15 | PostgREST error strings leak schema details to users | 🟡 | I-08 (done), verify S-13 | SEC-15, M-35 |
| G-16 | docker-compose port conflicts with Juega (5432, 54321) — violates AGENTS.md map | ✅ (I-02/M-01..M-10, 2026-08-10 — remap to 54382/54381/54384/54386/54388/54443; `tools/check_ports.sh --strict` PASS: 19 mappings / 221 refs / 0 violations) | I-02, M-01..M-05, M-10 | AGENTS.md §port; docker-compose.yml |
| G-17 | Stale pgTAP assertions on signup_tracker wide-open policies | ✅ (D-04, 2026-08-09 — `supabase/tests/schema_test.sql` + `supabase-testing/tests/schema_test.sql` Sections 6/15/37 now assert the email-scoped `signup_tracker_*_own` policies + `FORCE ROW LEVEL SECURITY` + `check_signup_email` grants; no "Anyone can …" assertions remain; both files byte-identical) | D-04 | supabase/tests/schema_test.sql |
| G-18 | Realtime channel abuse / presence enumeration | 🟡 | S-11 | §2.9 |
| G-19 | Deep-link/invite-token validation (samay://event/{token}) | 🟡 | S-12, I-66 | MASTG-BEST-0071 |
| G-20 | Go HTTP client: no timeouts/context; silent error swallowing in secondary queries | 🟡 | I-39 (+I-42 tests) | M-43, H-31 |
| G-21 | `minimum_password_length = 6` (NIST 800-63B recommends ≥ 8) | ✅ (2026-08-09 — `config.toml:62` = 8, both stacks) | I-30 | R10 §5.1.1; config.toml:62 |
| G-22 | No certificate pinning; no Android network-security-config hardening | 🟠 | S-05, M-27 | R11 |
| G-23 | Audit log integrity (append-only enforcement, CLI identity) | 🟡 | S-17 | §1.3 R-row |
| G-24 | Server-side rate limiting (Kong plugin + RPC-level caps, FLMT) | 🟠 (client OTP caps landed I-29; server-side blocked on Edge Functions — EEDG ❌) | S-10, M-09 | FLMT doc |
| G-25 | E2EE prekey-fetch rate limit (`prekey_fetch_log`) | 🟡 (deferred to S-10 — comment in `20260809000003:73-78`) | S-10 | E2EE-ARCHITECTURE.md §5.5 |

---

## 7. Verification Notes (D-06 evidence ledger)

Original ledger verified **2026-08-09** (pre-I-31 state); re-verified **2026-08-13** against HEAD `18b8c8b`:

- `rg "FORCE ROW LEVEL SECURITY"` across `supabase/migrations/` → **34 statements**: 31× in `20260809000001_harden_rls_search_path.sql:39-69`, signup_tracker in `20260724000001:73`, `e2ee_identity_keys` in `20260809000003:62`, `deleted_messages` in `20260817000005:30-31`. (2026-08-09 ledger: 1.)
- `rg "SECURITY DEFINER"` across `supabase/migrations/` → 22 files define SD functions; **every live SD function carries `SET search_path = ''`** (verified per migration; zero unhardened). (2026-08-09 ledger: 11 unhardened.)
- `rg "ENABLE ROW LEVEL SECURITY"` → 34 RLS-enabled tables (30 base + signup_tracker + storage-era + e2ee_identity_keys + deleted_messages).
- `refreshSession` callers: definition `lib/core/services/auth_service.dart`, invoked from `auth_provider.dart` `tokenRefreshed` handler (2026-08-09 ledger: zero callers).
- `AuthFlowType.pkce` present at `lib/main.dart:118`; `flutter_secure_storage` used by `SecureSessionStorage`/`SecurePkceStorage`/`HiveService`/E2EE key store.
- Input sanitizer: `lib/core/utils/input_sanitizer.dart`, 29 unit tests (2026-08-09 ledger: none).
- `.env.example:18` is the `your_supabase_anon_key_here` placeholder; pubspec.yaml has no `assets:` block (2026-08-09 ledger: real key at :5, `.env` asset at pubspec :38-39).
- Compose port map vs AGENTS.md: `tools/check_ports.sh --strict` → **PASS** (19 mappings / 221 refs / 0 violations); no 5432/54321 host mappings (2026-08-09 ledger: `5432:5432` + `54321:8000` conflicts).
- pgTAP: `plan(385) == 385` both stacks; Sections 6/15/37 assert email-scoped policies + FORCE (2026-08-09 ledger: "Anyone can …" assertions present).

---

*Samay Security Architecture — v1.1 (D-06) · 2026-08-13 refresh · Next review: after FLMT/rate-limiting and before Alpha release checklist (§12 of MVP spec).*
