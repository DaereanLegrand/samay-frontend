# E2EE auth-lifecycle hooks: publish on profile creation + heal on session restore (2026-08-15)

**Branch:** `fixes` · **Worktree:** post-`af52ebf` (uncommitted by user directive)

## Symptom (user report)

"Sending a message fails, loads for a long time and then says 'No se pudo enviar el
mensaje'" (`chatSendError`).

## Root cause

E2EE prekey bundles were only published **lazily at send time**
(`chat_service.dart:102-104`, first send per process). The designed fix —
E2EE §12.2 step 4 "publish on `createProfile`" — was a documented, never-wired
follow-up; `handleMissingSession` existed on `SupabaseE2eePrekeyService` but was
called nowhere in production code.

So any account that never sent a message has **no `e2ee_identity_keys` row**.
When Alice sends to such a peer, `fetch_prekey_bundle` returns NULL →
`E2eeSession._ensureSessionReady` throws (`session.dart:277-280`) → send fails.
Chicken-and-egg: the first message between two fresh accounts could never succeed.

**Verified live** (remote prod `https://samay-api.qallariy.lat`, read-only):
`tester2` has a bundle (100 OPKs); `tester` and `tester3` have **no row at all**.

The "long time" is the first-send bootstrap: `publishAll()` generates **100
one-time prekeys** via pure-Dart `package:cryptography` (no `cryptography_flutter`
native bindings in `pubspec.yaml`) plus several remote round-trips before the
null-bundle throw.

## What was built

1. **`E2eePrekeyService` interface** (`lib/crypto/interfaces.dart`) — added
   `handleMissingSession()` ("publish only when nothing is published yet"),
   documented as the §12.2 step 4 auth-lifecycle hook. `@override` added on the
   existing concrete implementation; test fake updated.
2. **`AuthNotifier._ensureE2eeKeysPublished({force})`** (`auth_provider.dart`) —
   best-effort by design (catch + log; a publish failure must never block auth;
   the send-time bootstrap stays as a backstop and the next restore retries):
   - `createProfile` → `publishAll()` **after** the `users` row insert (FK
     `e2ee_identity_keys.user_id → users(id)`), **before** `hasProfile` flips.
   - session restore (`_resolveInitialState`) and `signedIn`/`initialSession`
     auth events → `handleMissingSession()` — heals legacy accounts (tester,
     tester3, and any account created before this hook) on next sign-in.
3. **Wipe on sign-out/delete unchanged** (`_wipeE2eeMaterial`) — §7.6.

## Tests

- `test/providers/auth_provider_test.dart` +4:
  - createProfile publishes the bundle after the profile row (`publishAll` ×1);
  - publish failure does not fail profile creation (best-effort);
  - session restore calls `handleMissingSession` (legacy heal; `publishAll`
    never called on restore);
  - restore heal failure never breaks auth (stays put).
  - Test container helper now stubs `e2eePrekeyServiceProvider` (no-op) so the
    heal/publish calls are deterministic and zero-network.
- `test/features/chat/chat_e2ee_test.dart` +1 — the pinned regression: two
  FRESH accounts (server prekeys cleared), both "create profiles" via
  `handleMissingSession` → first message initiates, peer decrypts, reply
  decrypts (real crypto over the fake server).
- `test/crypto/session_test.dart` — `_FakePrekeyServer` gains
  `handleMissingSession` (publish-when-missing).
- Service-level `handleMissingSession` (publish only when missing) already
  covered by `test/crypto/e2ee_prekey_service_test.dart:274-303`.

## Validation

- `dart analyze` **0** · `flutter test` **2238/2238** (was 2233; +5 new).

## Decisions

- **Best-effort publish** in auth: profile creation must not fail because key
  publishing does. Heal-on-restore retries it; send-time bootstrap is the
  final backstop. All three layers make the guarantee idempotent.
- **`publishAll` at createProfile, `handleMissingSession` on restore**: the
  row cannot exist at profile creation (skips the extra existence SELECT);
  restore must not rewrite a healthy row (idempotent heal).
- Interface method added to `E2eePrekeyService` (not just the concrete class):
  auth depends on the contract, not the Supabase implementation.

## Follow-ups (unchanged)

- Prekey-fetch rate limit (`prekey_fetch_log`) stays deferred to S-10.
- Group fan-out (§9.6), media encryption (type 0x04), Sealed Sender — post-MVP.

## Repro for the live stack

Sign in with BOTH tester accounts on the new build once (each publishes its
bundle), then the first message succeeds in both directions. Accounts that
never open the app again remain unreachable (server cannot generate client
keys — that is the E2EE point).
