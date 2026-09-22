# Samay — Security Precautions & Threat Model

**Status:** living document. Every precaution below is applied **today**; each
carries its *why* so future changes can weigh removal consciously. This is not
a forever-truth list — when a precaution changes or a gap closes, update this
file in the same commit.

Companion doc: `docs/security/E2EE-ARCHITECTURE.md` (chat crypto spec).

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
| E2EE chat keys | Device only (`lib/crypto/`) — never on server | Critical |
| Shard economy (balances + ledgers) | `users.personal_shards/preshards`, `shard_ledger`, `preshard_ledger`, `groups.group_shards` | Critical — double-spend is the top business risk |
| PII & UGC (bio, photos, chat) | `users`, Storage buckets, `messages` (ciphertext only) | High |
| Session tokens | Client secure storage + GoTrue | Critical |
| Admin credentials | `SUPABASE_SERVICE_ROLE_KEY` etc., env-only on the CLI machine | Critical — bypasses RLS by design (R7) |
| Audit trail | `admin_audit_log` | Medium |

### 1.2 Actors

| Actor | Trust posture |
|-------|--------------|
| Anonymous | Untrusted — RLS + GoTrue rate limits only |
| Authenticated user | Semi-trusted — every query scoped by RLS policies |
| Malicious authenticated user | Primary adversary: cross-user reads, mass assignment, OTP abuse, search enumeration, QR replay, shard manipulation |
| Compromised backend/table-owner role | Closed off via FORCE RLS (see §2.1) |
| Network attacker | HTTPS via Kong; no cert pinning yet (open item §6) |
| Insider admin | service_role via CLI only; every mutation audit-logged |

---

## 2. Server-side precautions (applied now)

### 2.1 FORCE ROW LEVEL SECURITY on every RLS table

- **Where:** `ALTER TABLE … ENABLE/FORCE ROW LEVEL SECURITY` across the
  migration set (`supabase/migrations/**`, mirrored byte-identical in
  `supabase-testing/migrations/**`); 44 FORCE statements today, and every
  FORCE-RLS table also has RLS ENABLED (a pgTAP invariant guards against a
  FORCE-without-ENABLE table silently bypassing its policies).
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
  shard minting and PII hard-delete) — the single worst vulnerability this
  project has had. The revoke-per-function pattern exists so that class of
  mistake cannot recur silently.

### 2.4 Mass-assignment guards

- **Where:** `REVOKE UPDATE` on economy/subscription columns
  (`personal_shards`, `group_shards`, subscription fields…) from
  authenticated/anon, plus `assert_safe_user_update` /
  `assert_safe_group_update` / `assert_safe_event_update` BEFORE triggers.
- **Why:** table-level GRANTs defeat column-level REVOKEs unless writes are
  re-checked; the triggers enforce one-way fields (e.g. `deleted_at`,
  server-managed counters like `rank_bracket`, `featured`) regardless of what
  the client sends (R3 API4).

### 2.5 Auth hardening (GoTrue)

| Setting | Value | Why |
|---|---|---|
| Refresh-token rotation | enabled, reuse interval 10 s (`config.toml:58-59`, compose env) | A stolen refresh token is replayable indefinitely without rotation; reuse detection kills replayed tokens |
| PKCE flow | pinned at init (`lib/main.dart`, `AuthFlowType.pkce`) | Prevents authorization-code interception on mobile |
| Password minimum length | 8 (`config.toml:62`) | NIST SP 800-63B §5.1.1 (R10) — the previous min-6 was below guidance |
| Session/PKCE storage | `flutter_secure_storage` (iOS Keychain / Android Keystore), never shared prefs | Tokens in app-local plaintext are extractable from backups |
| Token refresh handling | explicit `refreshSession()` wiring; failed refresh → unauthenticated state | Silent refresh failure otherwise leaves users thinking they're authenticated while every call 401s |
| GoTrue rate limits | email_sent=2, token_refresh=150, verifications=30, signin/signups=30 (`config.toml:64+`) | Slows OTP spraying and credential stuffing at the auth layer |

