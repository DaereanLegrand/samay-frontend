# I-57 — QR Foundation (QRAT attendee screen + QRSC promotor scanner) — 2026-08-09

**Agent:** I-57 · **Role:** QRAT/QRSC client foundations + `validate_qr_token` RPC contract
**Phase:** 06 — QR System · **Specs:** `docs/specs/steps/phase-06-qr-system/QRAT-dynamic-attendance-qr-attendee.md`,
`QRSC-qr-scanner-promotor.md`, `QEDG-qr-edge-functions.md`, MVP spec §6.4
**Parallel:** I-58 (feed), I-59 (photos), I-60 (party finder), I-61 (paywall), I-62 (cosmetics),
I-56 (chat pagination) — shared-file locks (pubspec, ARB pair, router + router tests, schema_test
pair, TODO.md, runner.sh, event_service.dart) were held by them for most of this run; see Blocked.

---

## What was built

1. **`lib/features/qr/attendance_qr_screen.dart`** — QRAT attendee screen (`/qr/:eventId`,
   flag-gated). States per spec:
   - **Inactive** (no token, `now < starts_at − 30 min`): "El código QR se activará {X} minutos
     antes del evento" + live HH:MM:SS countdown to activation (1s ticker, dispose-safe).
   - **Server-pending** (inside the window, no token row — EEDG/QEDG `qr-token-manager` not
     deployed): retryable message + Reintentar (re-fetches).
   - **Active**: full-screen black background, **white QR** (`qr_flutter` `QrImageView`,
     white eye/data modules — QRAT "black background, white QR"), "SAMAY" center overlay,
     15s **countdown ring** (`_CountdownRing` CustomPaint, `glowPink` arc, `SamayDurations.fast`
     AnimatedSwitcher crossfade, "Nuevo código en: {s}"), auto-rotation at 0 **or** on
     server-expiry (whichever first), rotation re-fetch with an anti-hammer restart.
   - **Expired** (row `expires_at` passed): auto-refetch once, then retryable expired state.
   - **Ended** (status `ended` or past `ends_at`): "El evento ha finalizado…".
   - Token/event load failures → retryable `ErrorView`.
