# ANIM-OFF + curl-JWT root-cause fix (RLS view) + code-first auth errors (2026-08-14)

**Branch:** `fixes` · **Worktree:** post-`af52ebf` (uncommitted by user directive)

## 0. Directives follow-up (same session)

- **Playfair italics REMOVED** (user directive): `app_typography.dart` drops
  `fontStyle: FontStyle.italic` from displayLarge/Medium/Small + headlineLarge;
  `VDisplayText` custom-size fallback too. Bold weights unchanged. Chat's
  decryptFailed italic (Inter, semantic marker) kept. Pinned in 7 test files
  (now `isNull`).
- **Skyblue text → white** (user directive): `VDisplayText.rendersWhite()`
  — null or the cyan family render white glyphs (login/feed/party-finder
  heroes); violet/gold/mint/peach keep gradient fills. Cyan icons/aurora/
  dividers untouched.
- **Home-page buttons → BLACK** (user directive): the feed's games cards
  + Party Finder card drop the cyan gradient/glow (`VGlassCard` white-only,
  `glowAlpha: 0`, white icons) — cyan stays only on ambient/rings/dots.
- **Login CTA → BLACK** (user directive): new `VButton.dark` variant
  (`surfaceAlt` black fill, white text, white hairline); the login
  "Iniciar sesión" CTA swapped from the cyan `glowAccent`. Tests: dark
  variant unit test + login-CTA restyle pin.
- **MISTAKE:** a perl mass-edit for the test assertions dropped the
  `reason:` texts on 7 sites — caught by reading the diffs, restored each.
- Also: `user_search_view` gained `bio` (migration `20260815000001`, both
  stacks) — pgTAP mirror + header count (34 migrations) updated; 385/385.
- Validation: analyze 0 · `flutter test` **2227/2227** · pgTAP **385/385**.
- Password restore: tester2/tester3 reset back to `tester123` (they had been
  clobbered to `Pass1234!` during the curl-JWT debugging — MISTAKE).

## 1. ANIM-OFF — all animations deactivated

- `lib/app.dart` — the MaterialApp `builder` now wraps the tree in
  `MediaQuery(copyWith(disableAnimations: true))`. Every motion widget honors
  `MediaQuery.disableAnimationsOf` → static (they already did; the flag now
  fires app-wide).
- `lib/core/theme/app_theme.dart` — new `StaticPageTransitionsBuilder`
  (route rendered with NO transition under reduced motion; Cupertino swipe
  otherwise). Replaces Cupertino on all 6 platforms.
- Zero-duration implicit animations: `v_input.dart` (glass shell/fill),
  `otp_verification_screen.dart` (code-field shell), `attendance_qr_screen.dart`
  (AnimatedSwitcher countdown label).
- New `lib/shared/widgets/v_spinner.dart` — static ring under reduced motion;
  adopted by `VLoadingView`, `VButton`, `_RowSpinner` (requests), chat,
  invite, edit_profile, photo_gallery, qr_scanner.
- Boundary kept: interactive affordances (ink press, snackbars/sheets/dialogs
  entrance, tab swipe) remain — they are functional, not decorative.

## 2. curl test with JWT → ROOT CAUSE of the "Usuario" + missing-friend bugs

Script: `/var/folders/.../curl-jwt-friends.sh` (temp, not committed). Signs in
tester2/tester3 via GoTrue password grant, exercises send → list → resolve →
accept → friends-list-both-sides, prints `error_code` verbatim.

**Finding:** `user_search_view` (security barrier, `20260520000001`) is the
only cross-user read path — `users` is own-row-only since `users_search` was
dropped. The client's `getUserProfile` still read `users` directly → **RLS
returned `[]` for any other user** → `maybeSingle()` → null → the "Usuario"
fallback fired everywhere, and `FriendsListNotifier` silently dropped every
friend. Both reported bugs were this one bug.

**Fix:**
- `user_service.dart` — `getUserProfile`: own row → `users` (full);
  any other user → `user_search_view` (public identity + bio).
- Migration `20260815000001_user_view_bio.sql` (both stacks, byte-identical):
  `user_search_view` gains `bio` (public profile copy; sensitive columns stay
  out). Preserves the block-exclusion + deleted_at filters and the I-32
  hardening (anon REVOKEd — initially I re-granted it; caught via the pgTAP
  anon test, fixed).
- pgTAP `schema_test.sql` columns_are updated; **385/385 pass** on the live DB
  (psql fallback; `supabase db test` hangs on the pg_prove image pull — known).

## 3. Supabase-related catches addressed correctly

- `error_mapper.dart` — AuthException branch rewritten **code-first** per
  https://supabase.com/docs/guides/auth/debugging/error-codes: full mapping
  (`over_*_rate_limit`, `invalid_credentials`, `email_not_confirmed`,
  `email_exists`/`user_already_exists`, `weak_password`, `same_password`,
  `validation_failed`, `otp_expired`/`otp_disabled`, `user_banned`,
  `reauthentication_needed`, `request_timeout`, `bad_jwt`/`no_authorization`/
  `not_admin`/`session_*`/`refresh_token_*`/`user_not_found`, `unexpected_failure`).
  No more blanket `UnauthorizedError` for everything; message heuristics only
  as a last resort for null-code client exceptions.
- Silent `catch (_)` fixed: `feed_screen._openMinigames` (fetch failure
  masqueraded as "No groups yet" → now surfaces `e.toAppError()`);
  `qr_providers` (config fetch now rethrows — consumers are `.valueOrNull`
  safe; `rotate()` logs); `notification_center` realtime subscribe logs;
  `attendance_qr._rotate` logs; `deep_link_handler` token resolution logs.
- No-fallback in friends providers: `ProfileResolutionError` (new sealed
  AppError) thrown instead of "Usuario"/uid-substring/silent-skip in
  `FriendsListNotifier`, `FriendRequestsNotifier`, `BlockedUsersNotifier`;
  `requests_screen` renders `names[...]!`.

## Validation

- `dart analyze` 0 · `flutter test` **2225/2225** · `go test ./...` green ·
  pgTAP **385/385** · migration parity byte-identical · curl-JWT flow green
  (username `tester2` resolves; direct `users` read stays blocked `[]`).

## MISTAKE blocks

- **MISTAKE:** the first migration draft re-granted `user_search_view` SELECT
  to anon (regression of `20260809000002`). Caught by the existing pgTAP
  anon-REVOKE assertion before committing. Fixed in the same migration.
- **MISTAKE:** `supabase db test` hung on the pg_prove image pull — use the
  documented psql fallback (Makefile:680) when the image is stalled.

## Follow-ups

- Friends-list realtime channel + invalidations on friendship mutations
  (approved plan) not in this session — next.
