# Samay — Security Precautions & Threat Model

**Status:** living document. Every precaution below is applied **today**; each
carries its *why* so future changes can weigh removal consciously. This is not
a forever-truth list — when a precaution changes or a gap closes, update this
file in the same commit.

Companion doc: `docs/security/E2EE-ARCHITECTURE.md` (historical chat crypto
design; the live consumer of the `lib/crypto/` primitives is the minigame answer
cipher).

---

## 0. References

Industry standards these decisions align with:

| # | Source | URL |
|---|--------|-----|
| R1 | OWASP MASVS v2 | https://mas.owasp.org/MASVS/ |
| R2 | OWASP MASTG | https://mas.owasp.org/MASTG/ |
| R3 | OWASP API Security Top 10 (2023) | https://owasp.org/API-Security/editions/2023/en/0x11-t10/ |
| R4 | Signal X3DH | https://signal.org/docs/specifications/x3dh/ |
| R5 | Signal Double Ratchet | https://signal.org/docs/specifications/doubleratchet/ |
| R6 | Supabase RLS guide | https://supabase.com/docs/guides/database/postgres/row-level-security |
| R7 | Supabase secure-data (service_role never client-side) | https://supabase.com/docs/guides/database/secure-data |
| R8 | PostgreSQL row-security (`FORCE` semantics) | https://www.postgresql.org/docs/current/ddl-rowsecurity.html |
| R9 | PostgreSQL CREATE FUNCTION (`search_path` guidance) | https://www.postgresql.org/docs/current/sql-createfunction.html |
| R10 | NIST SP 800-63B | https://pages.nist.gov/800-63-3/sp800-63b.html |
| R11 | NIST SP 800-124 Rev 2 | https://csrc.nist.gov/pubs/sp/800/124/r2/final |

---

## 1. Threat model

### 1.1 Assets

| Asset | Where it lives | Sensitivity |
|-------|---------------|-------------|
| User identity (email, birth date, username) | `auth.users`, `public.users`, `signup_tracker` | High |
| Minigame answer keys | Device only (`lib/crypto/**` + `lib/features/minigames/logic/minigame_cipher.dart`) — per-round AES-256-GCM keys, never on server. (Chat was removed in slim-prod; the `lib/crypto/` primitives now back only this cipher.) | Critical |
| Shard balances (retired economy) | `users.personal_shards/preshards` (still SELECTed by the profile reads), `groups.group_shards`; the ledgers `shard_ledger`/`preshard_ledger` are revoked from clients | Medium — the retired economy is read-only; wagers are always 0 |
| PII & UGC (bio, photos) | `users`, Storage buckets | High |
| Session tokens | Client secure storage + GoTrue | Critical |
| Admin credentials | `SUPABASE_SERVICE_ROLE_KEY` etc., env-only on the CLI machine | Critical — bypasses RLS by design (R7) |
| Audit trail | `admin_audit_log` | Medium |

### 1.2 Actors

| Actor | Trust posture |
|-------|--------------|
| Anonymous | Untrusted — RLS + GoTrue rate limits only |
| Authenticated user | Semi-trusted — every query scoped by RLS policies |
| Malicious authenticated user | Primary adversary: cross-user reads, mass assignment, search enumeration, QR replay |
| Compromised backend/table-owner role | Closed off via FORCE RLS (see §2.1) |
| Network attacker | HTTPS via Kong; no cert pinning yet (open item §6) |
| Insider admin | service_role via CLI only; every mutation audit-logged |

---

## 2. Server-side precautions (applied now)

### 2.1 FORCE ROW LEVEL SECURITY on every RLS table

- **Where:** `ALTER TABLE … ENABLE/FORCE ROW LEVEL SECURITY` across the
  migration set (single stack, `supabase/migrations/**` in the backend repo);
  61 FORCE statements today, and every FORCE-RLS table also has RLS ENABLED (a
  pgTAP invariant guards against a FORCE-without-ENABLE table silently
  bypassing its policies).
- **Why:** Postgres applies RLS to the table owner too *only* with `FORCE`
  (R8). Without it, any leak of the owner/postgres credential silently
  disables the entire authorization model. With it, RLS holds even for
  privileged roles except explicit `BYPASSRLS` (service_role, used solely by
  the admin CLI).
