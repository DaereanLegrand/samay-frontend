# 2026-08-25 — Fake "El código ha expirado" on "Completa tu perfil"

## Report

User report (es): landing on **Completa tu perfil** immediately showed a red
**"El código ha expirado. Solicita uno nuevo."** that was completely fake —
no failed action had just happened on that screen.

## Root cause (two stacked defects)

1. **Trigger — OTP re-submission of a consumed code.**
   `otp_verification_screen.dart` never cleared the code field on SUCCESS and
   had no verified latch. The screen stays mounted (offstage) below the
   pushed age-gate/privacy routes, so a late submit event re-ran
   `verifyOtp` with the already-consumed token. GoTrue answers ANY rejected
   email code with code `otp_expired` (not literally expired ones), so the
   duplicate produced exactly that error — and its catch block ran
   `signOut()`, destroying the just-created session mid-funnel.
2. **Leak — screens rendered the GLOBAL auth error.**
   `profile_setup_screen.dart` (also login + signup contact) bound its field
   `errorText` to `authStateProvider.hasError`. The global AsyncValue
   outlives individual steps, so the stale `otp_expired` rendered the moment
   profile-setup was entered. `/auth/profile-setup` sits under `authPrefix`,
   which `AuthGuard` treats as public, so the user was never bounced out —
   they just sat there staring at the fake error.

## Fix

- New flow-scoped error providers (`lib/features/auth/providers/
  auth_form_errors.dart`): `signupErrorsProvider` (multiple username errors +
  server error) and `loginErrorProvider`. Screens render ONLY these; each
  action captures its own failure right after the await. Entry clears state
  post-frame.
- New pure policy `lib/features/auth/logic/username_policy.dart`: ALL violated
  username rules reported together (specific messages per user directive).
- OTP single-shot latch: `_verified` flag set before navigation + field
  cleared → duplicate submits are impossible.

## Decisions

- Capture-after-await instead of mirroring global state: keeps one source of
  truth for auth while making each screen's error surface strictly scoped in
  time to its own action.
- Empty username reports required AND min-length together (multiple-error
  contract requested by the user).
- The destructive `verifyOtp` catch (`signOut()` on failure) was left as-is:
  correct pre-session safety; the latch removes the only path that abused it.

## MISTAKE blocks

- MISTAKE: wrote `ref.read(provider.notifier).clear()` inside `initState` —
  Riverpod throws "Tried to modify a provider while the widget tree was
  building". Fix: `addPostFrameCallback` for entry-time clears.
- MISTAKE: test fixtures used `'dana'` (4 graphemes) as a valid username —
  below `usernameMinLength = 5`. The silent pre-policy block would have made
  those tests lie; now they use `'sofia'`.
- MISTAKE: `find.widgetWithText(...)` silently skips OFFSTAGE widgets — the
  pushed-over OTP screen is offstage-but-alive, which is exactly why the
  production bug exists. Tests now fire the still-live handler directly.
- MISTAKE: allowlisting `'$usernameMinLength'` inside a const Dart string
  interpolates the symbol — needs `'\$usernameMinLength'` to match scanned
  source text in the l10n guard.

## Commands

```
flutter test test/features/auth/...            # RED → GREEN loop
make check                                     # analyzers + ports + secrets: PASS
make test                                      # 2449 pass / 0 fail + go: green
```

Baseline: README Flutter count 2434 → **2449** (+15 tests).
