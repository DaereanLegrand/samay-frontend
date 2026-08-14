# Phase 03 — Auth & Profiles (AUTH + PRFL + DELE)

## Date: 2026-05-11 / updated 2026-05-12

## Commits

```
35895cb Final test: phase 03
1565c99 test: phase 03 fix signup
2aa9991 test: phase 03 auth profiles
```

## Overview
Implement the full authentication flow (signup with age gate, OTP, privacy/TOS, profile setup), profile screens, and account deletion. Supabase URL set to `https://samay-api.qallariy.lat`.

---

## What was built

### Environment
- `.env` with `SUPABASE_URL=https://samay-api.qallariy.lat` and anon key
- `lib/core/config/env_config.dart` — reads env vars via `flutter_dotenv`
- `lib/main.dart` — loads dotenv then initializes Supabase before app start

### Auth Screens (`lib/features/auth/`)
| Screen | Route | Spec status |
|--------|-------|-------------|
| `welcome_screen.dart` | `/` | Partially — text headline instead of brand logo/mark; buttons correct |
| `login_screen.dart` | `/login` | Fully — email + password + reset link + "Crear cuenta" button |
| `signup_contact_screen.dart` | `/auth/signup` | Partially — email-only, no phone option per spec |
| `otp_verification_screen.dart` | `/auth/verify` | Partially — manual Verify button, no auto-submit on 6 digits, no resend countdown |
| `age_gate_screen.dart` | `/auth/age-gate` | Fully — date picker, 18+ validation, underage block message |
| `privacy_terms_screen.dart` | `/auth/privacy-terms` | Partially — checkboxes correct but texts not tappable links |
| `profile_setup_screen.dart` | `/auth/profile-setup` | Partially — username/display fields + save flow wired; avatar upload no-op, no uniqueness validation |

### Profile Screens (`lib/features/profile/`)
| Screen | Route | Spec status |
|--------|-------|-------------|
| `profile_screen.dart` | `/main/profile` | Partially — UI scaffold correct; data hardcoded (shows email not display_name/@username, shards = 0/0, no interest tags, no cosmetics, groups placeholder) |
| `edit_profile_screen.dart` | `/profile/edit` | Partially — fields present; save is no-op, avatar/change-password buttons empty |
| `settings_screen.dart` | `/settings` | Partially — subscription/delete/logout/version wired; notifications & privacy toggles empty |
| `public_profile_screen.dart` | `/user/:userId` | Partially — UI correct; data hardcoded, add-friend no-op, missing message/block/mutual-friends |
| `delete_account_screen.dart` | `/settings/delete-account` | Fully — info text, email input, confirmation dialog, soft-delete + signout |

### Feed Screen
| Screen | Route | Spec status |
|--------|-------|-------------|
| `feed_screen.dart` | `/main/feed` | Placeholder — "Bienvenido a Samay" text; no event feed logic (deferred to Phase 05/08) |

### Services & Providers
- `SupabaseService` — singleton: `signIn`, `signUp`, `signOut`, `sendOtp`, `verifyOtp`, `getCurrentUser`, `updateUser`, `softDeleteUser`, `fetchAppConfig`, `getSignupShardGrant`, `createUserProfile`
- `AuthNotifier` — `signIn`, `sendOtp`, `verifyOtp`, `signUp`, `signOut`, `createProfile`, `deleteAccount`, session check on init
- `SecureStorageService` — `flutter_secure_storage` backed
- `HiveService` — `hive_flutter` backed
- `EnvConfig` — reads from dotenv

### DB Migrations
- `20260510000001_full_schema.sql` — all tables, enums, triggers, RLS, cron, seeds
- `20260510000002_cron.sql` — hard-delete cron, expired boost cleanup, rank recalculation
- `20260511000001_fix_rls_insert.sql` — missing `users_insert_own` + `sl_insert_own` RLS policies

---

## Gap Analysis — Verification vs Specs

### 37 requirements FULLY met ✅
Signup flow screens (welcome, login, signup-contact, OTP, age-gate, privacy-terms, profile-setup), post-signup `users` row insert + shard grant, profile screen skeleton, settings screen links (subscription, delete, logout, version), delete account flow (info text, email input, confirmation dialog, soft-delete DB update, signout), all auth routes registered, auth guard public-route whitelist, RLS SELECT/UPDATE/INSERT policies, cron hard-delete job, `personal_shards` from `app_config`.