### 2.6 Storage

- Buckets: `avatars` + `groups` public-read (public assets by design),
  `events` private; `minigame_images` **private, participant-gated**
  (`storage_objects_minigame_images_select` / `..._insert` — encrypted
  minigame image ciphertext only, never plaintext/keys); object access governed
  by `storage.objects` RLS policies; event photos served through 1-hour signed
  URLs.
- **Why signed URLs:** private-bucket objects must not be guessable; short
  expiry bounds link sharing. Signing runs through the caller's RLS session,
  so a SELECT policy must match — access control stays in one model.

### 2.7 Audit trail

- Every CLI/admin mutation writes an `admin_audit_log` row
  (`internal/ops/audit.go`); clients have no policy granting read/write on it.
- **Why:** repudiation — shard grants, bans, deletions must be attributable.

### 2.8 Search abuse protection (OWASP API4:2023)

User-search is the one endpoint that lets any authenticated account scan the
user base, so it gets layered resource-consumption controls (API4:
"Unrestricted Resource Consumption"):

| Layer | Control | Why |
|---|---|---|
| Kong route limiter | `rate-limiting` on `/rest/v1/user_search_view`: 120/min per IP (`policy: local`, `limit_by: ip`; plugin enabled in `KONG_PLUGINS`) | Coarse flood guard with standard `RateLimit-*`/`Retry-After` headers; per-IP because all app users share the anon apikey consumer |
| `search_users(p_query)` RPC | SECURITY DEFINER (`130_search/01_search_rpc.sql`): trimmed length ∈ [5, 50] (SR002), 60 searches/rolling-minute per user via atomic `search_rate_limits` upsert (SR001), anon rejected (SR003), LIKE wildcards escaped, caller excluded, LIMIT 20 | Server-side input caps + precise per-user quota; client-side gating (`usernameMinLength`) is bypassable |
| Prefix index | `idx_users_username_prefix` (`username text_pattern_ops`) | Plain-btree indexes cannot serve `ILIKE 'x%'` — without it every search sequential-scanned `users` |

The client maps `SR001`/HTTP 429 to `RateLimitError`
(`lib/core/extensions/error_mapper.dart`). **Deviation note:** direct SELECT
on `user_search_view` stays granted — five non-search surfaces read it
(public profiles, group/event/shard joins, chat sender resolution); the Kong
limiter covers that raw path. Coverage: `test/opt-015-search-rpc.sh`,
pgTAP Section 61. `app_config`-driven generic thresholds remain open (O1).

### 2.9 Attendance codes / dynamic QR (2026-09-08)

The event attendance code is an **authenticator-style time-windowed code**
carried by a **plain rotating QR** on the attendee's own device
(`attendance_code_screen.dart`, route `/qr/:eventId`). Privacy posture:

- **No per-window codes are stored.** `event_code_keys` holds ONE random
  32-byte HMAC secret per (event, attendee), FORCE RLS with **zero client
  policies and zero table grants** — the only handle is the SECURITY DEFINER
  RPC (`get_my_code`). The displayed 24-hex code is a *pure function*
  `left(hex(hmac_sha256("samay.code.v1:<counter>", secret)), 24)` recomputed
  on demand; no code ever lands on disk server-side.
  **Why:** the legacy QR-token surface stored every rotated token (an
  unbounded, replayable row history); derived codes keep the server holding
  only the secret that produces them. That legacy surface was deleted —
  one rotating-code flow remains.
- **Secrets travel only to their owner.** The RPC is own-attendee-gated
  (host/staff membership or a **CONFIRMED** invite — `status IN
  ('accepted','attended')`; a merely-*pending* invitee is `not_invited`, mints
  no code, and is never confirmable); the app holds the secret **in memory
  only** (never Hive/secure-storage-persisted, never logged) and derives codes
  locally. A captured API response yields a secret scoped to one (event, user)
  — it cannot mint codes for other people or events.