- **Also:** `signup_tracker` policies are email-scoped
  (`email = auth.jwt() ->> 'email'`), and pre-signup email checks go through
  the `check_signup_email` SECURITY DEFINER RPC instead of exposing the table.
  **Why:** signup is the one pre-auth surface; a wide-open table there would
  let anyone enumerate or wipe pending signups.

### 2.2 `SET search_path TO ''` on every SECURITY DEFINER function

- **Where:** every function declared `SECURITY DEFINER` in the migrations
  carries `SET search_path TO ''` and fully-qualified `public.` references.
- **Why:** SECURITY DEFINER executes with the creator's privileges; an
  attacker-controllable `search_path` can hijack unqualified object references
  into arbitrary SQL with elevated rights (R9). The empty search path makes
  hijacking impossible rather than merely unlikely.

### 2.3 EXECUTE grants locked down

- **Where:** every security-relevant RPC revokes `PUBLIC` and grants
  `EXECUTE`/`ALL` to `authenticated` (or `service_role` for admin-only ones);
  triggers get none.
- **Why:** Postgres grants EXECUTE to PUBLIC by default. A forgotten default
  once exposed anon EXECUTE on every SECURITY DEFINER function (including
  economy minting and PII hard-delete) — the single worst vulnerability this
  project has had. The revoke-per-function pattern exists so that class of
  mistake cannot recur silently.

### 2.4 Mass-assignment guards

- **Where:** `REVOKE UPDATE` on subscription/economy columns and one-way fields
  (`deleted_at`, `date_of_birth`) from authenticated/anon, plus
  `assert_safe_user_update` / `assert_safe_group_update` BEFORE triggers.
  The retired economy ledgers (`shard_ledger`, `preshard_ledger`) are revoked
  from clients by `300_slim/05_revoke_removed.sql`; the balance columns
  (`users.personal_shards`/`preshards`, `groups.group_shards`) stay
  SELECT-only and readable by `authenticated` (the profile reads project them);
  writes are blocked by the table-level REVOKEs plus
  `assert_safe_user_update` / `assert_safe_group_update`, not by column REVOKEs.
- **Why:** table-level GRANTs defeat column-level REVOKEs unless writes are
  re-checked; the triggers enforce one-way fields and server-managed counters
  like `rank_bracket` / `featured` regardless of what the client sends
  (R3 API4).

### 2.5 Auth hardening (GoTrue)

| Setting | Value | Why |
|---|---|---|
| Refresh-token rotation | enabled, reuse interval 10 s (`config.toml:58-59`, compose env) | A stolen refresh token is replayable indefinitely without rotation; reuse detection kills replayed tokens |
| PKCE flow | pinned at init (`lib/main.dart`, `AuthFlowType.pkce`) | Prevents authorization-code interception on mobile |
| Password minimum length | 8 (`config.toml:68`) | NIST SP 800-63B §5.1.1 (R10) — the previous min-6 was below guidance |
| Session/PKCE storage | `flutter_secure_storage` (iOS Keychain / Android Keystore), never shared prefs | Tokens in app-local plaintext are extractable from backups |
| Token refresh handling | explicit `refreshSession()` wiring; failed refresh → unauthenticated state | Silent refresh failure otherwise leaves users thinking they're authenticated while every call 401s |
| GoTrue rate limits | email_sent=2, token_refresh=150, token_verifications=30, sign_in_sign_ups=30 (`config.toml` `[auth.rate_limit]`) | Slows OTP spraying and credential stuffing at the auth layer |

### 2.6 Storage

- Buckets: `avatars` + `groups` public-read (public assets by design);
  `minigame_images` **private, participant-gated**
  (`storage_objects_minigame_images_select` / `..._insert` — encrypted
  minigame image ciphertext only, never plaintext/keys); object access governed
  by `storage.objects` RLS policies. The `events` bucket is retained server-side
  but Events was removed from the client in slim-prod.
- **Why signed URLs:** private-bucket objects must not be guessable; short
  expiry bounds link sharing. Signing runs through the caller's RLS session,
  so a SELECT policy must match — access control stays in one model.

### 2.7 Audit trail

- Every CLI/admin mutation writes an `admin_audit_log` row
  (`internal/ops/audit.go`); clients have no policy granting read/write on it.
- **Why:** repudiation — economy grants, bans, deletions must be attributable.