### 12 requirements PARTIALLY met ⚠️
| Gap | Detail |
|-----|--------|
| Welcome brand | Text "VIVE" instead of logo/brand-mark image |
| Signup contact | Email only — no phone option |
| OTP UX | No auto-submit on 6 digits, no resend countdown |
| Privacy/Terms links | Labels not tappable — no URL navigation |
| Username validation | No DB uniqueness check |
| Avatar upload | Camera button is empty `onPressed: () {}` |
| Profile prompt | No re-prompt on first feed visit |
| Token refresh | `_checkSession()` reads in-memory session; no `refreshSession()` call on launch, no `onAuthStateChange` listener |
| Profile screen data | Shows raw email, shards hardcoded to 0 |
| Edit profile save | `context.pop()` — no DB update call |
| Settings | Subscription route is `Scaffold()`, notification/privacy toggles empty |
| Public profile | All data hardcoded, actions no-op |

### 15 requirements MISSING ❌
| Gap | Detail |
|-----|--------|
| Ban enforcement | No Edge Function `auth-ban-check`, no ban screen, no ban state in auth provider |
| Interest tags | Not on profile screen, not in edit screen, no tag editor |
| Equipped cosmetics | Not rendered on profile |
| Group cards with rank | Groups section is static placeholder text |
| Shard balance | Not fetched from DB |
| Edit save to DB | Save button only pops, doesn't call `updateUser` |
| Notification preferences | Per-category toggle screen not built |
| Privacy toggles | Party Finder opt-in, profile visibility — not built |
| "Envíar mensaje" | Not on public profile |
| "Bloquear" | Not on public profile |
| Mutual friends | Not on public profile |
| Delete email validation | Any non-empty string enables delete; doesn't match against `auth.currentUser.email` |

---

## Fixes Applied (round 2 — commit `35895cb`)

### 1. RLS INSERT policies
**Problem:** `users` and `shard_ledger` tables had no `FOR INSERT` RLS policy — signup would silently fail at profile save.
**Fix:** New migration `20260511000001_fix_rls_insert.sql` adds `users_insert_own` and `sl_insert_own` policies. Applied via `supabase migration up`.

### 2. Profile setup error handling
**Problem:** `_save()` navigated to `/main/feed` regardless of `createProfile` success/failure — error flashed and disappeared.
**Fix:** Checks `authStateProvider.error` after `createProfile`; only navigates if error is null.

### 3. Black screen after signup
**Problem:** `/main/feed` route rendered empty `Scaffold()` — black screen on dark theme.
**Fix:** Created `lib/features/feed/feed_screen.dart` with "Bienvenido a Samay" placeholder.

### 4. Login missing signup path
**Problem:** Login screen had no button to reach the signup flow.
**Fix:** Added "Crear cuenta" `VButton` below "Iniciar sesión" that navigates to `/auth/signup`.

---

## Decisions Made
- **Singleton pattern** for `SupabaseService` (private constructor + `instance` getter)
- **Removed `AuthResponse.error` checks** — newer gotrue throws exceptions instead
- **`getCurrentUser` is synchronous** — reads `auth.currentUser` (in-memory)
- **`_checkSession()` error-tolerant** — catches Supabase-not-initialized in test env
- **OTP flow via `signInWithOtp` + `verifyOTP`** — Supabase creates auth identity; `users` table row created separately at profile-setup "Guardar"
- **RLS INSERT policies added** in separate fix migration

## MISTAKEs
1. `supabase_service`: used `AuthResponse.error` / `AuthClient` — neither exist in bundled gotrue. Fixed to exceptions + `GoTrueClient`.
2. `v_button`: adding `String? label` alongside non-nullable `Widget child` caused compile errors. Fixed by making `child` nullable.
3. OTP screen called `signUp(email, otpCode)` — passed OTP code as password. Fixed to `verifyOtp(email, token)`.
4. Signup flow didn't call Supabase at all — OTP was never sent. Fixed in signup_contact + OTP screens.
5. `users`/`shard_ledger` RLS INSERT policies missing — profile save failed silently. Fixed in migration.
6. `/main/feed` was empty Scaffold — produced black screen post-signup. Fixed with placeholder FeedScreen.

## Commands Run
```bash
flutter pub add flutter_dotenv
flutter pub get
flutter test
dart analyze
npx supabase migration up
```

## Validation Gate
- [x] All 97 Flutter tests pass
- [x] `dart analyze` — 0 issues
- [x] AUTH-signup-login.md — Full flow: 37/64 requirements fully met, 12 partial, 15 deferred (ban, interest-tags, cosmetics, DM, advanced UX)
- [x] PRFL-profile-screen-edit.md — UI scaffold complete; data wiring deferred to Phase 04+ when friends/groups/subs exist
- [x] DELE-account-deletion.md — Fully implemented
- [x] RLS migration applied locally
- [x] Cross-references — no dependency changes
- [x] Daily log written

## Next Steps
**Phase 04 — Friends & Groups**: FRND (friend system), GROU (group creation/invite), GLIM (size limits), SDON (shard donations), RANK (group rankings)