- **Codes carry no identity.** A 24-hex code is 96 bits of HMAC output: an
  onlooker who reads someone's screen learns nothing about who they are. The
  code → attendee mapping happens only server-side, inside the host/staff-only
  `validate_code` RPC, recomputed per event (no code→user index exists).
- **Replay is bounded and one-shot.** A code is valid for its 10-s window
  (authenticator semantics, ±1 window clock-skew tolerance) and confirmation
  lands **once** — `event_attendances` is the single-confirmation marker and
  re-scans answer `already_scanned`, so a photographed code cannot double-claim.
- **Revocation kills the code instantly.** Declining an invite deletes the
  invite row; removing staff deletes the host row; both deletions fire the
  code-key purge triggers (`code_key_purge_on_invite_delete` /
  `code_key_purge_on_host_delete`), so a revoked attendee's code stops
  validating the moment their seat is gone (and their secret row is deleted
  with the cascade/event teardown).
- Enumeration surface: `validate_code` is host/staff-only, window-gated,
  and shape-checked (`^[0-9a-f]{24}$`); an unguessable 96-bit code defeats
  brute force within a 10-s window.
- **Confirmed-only membership.** The attendee-side roster opens through the
  security-barrier `event_roster_membership_view`, which projects only
  accepted/attended invites (and host/staff); a pending invitee reads neither
  the organizer roster nor the confirmed roster, and keeps `ei_read_own` for the
  accept/decline card. A confirmation live-flips an open screen via
  `event_attendances` on `supabase_realtime` (REPLICA IDENTITY FULL; delivery
  stays RLS-gated by `ea_read_access`) — the marker is written only by the
  SECURITY DEFINER `validate_code`, so clients cannot forge it.

Coverage: `test/opt-027-events-code.sh`, pgTAP Section 21d. The attendee side
is a rotating QR encoding the current code (derived locally, byte-identical to
`event_code`); host/staff read it with the in-app camera QR scanner
(`qr_scanner_screen.dart`) and confirm via `validate_code`.

---

## 3. Client-side precautions

| Precaution | Why | Where |
|---|---|---|
| Compile-time config via `--dart-define`; `.env` gitignored; nothing bundled as an asset | Runtime-loaded `.env` files ship inside the APK/IPA and are trivially extractable | `lib/core/config/env_config.dart`, Makefile |
| Hive boxes encrypted (AES-256, key in secure storage) | Caches (config, photo URLs, message metadata) otherwise persist unencrypted on disk; key stored beside data = no encryption | `storage_service.dart` |
| Typed `RestClient` filter chain | String-interpolated PostgREST filters were an SQL-injection class risk; typed chain methods make interpolation unreachable by construction | `lib/core/services/rest_client.dart` |
| `InputSanitizer` at every write boundary (trim, control-char strip, NFKC, grapheme-safe caps) | Zero-width/bidi characters enable spoofing; oversized inputs break layouts and DB constraints | `input_sanitizer.dart` (server-side shape CHECKs back it up; the Dart unit suite was deleted 2026-08-31) |
| Client OTP guard (60 s resend cooldown, 5-attempt cap) | UX-level abuse brake; complements (does not replace) server limits | `otp_verification_screen.dart` |
| Ban screen + ban-aware auth state | Banned accounts must visibly lose access even before server-side token enforcement lands | `ban_service.dart`, `auth_guard.dart` |
| Runtime permissions via `permission_handler` | Camera/gallery access without prompting fails silently or violates store policy | qr_scanner/photo flows |
| Crash/error reporting seam (`CrashReporter`) behind `SENTRY_DSN` | Production errors currently invisible beyond local logs; stub until DSN configured | `crash_reporter.dart` |

## 4. Cryptography policy