### 2.8 Search abuse protection (OWASP API4:2023)

User-search is the one endpoint that lets any authenticated account scan the
user base, so it gets layered resource-consumption controls (API4:
"Unrestricted Resource Consumption"):

| Layer | Control | Why |
|---|---|---|
| Kong plugin set | `KONG_PLUGINS` loads `rate-limiting` but no route declares it — the old `/rest/v1/user_search_view` route (and its limiter) was removed with the identity-privacy work (`233_identity_privacy`) | Nothing to throttle at the gateway today; the per-user quota below is the only enforcement |
| `search_users(p_query)` RPC | SECURITY DEFINER (`130_search/01_search_rpc.sql`): trimmed length ∈ [5, 50] (SR002), 60 searches/rolling-minute per user via atomic `search_rate_limits` upsert (SR001), anon rejected (SR003), LIKE wildcards escaped, caller excluded, LIMIT 20 | Server-side input caps + precise per-user quota; client-side gating (`usernameMinLength`) is bypassable |
| Prefix index | `idx_users_username_prefix` (`username text_pattern_ops`) | Plain-btree indexes cannot serve `ILIKE 'x%'` — without it every search sequential-scanned `users` |

The client maps `SR001`/HTTP 429 to `RateLimitError`
(`lib/core/extensions/error_mapper.dart`). **Deviation note:** direct client
SELECT on `user_search_view` was revoked (`233_identity_privacy/02_profile_privacy.sql`);
the view is still read by SECURITY DEFINER RPCs (public profiles, friend
profiles, lobby/invite context joins), which is now the only path — the Kong
route limiter was removed with that work. Coverage: `test/opt-015-search-rpc.sh`,
pgTAP Section 61.
`app_config`-driven generic thresholds remain open (O1).

### 2.9 Attendance codes / dynamic QR (removed)

The dynamic-QR attendance subsystem belonged to Events. The `event_*` tables
(including `event_code_keys` and 060_events migrations) are retained with
client grants revoked; the client code and `test/opt-027` were deleted.

---

## 3. Client-side precautions

