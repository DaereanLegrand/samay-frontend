# 2026-08-13 — R2 repair sweep: placeholder dead-ends → real flows + crash-recovery banner

Agent: R2 (repair). Scope: replace every "Próximamente"/placeholder dead-end in
the audited screens with REAL functionality, and add the LOG-03 crash-recovery
banner. Built on the LUXE widget tree (`lib/shared/widgets/`).

## What was built

1. **Report action (public_profile_screen.dart)** — the `Reportar` menu item
   opens a `SimpleDialog` with four predefined reasons (Acoso o abuso / Spam /
   Contenido inapropiado / Otro motivo), calls
   `ModerationService.reportContent('user', userId, reason)`
   (`moderationServiceProvider`, signature `(String targetType, String
   targetId, String reason)` — verified, inserts into `reports`), then shows a
   REAL confirmation snackbar (`profileReportSent`) or the mapped error via
   `showAppError`. The `profileReportComingSoon` snackbar is gone; the l10n
   key was deleted from both arbs (grep confirmed it became orphaned).

2. **Settings rows (settings_screen.dart)**:
   - `Notificaciones` → new `NotificationSettingsScreen` with four toggles
     persisted in the encrypted `config_cache` Hive box via a new
     `NotificationPrefsNotifier` (same seam as `ThemeModeNotifier`, I-65).
     Honest footer: "Estas preferencias se guardan en este dispositivo."
   - `Privacidad` → new `PrivacyInfoScreen` (static privacy/terms sections
     reusing the signup-funnel copy keys `authPrivacyPolicy(Subtitle)` /
     `authServiceTerms(Subtitle)` + two new body keys). The funnel's
     `PrivacyTermsScreen` cannot render standalone (requires email/dateOfBirth
     extras and pushes profile-setup), so a standalone info screen was the
     right call.
   - Both rows are `enabled` with real destinations; the `_SettingsTile`
     `enabled` param became dead code and was removed.

3. **Group detail tabs (group_detail_screen.dart)**:
   - Events tab → new `GroupEventsTab` widget: `EventService.listEvents()`
     filtered client-side by `group_id` (events carry the FK — verified in
     `event_service.dart:createEvent`), with real loading/error/empty/list
     states + pull-to-refresh; tapping a row pushes `RoutePaths.eventDetail`.
   - Chat tab → real empty state (E2EE is 1:1-only; group fan-out is E2EE
     §9.6 later work): "Los chats son 1:1 por ahora" +
     "Los chats de grupo se habilitan desde el listado de mensajes."
   - `groupsChatComingSoon` / `groupsEventsComingSoon` keys deleted from both
     arbs (orphaned after the swap).

4. **Crash-recovery banner (LOG-03)** — new `CrashRecoveryBanner`
   (`lib/shared/widgets/`): dismissible banner ("La app se recuperó de un
   cierre inesperado", dismiss reuses `commonOk`). `SamayApp` gains
   `recoveredFromCrash` (const-compatible default false); `main.dart` passes
   `recoverCrashMarker() != null` and the TODO(LOG-03) is removed. Mounted in
   the MaterialApp builder column above the ConnectivityBanner.

## Decisions

- **Persistence**: reused the existing Hive `config_cache` seam instead of
  inventing a new store — `getCachedConfig()/cacheConfig()` already power the
  theme-mode persistence, and `hiveServiceProvider` is test-overridable.
- **Navigation**: new screens are pushed via `MaterialPageRoute` because
  `app_router.dart` is off-limits for R2 (parallel agent owns it); the
  existing rows' `context.push` calls are untouched.
- **Banner flag plumbing**: passed from `main()` (where the marker is
  consumed) as a constructor param — the banner widget itself is
  dumb/`visible`-driven, so it is directly testable.

## Mistakes / gotchas

- **MISTAKE**: In `groups_screens_test.dart` I replaced the leave-group test's
  tail when inserting the new events tests — the closing assertions were
  dropped. Caught via `rg` before running; restored.
- **MISTAKE**: The privacy-body test assertion used lowercase `nunca se
  venden` while the copy starts capitalized (`Nunca`) — `textContaining` is
  case-sensitive. Fixed the expectation.
- **MISTAKE (near-miss)**: `GroupEventsTab._load()` calls `setState`
  synchronously from `initState` — legal in Flutter (element not yet active),
  but kept the redundant initial `setState` guarded by `mounted`.
- The a11y suite pinned the old disabled-placeholder rows (U-26 pin); that
  test was repointed to assert the rows are now enabled + actionable.

## Commands run (reproducibility)

```bash
flutter gen-l10n
dart format <changed files>
flutter analyze          # 0 issues in R2 files; remaining errors are the
                         # parallel agent R1's in-flight files
                         # (minigame_service, events/** , feature_flags,
                         # app_router_test)
flutter test test/features/profile/ test/features/profile_screens_test.dart
flutter test test/features/groups/ test/features/groups_screens_test.dart
flutter test test/features/auth/ test/widget_test.dart test/l10n/l10n_test.dart
flutter test test/accessibility/ test/widgets/ test/features/notifications/
             test/features/friends/ test/features/responsive_test.dart
flutter test test/widgets/crash_recovery_banner_test.dart
             test/features/profile/notification_prefs_provider_test.dart
```

## Test counts

- `test/features/profile/ + profile_screens_test.dart`: 75 passed (3 new
  report-flow tests + 2 settings-row navigation tests + 1 prefs provider test
  file with 5 tests).
- `test/features/groups/ + groups_screens_test.dart`: 68 passed (4 new events
  tab tests).
- `crash_recovery_banner_test.dart`: 5 passed (3 banner-direct + 2 SamayApp
  wiring).
- Full suite: 2184 passed; the 17 failures are ALL in the parallel agent's
  in-flight files (`feature_flags_test.dart`, `app_router_test.dart`) —
  R1 flipped feature flags live mid-edit and its arb keys are not yet
  committed.

## Deviations

- `flutter analyze` cannot reach 0 repo-wide while R1's in-flight edits
  (`minigame_service.dart` syntax error, missing `collage*`/`events*` l10n
  keys, `app_router_test.dart` duplicate import) are uncommitted; R2 files
  report zero issues.
- Per mandate, `lib/features/events/**`, `app_router.dart`, `feature_flags.dart`
  were never touched.

## Placeholder-copy confirmation

`profileReportComingSoon`, `groupsChatComingSoon`, `groupsEventsComingSoon`
have zero references in `lib/` and `test/` (grep). The only remaining
"próximamente"-adjacent copy is the out-of-scope `minigamesDetailComingSoon`
(minigames feature, not in R2's mandate).
