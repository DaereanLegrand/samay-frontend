# Samay — Security Architecture & Threat Model

**Owner:** D-06 (security architecture doc) · **Reviewed:** 2026-08-09 · **Status:** living document — update at every security change (RLS hardening, E2EE rollout, release checklist)

> Companion docs: `docs/security/E2EE-ARCHITECTURE.md` (D-07, planned — X3DH + Double Ratchet spec), `docs/security/MASVS-AUDIT.md` (S-01), `docs/security/CVE-SCAN.md` (S-02), `docs/security/FINAL-SECURITY-REPORT.md` (S-20), `docs/to-fix/categories/08-SECURITY.md` and `06-SUPABASE-BACKEND.md` (findings), `docs/implementation/phase-00-foundation/SECU-rls-policies.md` (RLS design).

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
| A2 — E2EE chat keys | Device only (planned `lib/crypto/`, I-37/I-38) | Critical | X25519 identity + ratchet keys; **never on server**; ciphertext-only server (R4/R5) |
| A3 — Shard balances | `users.personal_shards`, `users.preshards`, `shard_ledger`, `preshard_ledger`, `groups.group_shards` | Critical | economy integrity = app integrity; double-spend = top risk |
| A4 — PII & UGC | `users` (bio, DoB), `messages`, `event_photos`, `event_qr_tokens`, `notifications` | High | photos in Storage, chat plaintext (until E2EE) |
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
| Compromised backend role | service_role / table owner / `postgres` credentials theft (CLI machine, leaked `.env`) | **Defense:** no FORCE RLS today = table owner bypasses policies (R8) → I-31 |
| Network attacker | Passive TLS interception / MITM, Realtime WS sniffing | Mitigated by HTTPS (Kong 54443); no cert pinning yet |
| Insider admin | Full service_role access via CLI; audit-logged | Mitigated by `admin_audit_log` (A8) + least-privilege roles |

### 1.3 STRIDE table (mapped to Samay components)

| Threat | Samay component exposed | Current status | Primary mitigation | Owner |
|--------|------------------------|----------------|-------------------|-------|
| **S — Spoofing identity** | Auth (OTP), JWT handling, session persistence | ⚠️ `refreshSession()` never called (supabase_service.dart:53-60); `AuthFlowType` not set on init (main.dart:38-41); tokens not wired to SecureStorage (storage_service.dart:4-18 unused by auth) | PKCE on init, auto token refresh (I-30), SecureStorage persistence (I-25), GoTrue `enable_refresh_token_rotation` (config.toml:58) | I-30, I-25 |
| **T — Tampering (data)** | PostgREST writes; RLS policies; triggers | ⚠️ `users_update_own` allows updating **every column** of own row incl. `personal_shards`/`preshards`/`subscription_tier`/`banned_at` (full_schema.sql:611-612) — mass-assignment / self-elevation vector (API3:2023) | Column-level policies or restricted views (I-32); server-side validation in Edge Functions (FLMT); forbid client writes on ledger/economy columns | I-32, S-03 |
| **T — Tampering (privileged)** | SECURITY DEFINER functions | 🔴 12 SECURITY DEFINER functions lack `SET search_path = ''` (evidence in §2.2) → search_path hijack ⇒ privilege escalation (R9) | I-31 hardening migration | I-31 |
| **R — Repudiation** | Admin operations | ✅ `admin_audit_log` row per CLI mutation (internal/ops/audit.go:17-25; policy denies client access full_schema.sql:785) | Keep append-only; S-17 integrity review | S-17 |
| **I — Information disclosure** | `user_search_view` (security barrier, id/username/avatar_url only — 20260520000001:217-222); `users` read-own (full_schema.sql:610); messages/events/group policies | ✅ mostly scoped; ⚠️ `.env.example` contains a **real publishable anon key** (.env.example:5, H-21 open) | Rotate key + placeholder (I-34); column-level grants; S-03 audit | I-34, S-03 |
| **I — Information disclosure (E2EE)** | Chat `messages.content` | 🔴 plaintext in Postgres until E2EE lands (I-37/I-38); route is coming-soon (app_router.dart:159) | X3DH + Double Ratchet, client-only keys (R4/R5) → E2EE-ARCHITECTURE.md | I-37, I-38 |
| **D — Denial of service** | OTP sending (GoTrue `email_sent = 2` config.toml:65); search `.ilike` prefix enumeration (supabase_service.dart:310-317); RPC `donate_shards_to_group` (no rate limit); Realtime channels (supabase_service.dart:863-918); photo upload 50MiB (config.toml:42) | ⚠️ auth-level limits exist; no app-level limiting; no Kong rate-limit plugin (kong.yml plugins: cors/key-auth/acl only); FLMT blocked on Edge Functions | Kong rate-limit plugin (M-09), app_config thresholds (seed.sql:43-46), I-29 OTP UX caps, S-10 audit | I-29, S-10, M-09 |
| **E — Elevation of privilege** | RLS bypass: no `FORCE RLS` on 30/31 tables (only signup_tracker: 20260724000001:73); table owner bypasses RLS (R8) | 🔴 open (H-19/H-25, SUP-02) | I-31 migration adds `FORCE ROW LEVEL SECURITY` on all tables + per-table exception review | I-31 |

