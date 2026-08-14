# I-54 — ECRT Event Creation Flow (foundation)

**Date:** 2026-08-09
**Agent:** I-54-event-create
**Phase:** 05 — Events (`docs/specs/steps/phase-05-events/ECRT-event-creation-flow.md`)

## What was built

- **`lib/features/events/event_form_data.dart`** — typed, immutable form state
  for the ECRT wizard: `EventType` (casual/juerga/tono with PostgREST wire
  values), `EventVisibility` (public/group), `EventJoinMode` (open/approval),
  `EventRemainderAction` (return/redistribute) and `EventFormData` (name,
  description, type, startsAt, endsAt, locationName, visibility, groupId,
  joinMode, preshardsPool, preshardsCapPerUser, remainderAction,
  juergaLocationConfirmed) with `copyWith` (sentinel-based null clearing),
  `sanitized()` (InputSanitizer caps), `validate()` → `List<EventFormError>`
  and `toPayload()` matching `EventService.createEvent`'s insert shape.
- **`lib/features/events/create_event_screen.dart`** — `ConsumerStatefulWidget`
  single-scroll form (visual polish = U-12): cover picker (PermissionService +
  ImageProcessor via `MediaService.uploadEventCover`), VInput name/description/
  location, VChip type selector with per-type descriptions, locale-aware
  date/time pickers (`MaterialLocalizations.formatFullDate` +
  `TimeOfDay.format`), visibility toggle, myGroups dropdown (`groupService
  .getMyGroups()`, shown only when group-scoped), join-mode chips (public
  only), Juerga location warning dialog (ECRT step 4 — explicit confirm,
  cancel reverts the type), preshards section (Juerga/Tono only: pool input,
  optional cap input, remainder-action chips + dynamic-QR hint), submit →
  upload cover first → `createEvent` → `context.push(eventDetail)`.
- **`lib/core/services/media_service.dart`** — added `uploadEventCover`
  (events bucket, `event_covers/<ts>.png`, same compress path as
  `uploadGroupCover`). ECRT's `events/{event_id}/cover` layout is impossible
  from the creation form (event_id is generated server-side by `createEvent`),
  so the cover uploads **before** the insert and its public URL is passed as
  `cover_url` (documented in the method doc).
- **`lib/core/router/app_router.dart`** — `/group/:groupId/create-event` now
  builds `CreateEventScreen(groupId: …)` instead of `VComingSoonScreen`
  (group-scoped prefill, per ECRT "create from group detail").
- **ARB (es/en)** — 37 new `events*` keys (labels, type descriptions, juerga
  warning, preshards section, validation messages).

## Decisions

1. **Route: no standalone `/event/create`.** The ECRT spec creates events from
   group detail; `/event/:eventId` is already registered and I-55 owns EDET.
   Registering `/event/create` would require it to be listed *before*
   `/event/:eventId` (go_router matches same-prefix patterns in registration
   order) — a silent-shadowing trap for I-55. Public events are still
   creatable from the group route via the visibility toggle (payload drops
   `group_id`). **If a public entry point is ever needed, register
   `RoutePaths.eventCreate` BEFORE the `eventDetail` route** (see the
   `RoutePaths.createGroupEvent` comment in `app_router.dart`; I-55 also left
   a matching NOTE above the `eventDetail` route).
2. **Remainder action rendered as single-select VChips, not `RadioListTile`.**
   Same semantics as a radio group; `RadioListTile.groupValue/onChanged` are
   deprecated on Flutter 3.44 (RadioGroup migration) and VChips match the
   design system (§5.4) used by every other selector on the screen.