Approved: X25519 + Ed25519 (E2EE key agreement/signatures), AES-256-GCM
(messages), HKDF-SHA256 with domain-separated `info` strings, SHA-256/512.
Not allowed: MD5/SHA-1, ECB, CBC-without-MAC, RC4/DES/3DES, RSA <2048,
hardcoded key material, custom protocols, nonce reuse. Keys are generated with
CSPRNGs on device and live only in secure storage. Full chat-crypto design:
`docs/security/E2EE-ARCHITECTURE.md`. **Why this list:** everything approved
is a standard, reviewed construction (R4/R5/R2); everything banned has a known
break or a footgun.

## 5. Compliance

- **Peru Ley N° 29733:** privacy policy + terms accepted at signup
  (unchecked boxes), 18+ age gate, in-app deletion flow, anonymizing hard
  delete (daily cron). Law text: https://www.gob.pe/institucion/congreso-de-la-republica/normas-legales/243470-29733
- **Stores:** in-app account deletion (App Store 5.1.1(v)), UGC reporting
  (`reports` table + `reportContent()`), 17+/Mature rating, Data Safety form
  before release, Privacy Policy URL at release.

## 6. Open items (ranked)

These are known gaps, deliberately tracked here — each needs a decision or an
implementation pass; none is silently accepted:

| # | Severity | Item | Why still open |
|---|----------|------|----------------|
| O1 | HIGH → PARTIALLY RESOLVED 2026-08-25 | ~~No Kong rate-limit plugin;~~ `security.*` app_config thresholds unenforced server-side. **Shipped:** Kong `rate-limiting` on the search route + per-user 60/min quota in `search_users()` (§2.8). Still open: Edge-Function-level limits for the remaining endpoints (`EEDG`) and app_config-driven thresholds | Remaining scope blocked on Edge Functions (`EEDG`); GoTrue-level limits + client OTP caps are partial cover |
| O2 | HIGH | API-server admin gate is a static `ADMIN_API_KEY` placeholder | Real JWT/JWKS + `admin_users` required before any deployment |
| O3 | MEDIUM | No certificate pinning / network-security-config | Needs prod domain first |
| O4 | MEDIUM | No screenshot protection (`FLAG_SECURE`) on E2EE surfaces | Trade-off vs. screen-recording UX; revisit before wide E2EE rollout |
| O5 | RESOLVED 2026-08-25 for username/bio: server-side sanitize+validate now lives in the profile RPC family (`create_my_profile`/`update_my_profile`, baseline `020_core/02_users.sql`) + a tombstone-exempt `users_username_shape` CHECK; clients hold NO INSERT/UPDATE on `public.users` at all. Remaining text columns with client writers have RPC setters. Grapheme-vs-code-point note: caps are code points (username ≤64, bio ≤160). | Done — see BACKEND.md §profile RPCs + opt-014 |
| O6 | LOW | Realtime channel-existence enumeration | Row access is RLS-governed; enumeration residual accepted for MVP |
| O7 | LOW | Deep-link invite-token validation depth (`samay://event/{token}`) | Tokens are random UUIDs; add signature/HMAC if abuse appears |
| O8 | LOW | Audit-log append-only enforcement (DB level) | CLI is the only writer today; enforcement matters when second writer appears |
| O9 | LOW | Image-default TABLE grants remain broad (`arwdDxtm`) | Triggers + RLS are the enforcement layer; grant-model cleanup pre-Alpha |
| O10 | LOW | No data-export feature (store-review risk); anon/JWT-secret rotation is an ops action at deploy time | Release-checklist item |

## 7. Secrets hygiene

- **Rule:** no secrets in code, tests, or docs — placeholders only. Local
  values live in gitignored `.env*` files and are the source of truth for
  `tools/check_secrets.sh`, which fails if any local secret value appears in a
  tracked file.
- Service-role keys exist only on machines running the admin CLI/API server
  (R7). Compose defaults are placeholder strings meant to be overridden.
- Dependency CVE watch: subscribe to OSV/NVD/pub.dev/Go-vuln feeds; triage
  SLA — CVSS ≥ 7 patched within 7 days, medium next release, low backlog.