---

## 2. Security Architecture

### 2.1 RLS strategy + FORCE RLS

**Design (from `docs/implementation/phase-00-foundation/SECU-rls-policies.md`):** RLS is the *primary* security layer (spec §4). Every table in the exposed `public` schema carries `ENABLE ROW LEVEL SECURITY`; the `authenticated` role is gated per-table; `service_role` is the privileged path for CLI/Edge Functions; admin tables (`admin_users`, `admin_audit_log`, `subscription_overrides`, `processed_webhooks`) are `FOR ALL USING (false)` (defense-in-depth, full_schema.sql:783-787).

**Verified current status (evidence):**

| Claim | Evidence | Status |
|-------|----------|--------|
| RLS enabled on all 30 base tables | `supabase/migrations/20260510000001_full_schema.sql:578-607` (30× `ALTER TABLE ... ENABLE ROW LEVEL SECURITY`) | ✅ |
| RLS enabled on `signup_tracker` | `supabase/migrations/20260513000002_fix_signup_tracker.sql:13` | ✅ |
| **FORCE RLS: enabled only on `signup_tracker`** | `supabase/migrations/20260724000001_fix_signup_tracker_rls.sql:73` (`ALTER TABLE public.signup_tracker FORCE ROW LEVEL SECURITY;`) — the **only** `FORCE RLS` in the repo (grep: 3 matches, all in this file) | ⚠️ 1/31 tables |
| signup_tracker policies email-scoped (own-email only) | `20260724000001_fix_signup_tracker_rls.sql:57-68` (`email = auth.jwt() ->> 'email'`) — replaces the original wide-open `USING (true)` policies (`20260513000002:15-30`) | ✅ (C-01, commit b02090e) |
| Pre-auth email check via hardened RPC | `check_signup_email` — `SECURITY DEFINER`, `SET search_path = ''`, explicit `REVOKE/GRANT` (`20260724000001:15-44`) | ✅ pattern reference |
| RLS recursion bugs fixed post-hoc | `20260512000006_fix_group_members_rls_recursion.sql`, `20260512000008_fix_events_rls_recursion.sql` (42P17) | ✅ history |
| `user_search_view` exposes only id/username/avatar_url | `20260520000001_admin_rpc_and_rls.sql:217-222` (`security_barrier` view, `deleted_at IS NULL`) | ✅ |
| `donate_shards_to_group` RPC requires auth + own-user check | `20260724000002_fix_donate_shards_rpc.sql:17-19` (`auth.uid() != p_user_id` → exception), `:36-37` (`REVOKE ... FROM PUBLIC; GRANT ... TO authenticated`) | ✅ |
| RLS verified by integration tests | `test/opt-001-rls-security.sh` — anon/auth/service role matrix (A–H sections) | ✅ (run via `test/run_all_backend.sh`) |
| pgTAP suite **still asserts the old wide-open signup_tracker policies** | `supabase/tests/schema_test.sql:170-177` (expects `Anyone can select...`) | 🔴 stale — D-04 owns the fix |

**Plan (owner I-31):** migration adding `ALTER TABLE ... FORCE ROW LEVEL SECURITY` to all tables, with audited exceptions where service_role genuinely needs unfiltered access (e.g. `admin_audit_log` inserts from CLI); per-table exception justification required (SECU-rls-policies.md pattern, Juega reference).

