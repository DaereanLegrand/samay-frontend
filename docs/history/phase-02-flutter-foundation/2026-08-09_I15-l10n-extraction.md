# 2026-08-09 — I-15: L10N mass extraction (RESUME RUN)

**Agent:** I-15 · **Role:** migrate every remaining hardcoded user-facing string in
`lib/features/**`, `lib/shared/widgets/**` (rank badge + error widgets), and
`lib/core/router/app_router.dart` to typed `AppLocalizations` accessors with zero visual
diff; add the grep-guard test; document; update TODO.md M-15.

---

## 1. State found (interrupted run)

- I-14's l10n infra was **complete**: `l10n.yaml`, `lib/l10n/app_es.arb` + `app_en.arb`
  (229 keys, full parity), generated `app_localizations*.dart`, `app.dart` wired with
  `es` locale + delegates, and the two **demo migrations** (`welcome_screen.dart`,
  `v_coming_soon.dart`) already done.
- The mass extraction had **not started**: `rg "AppLocalizations.of" lib/` hit only the two
  demo files + generated code. No partial edits, no stale I-15 locks, no prior I-15 log.
- 112 `Text('` literals remained across 24 screens/widgets (counted per file).

## 2. What was built

### ARB (locked: lib/l10n/app_es.arb, app_en.arb; regenerated with `flutter gen-l10n`)
- Added 3 missing keys to **both** ARB files (parity enforced by `l10n_test.dart`):
  `profileBlock` (Bloquear/Block), `groupsAbandon` (Abandonar/Leave),
  `groupsNotFound` (No se encontró el grupo / The group was not found).
- 229 → **232 keys**. All parameterized strings use typed placeholders
  (`groupsShardsCount(int)`, `groupsMemberCount(int,int)`, `groupsMyContribution(int)`,
  `groupsLeaderboardSubtitle(int,int)`, `groupsInviteCount(int)`, `groupsInvitedCount(int)`,
  `authOtpSentTo(String)`, `groupsDonateTo(String)`, `authSelectedDate(int,int,int)`,
  `errorsNotFound(String)`).

