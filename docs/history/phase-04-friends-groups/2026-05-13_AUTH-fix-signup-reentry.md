# Auth Fix: Half-Registration Re-entry & SECURITY DEFINER Removal

## Summary

Fixed bug where half-registered user re-registering with a new password kept the old password active. Removed SECURITY DEFINER from `handle_signup` RPC.

## Problem

1. User half-registers (enters email + "password1", verifies OTP, closes app before profile creation)
2. User re-registers with same email + "password2"
3. Old `handle_signup` RPC (SECURITY DEFINER) tried to delete old `auth.users` record, but either failed silently or didn't propagate properly
4. Result: "password2" didn't work, "password1" still worked

## Solution

Replaced the SECURITY DEFINER `handle_signup` RPC (which queried/deleted from `auth.users`) with a `public.signup_tracker` table that tracks signup completion status entirely within the `public` schema.

### No SECURITY DEFINER needed because:
- `signup_tracker` is in `public` schema with permissive RLS (anyone can CRUD, no auth required during signup)
- We never touch `auth.users` directly
- The OTP flow naturally handles re-registration: OTP verification logs into the existing auth user, then `updateUser` changes the password on that user

### New approach:
- Before OTP: query `signup_tracker` for the email
  - No row → 'signup' (fresh registration)
  - `profile_created=false` → delete row, return 'signup' (incomplete, start fresh)
  - `profile_created=true` → 'exists' (block re-registration)
- After OTP sent: insert `signup_tracker(email, profile_created=false)`
- After profile created: `upsert signup_tracker(email, profile_created=true)`
- After OTP verification: check `hasProfile` — if true, fully registered user, show error + sign out

### Key insight:
Re-registration with the same email works because Supabase OTP sends to the existing user. After OTP verification, the user is logged into their existing auth user (with the old password). `updateUser(password: "password2")` then changes the password on that user. No need to delete the old auth user.

## Files Changed

### New:
- `supabase/migrations/20260513000002_fix_signup_tracker.sql` — drops SECURITY DEFINER RPC, creates `signup_tracker` table with RLS

### Modified:
- `lib/core/services/supabase_service.dart` — replaced RPC-based `checkSignupEmail` with `signup_tracker` query; added `upsertSignupTracker`; mark signup complete in `createUserProfile`
- `lib/core/providers/auth_provider.dart` — track signup start in `sendOtp`
- `lib/features/auth/otp_verification_screen.dart` — check `hasProfile` after OTP verify, block fully registered users
- `lib/core/router/auth_guard.dart` — redirect no-profile users to `/auth/signup` (instead of `/auth/age-gate`) so they can re-register

## Validation

- `dart analyze lib/` — only 19 pre-existing info-level warnings (no errors)
- `flutter test` — 121 tests pass
- No references to `handle_signup` RPC remain in Dart code
- The only remaining RPC call is `donate_shards_to_group` (unrelated to auth)