### 2.2 SECURITY DEFINER search_path hardening (I-31)

Postgres executes `SECURITY DEFINER` functions with the *creator's* privileges, so an attacker-controllable `search_path` can hijack unqualified object references → arbitrary SQL with elevated rights (R9). Fix: `SET search_path = ''` + fully-qualified `public.` references.

**Verified inventory — 12 SECURITY DEFINER functions, 11 unhardened (only `check_signup_email` sets `search_path = ''`):**

| Function | Migration : line | search_path |
|----------|------------------|-------------|
| `update_group_size_tier` | 20260510000001_full_schema.sql:469 (redefined 20260512000007:25) | ❌ missing |
| `set_dynamic_qr_enabled` | 20260510000001_full_schema.sql:482 | ❌ missing |
| `enforce_message_cap` | 20260510000001_full_schema.sql:513 | ❌ missing |
| `increment_group_shards` | 20260510000001_full_schema.sql:527 | ❌ missing |
| `update_photo_likes_count` | 20260510000001_full_schema.sql:551 | ❌ missing |
| `dispatch_shard_distribution` | 20260510000001_full_schema.sql:567 | ❌ missing |
| `hard_delete_expired_users` | 20260510000002_cron.sql:32 | ❌ missing |
| `donate_shards_to_group` | 20260512000001:13 / 20260724000002:14 | ❌ missing |
| `grant_shards` | 20260520000001_admin_rpc_and_rls.sql:15 | ❌ missing |
| `grant_preshards` | 20260520000001_admin_rpc_and_rls.sql:40 | ❌ missing |
| `distribute_shards` | 20260520000001_admin_rpc_and_rls.sql:65 | ❌ missing |
| `recalculate_ranks` | 20260520000001_admin_rpc_and_rls.sql:165 | ❌ missing |
| `check_signup_email` | 20260724000001_fix_signup_tracker_rls.sql:19 | ✅ `''` (reference pattern) |
| `handle_signup` (dropped) | 20260513000001:9 had `SET search_path = public` | 🔴 history — dropped by 20260513000002:4 |

### 2.3 Auth: JWT, PKCE, session handling (I-30)

**Verified current status:**

| Claim | Evidence |
|-------|----------|
| JWT expiry 1 h, refresh-token rotation ON, reuse-interval 10 s | `supabase/config.toml:57-59` |
| GoTrue rate limits configured (email_sent=2, token_refresh=150, token_verifications=30, …) | `supabase/config.toml:64-71` |
| OTP: 6 digits, 1 h expiry; email max_frequency 1s | `supabase/config.toml:79-80`, `:78` |
| `refreshSession()` **defined but never called** | `lib/core/services/supabase_service.dart:53-60` (grep: no callers) |
| No explicit PKCE (`AuthFlowType`) on client init | `lib/main.dart:38-41` (`Supabase.initialize(url:…, anonKey:…)` only) |
| Auth state listens to `tokenRefreshed` | `lib/core/providers/auth_provider.dart:60` (handles event, but relies on SDK auto-refresh, not explicit refreshSession) |
| Tokens NOT stored via `flutter_secure_storage` | `lib/core/services/storage_service.dart:4-18` exists; zero references from auth code (SEC-11) |
| `secure_password_change = false`, password min length 6 | `supabase/config.toml:62, 77` (⚠️ 6 < NIST SP 800-63B §5.1.1 recommended minimum of 8) |
| Auth guard redirect logic | `lib/core/router/auth_guard.dart:13-36` (`if (auth.loading) return null;` — SEC-12 loading flash, open M-34) |

**Plan (I-30):** enable PKCE on init, subscribe + call `refreshSession()` on `TOKEN_REFRESHED`, persist session via SecureStorage-backed `AsyncStorage`, ban-enforcement hook when Edge Functions land (AUTH spec §ban).

### 2.4 E2EE chat (I-37/I-38 — spec lives in `docs/security/E2EE-ARCHITECTURE.md`, owned by D-07)