### Migrated files (lock acquire → edit → release per batch; all verified below)
- **auth/** (6): age_gate, login, otp_verification, privacy_terms, profile_setup,
  signup_contact — incl. dialogs and date picker string via `authSelectedDate(...)`.
- **friends/** (4): blocked_users, friends_list, requests_screen (post-I-20 version,
  incl. `_ActionPair`), search_screen (statuses via `friendsStatus*`).
- **groups/** (7): create_group (limit dialog), donate_shards, group_detail (tabs, popup,
  frozen banner, counts, leave dialog — new `groupsAbandon`), group_members, invite,
  leaderboard, my_groups (tooltip, role-separator row unchanged).
- **profile/** (5): delete_account (dialog), edit_profile, profile_screen (`_BalanceCard`),
  public_profile (menu + 7 snackbars), settings.
- **feed/** (1): feed_screen (`feedBrand/feedWelcome/feedEmpty`).
- **shared/widgets/** (5): rank_badge (labels via `rank*` switch — `_labels` const map
  removed, `label` getter dropped), error_banner, error_view (`retryLabel` now
  `String?` defaulting to `commonRetry`), show_app_error (dialog chrome + `errorsGeneric`
  fallback; `l10n` captured before awaits), route_error_screen (title/message now
  nullable with l10n defaults).
- **router/** (2): app_router.dart (errorBuilder, 3 missing-extra RouteErrorScreens,
  all 13 coming-soon titles/bodies, `_screenForId` error messages, donate 'Grupo'
  fallback → `commonGroup`), main_shell.dart (`MainShell.build` renders tab labels via
  `shell*` keys; `TabItem.label` kept as data keys asserted by main_shell_test).

### Deliberately NOT migrated (documented)
- `lib/core/errors/app_error.dart` + service exception messages + `error_mapper.dart`
  Spanish literals: no `BuildContext` reachable — presentation maps them via
  `toAppError()` at the call site. Documented in the guard test header.
- `MaterialApp.title: 'Samay'` (non-UI, app-title metadata).
- Data values: 'member' role, friendship statuses, tier keys, '?', '#', '@', '·'.

### Tests
- **New** `test/l10n/l10n_extraction_test.dart` — grep-based guard: no Spanish UI
  literal in the three scopes outside the documented allowlist (data values, glyphs,
  numbers; skips imports/comments/log lines/`.select()` queries/interpolations), plus a
  MainShell-l10n seam check.
- **Fixed harnesses** (add `locale: es` + `AppLocalizations` delegates):
  friends/groups/profile `_screens_test.dart`, `error_banner_test`, `error_view_test`,
  `rank_badge_test`, `show_app_error_test`, `main_shell_test`, and the one
  `app_router_test.dart` pump that lacked delegates (groupDetail), plus
  `test/perf/list_view_builder_test.dart` (I-20's file — my change broke it, fixed).

## 3. Commands run (reproducibility)

```bash
export PATH="$PATH:/opt/homebrew/share/flutter/bin"
flutter gen-l10n
dart analyze lib/            # 0 errors
dart analyze                 # 0 errors, 14 info (< 19 baseline, 0 new)
flutter test test/l10n/      # 12/12 pass
flutter test test/router/ test/features/ test/widgets/   # 230/230 pass
flutter test                 # 500 pass / 12 fail — exactly the structure_test baseline (I-47)
```

## 4. Lock evidence

Every edited file was acquired/released with `tools/agent_lock.sh` under `--owner I-15`
(24 lib files, 3 ARB/generated, 11 test files, TODO.md, daily log). Two files
(`group_detail_screen.dart`, `requests_screen.dart`) were briefly blocked by an active
**I-20-listview** session; the locks freed and I-15 acquired them in the background while
doing other batches (no wait time lost, no conflict). `repo-locks/` re-checked clean at
the end.

## 5. Decisions

- **Zero visual diff** is the contract: the es ARB values are byte-identical to the old
  literals, so every Spanish-asserting test passes unchanged.
- `ErrorView.retryLabel` / `RouteErrorScreen.title`/`message` became nullable with
  in-build l10n fallbacks (a const default cannot call `AppLocalizations.of`).
- `RankBadge.label` getter (public API) was removed — only widget rendering used it;
  `rank_badge_test.dart` asserts rendered text only.

## 6. MISTAKE blocks

**MISTAKE (fixed):** I initially called `AppLocalizations.of(context)` *after* an `await`
in `login_screen._login()` → `use_build_context_synchronously`. Fix: capture `l10n` at the
top of async methods before any await (login, otp `_verify`, signup `_signup`, public
profile actions, donate, invite, create group, edit profile, delete account).

**MISTAKE (fixed):** I wrote the guard test with a naive whole-file regex; interpolated
strings with nested quotes (`'...${g['x']}...'`) fragment the match and produced false
positives (multi-line code chunks, import paths, `'createGroup error: $e'` log strings,
`.select('username, bio, ...')` PostgREST column lists). Fixed with line-based scanning:
skip imports/comments/`AppLogger`/`.select()` lines, strip `${...}` interpolations first.
The false positives taught the allowlist shape now documented in the test header.

## 7. Issues found (reported, not fixed)

- **Pre-existing router quirk:** `/event/:inviteToken` is registered after
  `/event/:eventId`, so invite-token URLs resolve to the event-detail coming-soon screen
  ('Evento'). `app_router_test.dart` "resolves to the event detail route" passes *because*
  of this shadowing. Route ordering is out of scope (I-03/H-02 territory).
- **Pre-existing:** `lib/core/services/shards_service.dart:1` unused import (warning).
- `lib/core/router/main_shell.dart` `TabItem.label` data keys still carry Spanish values
  ('Feed'..'Perfil'); rendered text is localized. If a future agent wants the keys
  themselves non-Spanish, main_shell_test must be updated in the same change.
- docs/to-fix/categories/05-LOCALIZATION.md (D-03-owned) still shows L10N-01/05/07 as
  open — TODO.md M-15 was updated per mission; category file refresh is D-03's.