| Precaution | Why | Where |
|---|---|---|
| Compile-time config via `--dart-define` (no app env file; `testing-local` reads the backend's `.env`, release ENVs read the vault) | Runtime-loaded `.env` files ship inside the APK/IPA and are trivially extractable | `lib/core/config/env_config.dart`, Makefile |
| Hive boxes encrypted (AES-256, key in secure storage) | Caches (config, prompt packs, session summaries) otherwise persist unencrypted on disk; key stored beside data = no encryption | `storage_service.dart` |
| Typed `RestClient` filter chain | String-interpolated PostgREST filters were an SQL-injection class risk; typed chain methods make interpolation unreachable by construction | `lib/core/services/rest_client.dart` |
| `InputSanitizer` at every write boundary (trim, control-char strip, NFKC, grapheme-safe caps) | Zero-width/bidi characters enable spoofing; oversized inputs break layouts and DB constraints | `input_sanitizer.dart` (server-side shape CHECKs back it up) |
| Guest-first account model (`signInAnonymously` + `bootstrap_profile`); optional Apple/Google linking (`linkIdentityWithIdToken` → `confirm_my_account`) | Credentials are optional; linking keeps the same guest uid | `lib/core/services/auth_service.dart` |
| Password recovery via `resetPasswordForEmail` | No password UI ships, but the auth surface keeps a recovery path | `auth_service.resetPasswordForEmail` |
| Ban screen + ban-aware auth state | Banned accounts must visibly lose access even before server-side token enforcement lands | `ban_service.dart`, `auth_guard.dart` |
| Camera permission for the minigame join QR scanner | Scanning the join QR without prompting fails silently or violates store policy | `lib/features/minigames/screens/join_scanner_screen.dart` |
| Crash/error reporting seam (`CrashReporter`) behind `SENTRY_DSN`; user context is a non-reversible SHA-256 of the uid (data minimization, never an email) | Production errors are otherwise invisible beyond local logs; the stub keeps running until a DSN is configured | `crash_reporter.dart` |

## 4. Cryptography policy

Approved: X25519 + Ed25519 (key agreement/signatures), AES-256-GCM (minigame
answers), HKDF-SHA256 with domain-separated `info` strings, SHA-256/512.
Not allowed: MD5/SHA-1, ECB, CBC-without-MAC, RC4/DES/3DES, RSA <2048,
hardcoded key material, custom protocols, nonce reuse. Keys are generated with
CSPRNGs on device and live only in secure storage. The `lib/crypto/` primitives
and the historical chat design are described in
`docs/security/E2EE-ARCHITECTURE.md`. **Why this list:** everything approved
is a standard, reviewed construction (R4/R5/R2); everything banned has a known
break or a footgun.

## 5. Compliance

- **Peru Ley N° 29733:** privacy policy + terms accepted via the single
  onboarding consent action (`bootstrap_profile` records `age_confirmed_at`,
  `terms_accepted_at`, `terms_version`), 18+ age gate, in-app deletion flow,
  anonymizing hard delete (daily cron). Law text: https://www.gob.pe/institucion/congreso-de-la-republica/normas-legales/243470-29733
- **Stores:** in-app account deletion (App Store 5.1.1(v)), UGC reporting
  (`reports` table + `reportContent()`), 18+ store rating via override for a
  drinking-game app, Data Safety form before release, Privacy Policy URL at
  release.

## 6. Open items (ranked)

These are known gaps, deliberately tracked here — each needs a decision or an
implementation pass; none is silently accepted:

| # | Severity | Item | Why still open |
|---|----------|------|----------------|
| O1 | HIGH → PARTIALLY RESOLVED 2026-08-25 | ~~No Kong rate-limit plugin;~~ `security.*` app_config thresholds unenforced server-side. **Shipped:** per-user 60/min quota in `search_users()` (§2.8). The Kong route limiter was removed with the identity-privacy work. Still open: Edge-Function-level limits for the remaining endpoints (`EEDG`) and app_config-driven thresholds | Remaining scope blocked on Edge Functions (`EEDG`); GoTrue-level limits + the `search_users()` quota are partial cover |
| O2 | HIGH | API-server admin gate is a static `ADMIN_API_KEY` placeholder | Real JWT/JWKS + `admin_users` required before any deployment |
| O3 | MEDIUM | No certificate pinning / network-security-config | Needs prod domain first |
| O4 | MEDIUM | No screenshot protection (`FLAG_SECURE`) on multiplayer answer surfaces | Trade-off vs. screen-recording UX; revisit before wide rollout |
| O5 | RESOLVED 2026-08-25 for username/bio: server-side sanitize+validate now lives in the profile RPC family (`create_my_profile`/`update_my_profile`, baseline `020_core/02_users.sql`) + a tombstone-exempt `users_username_shape` CHECK; clients hold NO INSERT/UPDATE on `public.users` at all. Remaining text columns with client writers have RPC setters. Grapheme-vs-code-point note: caps are code points (username ≤64, bio ≤160). | Done — see the backend repo's migration `020_core/02_users.sql` + `test/opt-014-profile-rpc.sh` |
| O6 | LOW | Realtime channel-existence enumeration | Row access is RLS-governed; enumeration residual accepted for MVP |
| O7 | LOW | Deep-link join-code validation depth (`samay://join/<CODE>`, `https://samay.qallariy.lat/j/<CODE>`) | Codes are short and rate-limited server-side; add signature/HMAC if abuse appears |
| O8 | LOW | Audit-log append-only enforcement (DB level) | CLI is the only writer today; enforcement matters when second writer appears |
| O9 | LOW | Image-default TABLE grants remain broad (`arwdDxtm`) | Triggers + RLS are the enforcement layer; grant-model cleanup pre-Alpha |
| O10 | LOW | No data-export feature (store-review risk); anon/JWT-secret rotation is an ops action at deploy time | Release-checklist item |

## 7. Secrets hygiene

- **Rule:** no secrets in code, tests, or docs — placeholders only. Local
  values live in `../backend/.env/testing-local.env` and `.env.local` (both
  gitignored) and are the source of truth for `tools/check_secrets.sh`, which
  fails if any local secret value appears in a tracked file.
- Service-role keys exist only on machines running the admin CLI/API server
  (R7). Compose defaults are placeholder strings meant to be overridden.
- Dependency CVE watch: subscribe to OSV/NVD/pub.dev/Go-vuln feeds; triage
  SLA — CVSS ≥ 7 patched within 7 days, medium next release, low backlog.