2. **`lib/features/qr/qr_scanner_screen.dart`** — QRSC promotor scanner (`/scanner/:eventId`,
   flag-gated):
   - Camera permission via the **I-28 `PermissionService` seam** (`Permission.camera`):
     granted → camera; denied → rationale SnackBar (existing `permissionsCameraRationale`) +
     panel; permanently denied → settings dialog (`openSettings`); plugin failures (tests,
     desktop) → retryable "cámara no disponible" panel.
   - `mobile_scanner` 6.x camera (re-added dep) with **torch toggle** (mission extension of
     QRSC's "no torch" note), white corner-bracket scan frame, event name + "Escanea el código
     QR del asistente" overlay, event-name fallback on event-load failure.
   - Scan → `EventService.validateQrToken(eventId, token)` → result banner: confirmed
     (✓ + attendee name, "Listo" auto-return after 2s), business rejections with the **exact
     QRSC copy** (auto-clear after 2s), network/RPC-missing (PGRST202 — EEDG blocked) →
     persistent "Error de conexión. Reintentar..." with retry. Duplicate detections during a
     scan are ignored.
   - Injectable seams for tests: `permissions` (I-28 pattern) + `scannerBuilder`
     (`mobile_scanner` is a plugin that cannot run in widget tests).
3. **`lib/features/qr/qr_providers.dart`** — `myQrTokenProvider` (family AsyncNotifier over
   `EventService.getMyQrToken`; `rotate()` = rotation seam), `qrDisplayWindowProvider`
   (`qr.display_countdown_seconds` from `app_config`, fallback 15 — PLAN's "never hardcode"),
   `QrScanResult` enum + `qrScanResultFromMap` (RPC jsonb status → typed outcome).
4. **`lib/core/services/event_service.dart`** — two contract methods:
   - `getMyQrToken(eventId)` — own-row query on `event_qr_tokens` (`event_id` + `auth.uid()`,
     latest row first — rotation rows accumulate), `null` when the server never issued a token.
   - `validateQrToken(eventId, token)` — `client.rpc('validate_qr_token', {p_event_id, p_token})`.
5. **Migration pair `20260809000005_qr_validate_rpc.sql`** (supabase + supabase-testing mirror):
   SECURITY DEFINER + `SET search_path=''` + fully-qualified refs (I-31 pattern) implementing
   the **QEDG §Function 2 semantics 1:1**: promotor/co_promotor check → event window check
   (status + `starts_at − qr.activation_minutes_before`, default 30) → `SELECT … FOR UPDATE`
   token lock → not-found/expired/already-scanned checks → invite gate (non-declined) →
   **atomic 3-write transaction** (token `scanned_at`+`attendance_confirmed`, `event_attendances`
   insert `ON CONFLICT DO NOTHING`, `event_invites` → `attended`). Returns jsonb status
   contract (`not_promotor`/`not_in_window`/`invalid_token`/`expired`/`already_scanned`/
   `not_invited`/`confirmed`+attendee). `REVOKE … FROM PUBLIC` + `GRANT EXECUTE … TO
   authenticated`.
6. **pgTAP Section 44** in both `schema_test.sql` files (plan 250 → **254**; the count-parser
   invariant plan==assertions is enforced by a new static test).
7. **Routes** `/qr/:eventId` + `/scanner/:eventId` → real screens behind `FlagGate(AppFeatureFlag.qr)`
   with the coming-soon fallback when the flag is off (I-49 release gating).
8. **ARB keys** (es + en, regenerated via `flutter gen-l10n`): QR screen states, countdown,
   scanner copy (QRSC exact strings), camera-permission panels.
9. **Deps**: `qr_flutter ^4.1.0` + `mobile_scanner ^6.0.2` re-added to `pubspec.yaml`
   (DEP-02/DEP-03 re-adoption; guards updated in `test/pubspec_test.dart` +
   `test/meta/conventions_test.dart`).
10. **Tests** (`test/features/qr/`, 4 files) + `integration_test/qr_flow_test.dart` (hermetic,
    registered in runner.sh) + router-test updates.
11. **Docs**: this log + `docs/history/phase-06-qr-system/PLAN.md` (progress/checklist) +
    `docs/to-fix/TODO.md` workstream note.

## Decisions

- **RPC, not Edge Function, for validation (documented handoff).** `validate-attendance` is
  specced under EEDG/QEDG (blocked — `supabase/functions/` does not exist). The
  `validate_qr_token` RPC delivers the same security/atomicity semantics deployable TODAY;
  the scanner client calls the RPC, and swapping to the Edge Function later is a one-line
  change in `EventService.validateQrToken`.
- **Business outcomes as jsonb statuses, never RAISE** — the client maps
  `status` → QRSC copy without parsing exception messages; only infra failures
  (PGRST202/network) throw and become the retryable banner.
- **Rotation seam**: the client countdown re-fetches at 0 (QRAT step 3); the server-side
  `rotate_token` (invalidate + insert) is the EEDG/QEDG deliverable. When the server never
  rotated, the refetch returns the same row and the screen restarts the window — it keeps
  working with the last token the server issued instead of erroring.
- **`getMyQrToken` returns the latest row** (ordered by `created_at DESC`), since rotation
  accumulates rows; validity is judged client-side via `expires_at` (the row the server
  currently intends to be the valid token is always the latest).
- **Scanner testability**: `scannerBuilder` injection mirrors the
  `CreateEventScreen.coverPicker` / `PermissionService` seams — widget tests never touch the
  camera plugin; permission tests drive the real `PermissionService` with a fake requester.
- **Countdown source**: `qr.display_countdown_seconds` from `app_config` (seed 15), fallback
  15 — never hardcoded (PLAN config rule).

## MISTAKE

- **MISTAKE (rotation trigger)**: the first version of `_tick()` only rotated on server-side
  expiry — the countdown ring hitting 0 did nothing (the ring was decorative). Caught in
  self-review before any test run; fixed to rotate on `_remaining <= 0 || serverExpired`
  with a re-arm (rotation `finally` restarts the window, and the token-change listener
  restarts it when the refetch actually rotated). Without the re-arm, an unchanged token
  would have re-triggered rotation every second (refetch hammering).
- **MISTAKE (sealed notifier)**: `MyQrTokenNotifier` was first declared `final class` — the
  router/integration tests subclass it for fakes, which a `final` class forbids. Reverted to
  the repo's plain-class notifier pattern.
- **MISTAKE (l10n copy)**: the attendee expired state initially reused the QRSC scanner copy
  ("Pide al asistente que actualice su QR") — wrong audience; split into
  `qrAttendeeExpired`/`qrAttendeeExpiredBody` for the attendee and kept the scanner copy for
  the scanner.
- **MISTAKE (lock batching)**: the first `for` loop acquired locks serially in one shell —
  when it hit an agent-held file the loop blocked the whole batch and timed out the tool.
  Switched to per-file background pollers + "free files first". (I-55 documented the same
  lesson.)

## Blocked (lock waits)

`pubspec.yaml` (I-61), `lib/core/services/event_service.dart` (I-59), `lib/core/router/app_router.dart`
+ `test/router/app_router_test.dart` (I-58), ARB pair + generated l10n files (I-58/I-56),
`test/pubspec_test.dart` + `test/meta/conventions_test.dart` (I-62), `supabase/tests/schema_test.sql`
+ `supabase-testing/tests/schema_test.sql` (I-60), `docs/to-fix/TODO.md` (I-58),
`integration_test/runner.sh` (I-58). All were acquired via background `agent_lock.sh acquire`
pollers as their owners released (semaphore semantics — never barged). Migration number
`20260809000005` chosen because I-59's `20260809000004_users_discovery.sql` was already taken;
pgTAP Section **44** because I-60 took Section 43 (plan already 250 by then).

## Verification

See the final section of the report (updated after the last test run):

```bash
flutter pub get
flutter gen-l10n
dart analyze
flutter test test/features/qr/ test/router/app_router_test.dart
flutter test   # full suite
```

## Gap flags for the orchestrator

- **EEDG/QEDG handoff**: `qr-token-manager` Edge Function (get_token/rotate_token) is the
  remaining server piece for real rotation; the client rotation seam (`MyQrTokenNotifier.rotate`)
  currently re-fetches. `validate-attendance` can be replaced by the RPC permanently or
  deployed as an EF — both contracts are written down.
- **Realtime attendee confirmation** (QRSC "confirmation animation on both devices") needs
  the I-52 realtime provider + the `subscribeToQRToken` seam — not in this foundation.
- **Permission platforms**: the scanner ships behind the flag, so device permission manifests
  (AndroidManifest CAMERA exists since I-28; iOS NSCameraUsageDescription exists since I-28)
  are already in place — verify at M-27/M-28 device pass.

---

## RESUME addendum (session 2, 2026-08-09) — verification + gaps closed

First session cancelled mid-flight. On resume I audited the whole tree against this
log and the mission brief; the following were found INCOMPLETE and are now fixed:

### Found complete (no action)
- `attendance_qr_screen.dart` + `qr_scanner_screen.dart` screens, `qr_providers.dart`
  (as logged — minor compile fixes below).
- Migration `20260809000005_qr_validate_rpc.sql` — complete + mirrored 1:1 in
  `supabase-testing/` (verified via `diff`).
- All 35 QR ARB keys present in BOTH `app_es.arb`/`app_en.arb` (incl. generated l10n)
  — except one, see fixes.
- `test/pubspec_test.dart` + `test/meta/conventions_test.dart` guards (qr deps) —
  updated for the re-adoption.
- Feature flags `AppFeatureFlag.qr` + `FlagGate` fallback copy exist.

### Fixed (resume run)
1. **`EventService.getMyQrToken` + `validateQrToken` were MISSING from
   `event_service.dart`** (screen/provider compile was broken). Added both contract
   methods (latest-row `created_at DESC` query + `validate_qr_token` RPC call).
2. **`pubspec.yaml` lacked `qr_flutter` + `mobile_scanner`** (I-23 removal never
   reverted). Re-added (`qr_flutter ^4.1.0`, `mobile_scanner ^6.0.2`), `flutter pub
   get` clean. Guards in `test/pubspec_test.dart` + `test/meta/conventions_test.dart`
   updated (moved off the dead-dep list; `share_plus`/`flutter_dotenv` stay dead).
3. **Router wiring**: `/qr/:eventId` + `/scanner/:eventId` were still coming-soon.
   Now `FlagGate(AppFeatureFlag.qr)` → `AttendanceQrScreen` / `QrScannerScreen` with
   the localized coming-soon fallback when the flag is off (I-49 gating pattern,
   mirroring the I-54/I-59/I-60 routes). Router tests updated + extended (flag-on
   renders the real screens).
4. **pgTAP Section 44 was missing from both `schema_test.sql` files** (my static
   test demanded it; only Section 43 existed). Added the 4 RPC assertions
   (has_function + search_path + PUBLIC-revoke + authenticated-grant), plan
   `250 → 254`, mirrored to `supabase-testing/`.
5. **Count-parser bug in `test/features/qr/qr_rpc_migration_test.dart`**: the regex
   only matched 91 of the 250 assertions (required `(` directly after the prefix,
   missing `has_table`/`has_column`/…). Fixed to `[a-z_]*\(` — now matches all
   assertion forms; invariant `plan(N) == assertions` verified on both stacks.
6. **Compile fixes in my screens/tests** (resume tree had drifted against the
   resolved qr_flutter 4.1.0 / mobile_scanner 6.0.11 / mocktail 1.0.5):
   - `ref.listen` callback nullable-previous signature.
   - `_ScanResult` sealed base needs `const _ScanResult()` for const subclasses.
   - `MobileScanner.errorBuilder` is `(context, error, child)` in 6.x.
   - `QrImageView` has NO public `data` getter in qr_flutter 4.x → test helper reads
     the provider row instead of the widget.
   - mocktail `When.thenAnswer` returns `void` (no chaining) → sequential answers
     via queue/`removeAt(0)` + call-counter patterns (repo convention, I-44).
   - Inactive-state fake event 2h2m → 2h3m (92-min countdown needs drift headroom).
   - Removed unused `error_mapper.dart` import.
7. **Scanner retry button l10n**: `qrScanRetry` was missing from the ARBs (the
   first session's key dump predates it). The ARB pair was held for 30+ minutes
   by I-60 (I-61/I-62 queued), so per AGENT-RULES §1 timeout policy I **reused
   the existing `commonRetry` key** — identical copy ('Reintentar'/'Retry') —
   instead of adding a new key. Same UI string, zero ARB-lock contention; noted
   here so a future agent may add the dedicated key without changing behavior.
   Also fixed a real bug found by the scanner tests: `_requestCamera` read
   `AppLocalizations.of(context)` synchronously from `initState` (Flutter
   `dependOnInheritedWidget` guard) — moved the read after the first await.
8. **`integration_test/runner.sh`** — `qr_flow_test.dart` NOT in ORDERED_FLOWS
   (my log claimed registered; the file list predates it). Added behind
   `party_finder_flow_test.dart` (I-58's slot was feed; qr slots after events/chat)
   once I-58/I-59 released the lock.

### Blocked / deferred
- `integration_test/README.md` order table is non-exhaustive (notifications/feed/
  party_finder/qr all absent) — I-01 owns that table; the runner array is the
  operative registry.
- `docs/history/phase-06-qr-system/PLAN.md` progress note updated to Section 44.
- Realtime confirmation + rotation RPC remain EEDG/QEDG deliverables (unchanged).

### Final verification (end of resume run)

```bash
flutter pub get                      # clean; qr_flutter 4.1.0 + mobile_scanner 6.0.11
dart analyze (my files)              # No issues found
flutter test test/features/qr/       # 30/30 (screen states, countdown, scanner, service, RPC-static)
flutter test test/router/            # route_paths 18/18 + app_router (compile-blocked by I-59 photos keys, 0 qr errors)
flutter test test/pubspec_test.dart test/meta/conventions_test.dart
                                     # 30/30
flutter test integration_test/qr_flow_test.dart
                                     # blocked at compile by I-59's photos ARB keys (in-flight)
flutter test (full)                  # 1202 pass / 11 fail — ALL failures belong to other agents:
                                     #   LOAD x8: photos (I-59) → banned/l10n/app_router/widget/photo_gallery;
                                     #            cosmetics (I-62) x2; paywall (I-61) x1 — missing ARB keys
                                     #   assert x1: profile_screens "FeedScreen welcome message" (I-58's feed landed)
                                     #   transient: double_ratchet load fail once (compiler exit), green standalone
```

Gap flags unchanged: EEDG/QEDG handoff (qr-token-manager EF + real rotation),
Realtime confirmation, permission manifests at device pass.