3. **Route gated on `AppFeatureFlag.events` (dark-first).** I-49's flag system
   (`lib/core/feature_flags.dart`: `FlagGate`, `featureFlagsProvider`) landed
   *while I-54 was in flight* — the mission's "check feature_flags state; if
   flag disabled, keep coming-soon" therefore applies: the route is wrapped in
   `FlagGate(flag: AppFeatureFlag.events, child: CreateEventScreen(...))` with
   a **custom fallback** carrying the previous `comingSoonCreateEvent*` copy
   (zero visual diff when disabled; the default flag fallback would have
   swapped the title from "Crear evento" to "Eventos" and broken the router
   test's text assertion).
4. **`event_service.createEvent` verified against the spec — no changes
   needed.** The 3-table insert (events + event_promotores + chats), invite
   token generation, `dynamic_qr_enabled = pool > 0` and `status = upcoming`
   all match ECRT step 7. Gap: step 7's daily-limit check (from
   `app_config.events.*_daily_limit`) and step 6 (invite promotores) are NOT
   implemented — tracked for I-55/EINV/EEDG.

## Files modified (lock evidence)

| File | Lock |
|------|------|
| `lib/features/events/event_form_data.dart` (new) | ACQUIRED by I-54-event-create |
| `lib/features/events/create_event_screen.dart` (new) | ACQUIRED by I-54-event-create |
| `lib/core/services/media_service.dart` | ACQUIRED by I-54-event-create |
| `lib/core/router/app_router.dart` | ACQUIRED by I-54-event-create (waited out I-53/I-55) |
| `lib/l10n/app_es.arb` / `app_en.arb` (+ regenerated `app_localizations*.dart`) | ACQUIRED by I-54-event-create |
| `test/features/events/create_event_test.dart` (new) | ACQUIRED by I-54-event-create |
| `test/services/media_service_test.dart` | ACQUIRED by I-54-event-create |
| `test/router/app_router_test.dart` | ACQUIRED by I-54-event-create (waited out I-55) |
| `test/perf/list_view_builder_test.dart` (allowlist entry) | ACQUIRED by I-54-event-create |
| `docs/history/phase-05-events/PLAN.md` | edited while free; I-55 acquired it later (same tree, no conflict) |
| `docs/to-fix/TODO.md` | ACQUIRED by I-54-event-create |
| this log | ACQUIRED by I-54-event-create |

All locks released after edits (see `tools/agent_lock.sh list`).

## Tests

- `test/features/events/create_event_test.dart` (new): EventFormData
  validation (name required, ends>starts, casual pool zero, juerga confirm,
  group/join-mode requirements), payload contract (casual pool forced 0,
  group → join_mode null, ISO dates, wires), and widget tests (form skeleton,
  juerga warning dialog confirm/cancel, preshards section on juerga/tono only,
  group dropdown via myGroups, route prefill, submit → createEvent payload →
  navigation to `/event/:id`, cover upload before create, empty-name snackbar
  with no service call).
- `test/services/media_service_test.dart` — `uploadEventCover` group
  (compress / passthrough / public URL), mirroring `uploadGroupCover`.
- `test/router/app_router_test.dart` — `createGroupEvent` moved from
  coming-soon to screen-resolution coverage (flag-on variant with
  `AppFeatureFlags(events: true)`); default-flags coming-soon assertions kept.
- `test/perf/list_view_builder_test.dart` — justified allowlist entry for the
  fixed-content creation form (PERF-01/H-27 guard).

**Final verification (2026-08-09):** `dart analyze` → **0 issues** ·
`flutter test` → **1160/1160 passed, 0 failed** (full suite, incl. I-55's
`event_detail_test.dart`, router, l10n, services, perf guard).

**Commands:**
```bash
/opt/homebrew/share/flutter/bin/flutter gen-l10n
/opt/homebrew/share/flutter/bin/dart analyze
/opt/homebrew/share/flutter/bin/flutter test test/features/events/ \
  test/router/app_router_test.dart test/l10n/ test/services/media_service_test.dart
/opt/homebrew/share/flutter/bin/flutter test   # full suite
```

## Issues found / notes

- **Route ordering trap documented** (decision 1) — I-55 must not add
  `/event/create` after `/event/:eventId`.
- `createEvent` **returns** `{'id', 'invite_token'}` — the screen navigates
  with `id`; the static QR (`samay://event/{invite_token}`) is EINV's scope.
- Daily event-creation limit + promotor invite step remain unimplemented
  (spec steps 6-7) — report to orchestrator for I-55/EEDG.
- `events` bucket is assumed to exist for cover uploads (same bucket already
  used by `uploadEventPhoto`).
