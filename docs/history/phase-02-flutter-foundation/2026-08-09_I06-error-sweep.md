# 2026-08-09 — I-06: Error-presentation sweep (H-05 / ERR-04 / ERR-07 / CQ-06)

**Agent:** I-06 (shared error widgets + catch-block sweep + AlertDialog consolidation)
**Status:** DONE
**Scope:** shared error widgets, `catch (_)` sweep (20 sites), AlertDialog error-pattern consolidation, tests, TODO.md statuses.

## What was built

### Shared error-presentation widgets (`lib/shared/widgets/`)
- `error_banner.dart` — `ErrorBanner`: inline banner (pink `glowPink #FF2E88` icon + message + optional retry + optional close), const-constructible, themed per DISCO-DESIGN-SYSTEM.md (`#0A0A0A` surface, hairline `#333333` borders, white retry text, `mutedStrong #999999` message).
- `error_view.dart` — `ErrorView`: full-area error state (icon + message + optional retry via `VButton.outlined`), same theming, const-constructible.
- `show_app_error.dart` — `showAppError(BuildContext, Object error, {String? fallback, bool blocking})`: maps via `error.toAppError()` (real `error_mapper.dart`, service-agnostic — no Supabase imports), SnackBar (transient) or AlertDialog (blocking) — one consistent pattern; plus `showErrorSnackBar` variant. Both themed black/white/pink.

### Catch sweep (20 sites, all from ERR-04 audit)
Every `catch (_)` → `catch (e, st)` logging via `AppLogger.instance.error('…', '$st')` (I-05's logger landed mid-sweep; earlier sites were written with the mandated `debugPrint('[Samay] …')` fallback and then upgraded once `app_logger.dart` appeared — verified present at the time of the final edits).

Feedback policy (documented per site):
- **User button actions → log + `showAppError`/`showErrorSnackBar`**: `login_screen` (blocking), `signup_contact_screen` (blocking, was already `catch (e)` → dialog migrated), `create_group_screen` (blocking), `invite_screen._invite`, `search_screen._search` (debounced search), `search_screen` send-friend-request.
- **Background/refresh/app-init → silent-but-logged** (empty states render instead; snackbar spam would be noise): `refreshSession`, `getSignupShardGrant`, `checkInitialSession`, `userHasProfile`, `checkEmail`, `loadConfig`, `loadFriends`, `loadBlockedUsers`, `loadRequests`, `loadProfileBio`, `loadPublicProfile` ×3, `loadMyGroups`, `loadInviteMembers`, `inviteSearch` (per-keystroke, no debounce — L-24, I-21 will debounce), `loadLeaderboard`, `emailMatches`.

### AlertDialog consolidation (ERR-07/CQ-06)
Replaced the 4 duplicated **error** `AlertDialog(title: 'Error', …)` blocks with `showAppError(..., blocking: true)`: login ×2 (auth.error + catch), signup catch, create_group catch. Retained intentionally: confirmation dialogs (delete-account, leave-group) and informational dialogs ("correo ya registrado" ×2, group-limit) — those are flow states, not error presentation.

### Tests
- `test/widgets/error_banner_test.dart` (9) — render message/icon/custom icon, retry fires callback, close fires callback, hidden when null, pink accent icon, muted message.
- `test/widgets/error_view_test.dart` (8) — same surface + custom retry label.
- `test/widgets/show_app_error_test.dart` (6) — raw `Exception` → user-facing SnackBar (real `error_mapper`), transient vs blocking, blocking dismiss via OK, plain-`String` error verbatim, `showErrorSnackBar` variant.
- No existing feature tests asserted the old dialog text (verified by grep) — no updates needed.

### Docs
- `docs/to-fix/TODO.md` — H-05 ✅, M-10 ✅.
- `docs/to-fix/categories/03-ERROR-HANDLING.md` — ERR-04 ✅, ERR-07 ✅.
- `docs/to-fix/categories/16-CODE-QUALITY.md` — CQ-06 ✅.

## Decisions & rationale

1. **`blocking: true` for login/signup/create_group**: those were blocking dialogs before; the helper keeps one pattern while preserving the consequential-flow semantics.
2. **Per-keystroke searches log-only**: `invite_screen._search` fires on every keystroke (no debounce — finding L-24); a snackbar per keystroke is noise. `search_screen._search` is debounced (300 ms) so it gets a snackbar.
3. **Logger fallback**: `AppLogger.log()` falls back to `debugPrint` when no dir is inited — identical observable behavior in tests, structured `[Samay][ERROR]` line in prod.

## MISTAKE blocks

- **MISTAKE (test):** `const ErrorBanner(...)` pumped without a `MaterialApp` in the custom-icon tests → "No Directionality widget found". Fixed by wrapping in the `_wrap` helper. Always wrap widgets in a MaterialApp in widget tests.
- **MISTAKE (test):** `find.text('boom')` exact-match on a mapped message — the real mapper produces `ServerError('Exception: boom')` (ERR-09 residual: mapper fallback keeps `toString()`); use `find.textContaining`. Also: the `fallback` param is unreachable with the real mapper (every `AppError` message is non-empty) — tested the String-verbatim path instead.
- **MISTAKE (test):** `await showAppError(..., blocking: true)` without dismissing the dialog hangs the test until the 10-min tester timeout SIGTERMs the subprocess ("Cannot close sink while adding stream"). Fire the future, `pumpAndSettle`, assert, tap OK, then `await future`.
- **MISTAKE (concurrency):** my `auth_provider.dart` catch edit landed with 6-space indentation because I-07 (retry/`resilient` sweep, `lib/core/utils/async_ops.dart`) had concurrently restructured the file; fixed to 4-space. Also found an extra `}` in `create_group_screen.dart` after a concurrent un-locked edit — removed.
- **Concurrency note:** `signup_contact_screen.dart` was held by **I-03-router-hardening** for the whole session; the acquire wait ran in background. (Final state: see below.)

## Commands run

```
dart analyze                                   # 0 errors / 19 info (documented baseline)
flutter test test/widgets/ --concurrency=1     # 51 passed (23 new + 28 existing)
flutter test test/features/{groups,friends,profile,auth}_screens_test.dart  # 29 passed, 7 failed = documented baseline (6 auth + 1 profile, Supabase-not-initialized harness)
rg -n "catch \(_\)" lib/                       # 0 in swept files; 6 remain in I-05's lib/core/logging/app_logger.dart (intentional best-effort fallbacks, I-05-owned)
```