- Protocol: **X3DH** key agreement (R4) + **Double Ratchet** message ratchet (R5) — "as secure as Signal": identity keys and ratchet state client-only, server stores ciphertext only (see ORCHESTRATION.md cross-cutting requirement #4).
- Parameters (per X3DH §2.1): curve **X25519**, hash **SHA-256**, AEAD via AES-256-GCM; per-message keys from HKDF chains; `MAX_SKIP` bounds skipped-key storage (Double Ratchet §3.1, §8.4).
- Prekey management per X3DH §3.2: signed prekey rotation (e.g. weekly) + one-time prekey replenishment + rate-limited prekey-bundle fetch (X3DH §4.7 server-trust).
- Current code state: no crypto code exists (`lib/crypto/` planned); chat route is `VComingSoonScreen` (app_router.dart:159); `messages.content` is plaintext (full_schema.sql:251-260).

### 2.5 Storage buckets + signed URLs (S-09)

| Claim | Evidence |
|-------|----------|
| Event photos: private bucket, 1 h signed URLs | `lib/core/services/supabase_service.dart:656-659` (`createSignedUrl(storagePath, 3600)`); bucket design: SECU-rls-policies.md:51-55 |
| Group covers: public bucket + public URL | `lib/features/groups/create_group_screen.dart:77-80` (`uploadBinary` + `getPublicUrl`) |
| No image size/resizing on upload (full-res files) | `lib/core/services/supabase_service.dart:641-645` (raw bytes) — I-22 image_processor |
| Storage file-size cap 50 MiB | `supabase/config.toml:42` |
| **Bucket policies not yet created** (deferred) | SECU-rls-policies.md:43-67; no storage migration exists |

Plan (S-09/I-59): define per-bucket policies (avatars public-read/own-write, events private + signed URLs, chats private, cosmetics public), enforce path-prefix ownership (`{user_id}/...`), signed URL expiry ≤ 1 h, rate-limit URL generation.

### 2.6 Input sanitization (I-27)

Current: **no sanitization layer** — 12 raw `TextEditingController` input sites across auth/friends/groups/profile screens (e.g. `login_screen.dart:19-20`, `signup_contact_screen.dart:18-20`, `create_group_screen.dart:18-19`, `invite_screen.dart:14`, `donate_shards_screen.dart:23`), no NFKC normalization, no control-character stripping, no length caps (SEC-06). Client-side validation exists only for password strength (`signup_contact_screen.dart:31-34`) and donation amount (`donate_shards_screen.dart:31-33`). Plan (I-27): shared `InputSanitizer` (trim, NFKC, strip `\p{Cc}\p{Cf}`, per-field max length) at every entry point + server-side length caps via DB CHECK constraints.

### 2.7 Rate limiting (Kong + app_config + GoTrue)

| Layer | Status | Evidence |
|-------|--------|----------|
| GoTrue auth rate limits | ✅ configured | config.toml:64-71; docker-compose.yml:86 (`GOTRUE_RATE_LIMIT_EMAIL_SENT: 2`) |
| Kong gateway plugins | ⚠️ key-auth + ACL + CORS only — **no rate-limit plugin** | supabase/volumes/api/kong.yml:22-32 (rest-v1), :34-49 (rest-admin service_role-only) |
| app_config abuse thresholds | ✅ seeded, **not enforced** (FLMT blocked — no Edge Functions) | seed.sql:43-46 (`security.max_events_per_minute=3`, `max_concurrent_event_invites=50`, `max_qr_token_rotations=20`, `max_failed_qr_validations=5`); docs/implementation/phase-00-foundation/FLMT-edge-functions-rate-limiting.md |
| OTP client-side cooldown / attempt caps | ❌ none (SEC-05) | supabase_service.dart:39-45 (`sendOtp`/`verifyOtp` uncapped) |
| Search enumeration | ⚠️ `.ilike('username', '$query%')` prefix search, limit 20, authenticated-only view | supabase_service.dart:310-317 |

### 2.8 Secrets management (I-34 / M-13)

| Claim | Evidence | Status |
|-------|----------|--------|
| `.env` bundled as Flutter asset | `pubspec.yaml:38-39` (`assets: [.env]`) — extractable from APK/IPA (SEC-09/M-31) | 🔴 |
| Env consumed via `flutter_dotenv` at runtime | `lib/main.dart:37`, `lib/core/config/env_config.dart:9-15` | 🔴 (must move to `String.fromEnvironment` dart-define) |
| `.env.example` contains a **real publishable anon key** | `.env.example:5` (H-21/SEC-03 — committed to git history) | 🔴 — rotate + placeholder |
| Service role / admin IDs via env only, never in app | `internal/db/client.go:21-22`, `cmd/samay-admin/root.go:15, 52-57` | ✅ |
| Compose uses placeholder secrets (no real creds committed) | `supabase/docker-compose.yml:67, 74, 102, 124, 127, 146-147` ("your-…-change-in-production") | ✅ (M-01..M-05 to finish pinning) |
| Makefile passes `APPLE_PASSWORD` as plaintext var | `Makefile:16, 62-70` (M-13 to move to env/pass) | ⚠️ |
| Dev test script embeds local dev keys | `test/opt-001-rls-security.sh:20-22` (local-stack dev keys only — acceptable for dev, must never be prod) | ⚠️ |

Rule: **no secrets in code, tests, or docs — placeholders only** (AGENT-RULES §4). Build-time injection via `--dart-define` (Makefile `build`/`dev` targets, M-11/M-13).

### 2.9 Network transport

- HTTPS in prod via Kong TLS (`54443`, AGENTS.md port map); PostgREST/GoTrue behind Kong (kong.yml). Self-hosted dev is HTTP on localhost only.
- No certificate pinning implemented (S-05 scope); keep OS trust store + enforce TLS 1.2+ (R11).
- Realtime: WebSocket with JWT; channel names embed user/entity ids (`supabase_service.dart:880-918`) — Realtime row access is governed by table RLS; channel-existence enumeration is a residual risk (S-11).

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
| PII minimized on hard delete | anonymization (username → `deleted_user_{id}`, avatar/bio nulled, messages `[deleted]`) | `supabase_service.dart:72-84`, `20260510000002_cron.sql:7-32` |

Legal source: Law N° 29733 (Peru) — https://www.gob.pe/institucion/congreso-de-la-republica/normas-legales/243470-29733

### 4.2 Apple App Store / Google Play

| Obligation | Implementation | Evidence |
|------------|---------------|----------|
| In-app account deletion (App Store 5.1.1(v); Play data-deletion policy) | Soft-delete (immediate, reversible 30 d) + hard-delete cron (permanent) | `delete_account_screen.dart:41-72` → `supabase_service.dart:72-84` → cron `20260510000002_cron.sql:47-52` |
| UGC reporting mechanism (chat, photos, users) | `reports` table + `reportContent()` | `supabase_service.dart:770-781`; table `full_schema.sql:329-337` |
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
  → softDeleteUser():                         lib/core/services/supabase_service.dart:72-84
      deleted_at = now, username = deleted_user_{id}, avatar_url/bio = NULL
  → signOut()                                 supabase_service.dart:35-37
Recovery window (30 days): admin CLI clears deleted_at  internal/ops/users.go (SoftDeleteUser counterpart) / docs/implementation/phase-03-auth-profiles/DELE-account-deletion.md
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
| G-01 | `FORCE RLS` on 30/31 tables (only signup_tracker) | 🔴 | I-31 | SUP-02, H-19/H-25, SEC-13 |
| G-02 | `SET search_path = ''` missing on 11 SECURITY DEFINER functions | 🔴 | I-31 | SUP-03, H-20/H-26, SEC-14 |
| G-03 | `users_update_own` allows mass-assignment of economy/subscription columns (self-elevation) | 🔴 | I-32, S-03 | API3:2023 (R3) |
| G-04 | Token refresh never invoked; no PKCE on init; tokens not in SecureStorage | 🟠 | I-30 (+I-25) | SEC-04, SEC-11, H-22 |
| G-05 | OTP rate limiting: no client cooldown, no attempt caps | 🟠 | I-29 (+S-10) | SEC-05, H-23 |
| G-06 | `permission_handler` missing (camera/gallery runtime permission) | 🟠 | I-28 | SEC-07, M-29 |
| G-07 | No input sanitization (NFKC, control chars, length caps) | 🟠 | I-27 | SEC-06, H-24 |
| G-08 | `.env` bundled as asset + `flutter_dotenv`; `.env.example` leaks real anon key | 🟠 | I-34, M-13 (+S-08) | SEC-03, SEC-09, H-21, M-31, SUP-05 |
| G-09 | E2EE chat: no crypto code, plaintext `messages.content`, no key lifecycle | 🔴 (before chat ships) | I-37, I-38 (spec D-07) | SEC-10/M-32 (Hive), E2EE-ARCHITECTURE.md |
| G-10 | Unencrypted Hive caches (config/photo/message) | 🟠 | I-26 | SEC-10, M-32 |
| G-11 | Kong has no rate-limit plugin; app-level limits unenforced (FLMT blocked on Edge Functions) | 🟠 | M-09, S-10 (FLMT: EEDG) | SEC-05, FLMT doc |
| G-12 | Storage bucket policies not created; no signed-URL access check (client calls `createSignedUrl` directly) | 🟠 | S-09, I-59 | SECU-rls-policies.md §storage |
| G-13 | No crash/error reporting (Sentry placeholder) | 🟡 | I-70, I-05 | SEC-08, M-30 |
| G-14 | AuthGuard loading flash (`return null`) | 🟡 | I-03 | SEC-12, M-34 |
| G-15 | PostgREST error strings leak schema details to users | 🟡 | I-08 (done), verify S-13 | SEC-15, M-35 |
| G-16 | docker-compose port conflicts with Juega (5432, 54321) — violates AGENTS.md map | 🟠 | I-02, M-01..M-05, M-10 | AGENTS.md §port; docker-compose.yml:13,44; run.sh:17 |
| G-17 | Stale pgTAP assertions on signup_tracker wide-open policies | 🟡 | D-04 (I-77 expansion) | supabase/tests/schema_test.sql:170-177 |
| G-18 | Realtime channel abuse / presence enumeration | 🟡 | S-11 | §2.9 |
| G-19 | Deep-link/invite-token validation (samay://event/{token}) | 🟡 | S-12, I-66 | MASTG-BEST-0071 |
| G-20 | Go HTTP client: no timeouts/context; silent error swallowing in secondary queries | 🟡 | I-39 (+I-42 tests) | M-43, H-31 |
| G-21 | `minimum_password_length = 6` (NIST 800-63B recommends ≥ 8) | 🟡 | I-30 (config change) | R10 §5.1.1; config.toml:62 |
| G-22 | No certificate pinning; no Android network-security-config hardening | 🟡 | S-05, M-27 | R11 |
| G-23 | Audit log integrity (append-only enforcement, CLI identity) | 🟡 | S-17 | §1.3 R-row |

---

## 7. Verification Notes (D-06 evidence ledger)

Every "current status" claim above was cross-checked against the working tree on 2026-08-09:

- `rg "FORCE ROW LEVEL SECURITY"` across `supabase/` → exactly one enforcement (signup_tracker), three comment+statement matches in `20260724000001_fix_signup_tracker_rls.sql` (lines 4, 71, 73).
- `rg "SECURITY DEFINER"` across `supabase/migrations/` → 14 functions defined SECURITY DEFINER; 12 survive today; only `check_signup_email` carries `SET search_path = ''`; `handle_signup` carried `SET search_path = public` and was dropped.
- `rg "ENABLE ROW LEVEL SECURITY"` → 30 in `20260510000001_full_schema.sql` + 1 in `20260513000002_fix_signup_tracker.sql` = 31 RLS-enabled tables.
- `refreshSession` callers: grep over `lib/` → definition at `supabase_service.dart:53`, zero invocations.
- `AuthFlowType`/`pkce`/`permission_handler`/`sentry`/`cached_network` over `lib/`: zero matches.
- Input sites: 21 `TextEditingController`/`TextField` matches across 13 files; no sanitizer module exists.
- Anon key presence in `.env.example:5` and `.env` as Flutter asset (`pubspec.yaml:38-39`) confirmed by direct read (key value deliberately not repeated in this doc).
- Compose port map vs AGENTS.md: `docker-compose.yml:13` (`5432:5432`) and `:44` (`54321:8000`) conflict with the approved map (54382/54386) — filed as G-16.
- `supabase/tests/schema_test.sql:170-177` still asserts the four "Anyone can …" signup_tracker policies (stale since 20260724000001) — filed as G-17.

---

*Samay Security Architecture — v1.0 (D-06) · 2026-08-09 · Next review: after I-31/I-30/I-37 land and before Alpha release checklist (§12 of MVP spec).*
