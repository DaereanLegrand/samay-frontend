# I-55 — Event Detail & Edit (EDET foundation) — 2026-08-09

**Agent:** I-55 · **Role:** EDET foundation (`event_detail_screen` + `event_edit_screen`)
**Phase:** 05 — Events · **Specs:** `docs/specs/steps/phase-05-events/EDET-event-detail-edit.md`,
`ESTA-event-status-machine.md`, `EEDG-edge-functions-event-lifecycle.md`, MVP spec §6.3
**Parallel:** I-54 (ECRT create flow — locks held on `event_form_data.dart`/`create_event_screen.dart`),
I-53 (notification center — locks on `app_router.dart`/ARB/router tests), I-49/I-50/I-51.

---

## What was built

1. **`lib/features/events/events_providers.dart`** — Riverpod family providers:
   - `eventDetailProvider` (FamilyAsyncNotifier): fetch via `EventService.getEvent`,
     `refresh()` (invalidateSelf) and `update(patch)` (patch + reload).
   - `eventPromotoresProvider`: promotor rows enriched with `users.username`.
   - `myEventInviteProvider`: the current user's `event_invites` row (null when not invited).
2. **`lib/features/events/event_detail_screen.dart`** — `ConsumerStatefulWidget`:
   - Cover (`VNetworkImage` when `cover_url` set), Playfair Display `headlineLarge`
     (28px italic, glow-soft per DISCO-DESIGN-SYSTEM §3.2/§3.4) name, type + status badges
     (status colors per ESTA: upcoming white, live white-fill, ended dark, cancelled pink),
     date range via `intl` `DateFormat` with the app locale, location row, group link
     (`/group/:id`) when `group_id` is set, preshard pool card (amount, distributed flag,
     per-user cap, remainder action), promotores avatar row with role badges, own invite
     status row.
   - Actions per role+status: **Editar** → `/event/:eventId/edit`; **Cancelar evento** →
     confirm dialog → `updateEvent({'status': 'cancelled'})` → snackbar. Only `promotor`
     role and status ∉ {ended, cancelled}. Co_promotores see no edit/cancel (capability
     limits enforced — spec §EDET).
3. **`lib/features/events/event_edit_screen.dart`** — promotor pre-live editor:
   - Pre-filled name / description / location / starts_at / ends_at (date+time pickers).
   - Preshard pool / cap / remainder: editable only until `starts_at` (lock notice otherwise),
     hidden entirely for `casual` (DB CHECK forces pool 0).
   - Validation: name required, `ends_at > starts_at`, pool ≥ 0. Submit → `update` (patch +
     reload) → snackbar → pop back to detail.
4. **`lib/features/events/event_formatters.dart`** — pure `formatEventDateRange` helper
   (same-day ranges collapse the end time; locale-aware via intl).
5. **`lib/core/services/event_service.dart`** — added `getEventPromotores(eventId)` and
   `getMyEventInvite(eventId)` (event detail data sources).
6. **Integration flow** `integration_test/events_flow_test.dart` + `newTestContainer`
   gained an `overrides` parameter (hermetic provider stubbing in the real app shell).
7. Router + ARB keys + router tests (pending I-53's locks — see "Blocked" below).

## Decisions

- **Providers are the single data seam**: screens watch providers, never call
  `SupabaseService.instance` — consistent with the decomposed-service direction
  (I-11/I-50, `service_providers.dart`).
- **Cancel = client-side status flip only.** The pool return (preshard_ledger
  `event_pool_returned` + `preshards_pool = 0`) is server-side logic: the Go admin CLI
  `CancelEvent` (internal/ops/events.go) does the refund under service-role; the client
  has no privileged path and no RPC exists for it.
- **Invitee actions (Aceptar/Declinar/QR) and scanner buttons are NOT built here** —
  they belong to EINV/QRAT/ESTA (invite management + QR screens); the detail screen
  shows the invite status row only. Documented so the checklist isn't silently dropped.
- **Maps-launch not implemented**: the location is a plain row. Opening maps needs a
  direct `url_launcher` dependency (currently only transitive in pubspec.lock) — flagged
  to the orchestrator; EINV/ESTA may take it.
- **I-54 coordination**: `event_form_data.dart` did not exist when I-55 ran; the edit
  form is self-contained (its own controllers/validation). If I-54's shared
  form-data/validation lands, the edit screen can be refactored onto it — flagged.

## MISTAKE

- **MISTAKE (l10n race)**: I-54 regenerated the generated l10n files
  (`app_localizations*.dart`) several times while I held their locks — my
  hand-added accessors were wiped 3×. Root cause: my ARB keys could not land
  (I-54 holds `app_es.arb`/`app_en.arb`), so the generated files were the only
  place to put them, and gen-l10n rewrites them wholesale. Workaround: a
  re-apply script (`/tmp/i55-reapply.sh`) that re-patches the generated files
  just-in-time before each test run; the ARB files remain the source of truth
  and I-55's keys must be merged into them (blocked on I-54's locks) so a
  regeneration is stable. **Lock-discipline note for the orchestrator:**
  I-54's `flutter gen-l10n` edited files under I-55's held locks.
- **MISTAKE (perf guard)**: the first full-suite run failed
  `test/perf/list_view_builder_test.dart` because `event_detail_screen.dart`
  used `ListView(children: [])`. The outer list is fixed-content (data renders
  inside a Wrap), so a justified allowlist entry was added
  (`test/perf/list_view_builder_test.dart`, I-20's file, locked).
- **MISTAKE (riverpod API)**: naming the notifier method `update()` collided
  with `AsyncNotifierBase.update` — renamed to `patch()`.
- **MISTAKE (tests)**: first version of `event_detail_test.dart` had a
  leftover `final container = _pump(Container());` in the co_promotor test and
  a meaningless `expect(_DetailHarness, isNotNull)`; both fixed in self-review.
  `scrollUntilVisible` stops as soon as a lazy ListView child is *built*
  (cacheExtent) rather than *visible* — switched to deterministic drags /
  `ensureVisible` / a taller `tester.view` for the edit form.
- **MISTAKE (edit screen)**: `DropdownButtonFormField` used the deprecated
  `value:` param; the date button reused `formatEventDateRange(v, v)`
  doubling the time label — replaced with a direct `DateFormat` call.
- **MISTAKE (locks)**: the first lock-acquire loop hit I-53-held files and
  timed out the shell at 120 s — split into "free files first, then poll
  blocked ones in the background".

## Blocked (lock waits — resolved)

- `lib/core/router/app_router.dart`, `lib/l10n/app_es.arb`, `lib/l10n/app_en.arb`,
  `lib/l10n/app_localizations*.dart`, `test/router/app_router_test.dart`,
  `docs/to-fix/TODO.md`, `integration_test/runner.sh` — initially held by
  **I-53-notification-center**, then the ARB pair by **I-54-event-create** and
  TODO.md by I-51/I-52/I-50. All were acquired (background polls) as their
  owners released; the ARB keys landed via `flutter gen-l10n` (canonical
  regeneration including I-54's keys), and TODO.md was updated + released.

## Final verification (2026-08-09, post-ARB)

- `dart analyze` — **0 errors, 0 new issues** (2 pre-existing warnings remain in
  I-54's in-flight `create_event_screen.dart`).
- `flutter test test/features/events/event_detail_test.dart` — **20/20**.
- `flutter test test/router/app_router_test.dart test/l10n/` — **72/72**.
- `flutter test integration_test/events_flow_test.dart` — **2/2**.
- `flutter test` (full suite) — **1137 pass / 2 fail**, both from I-54's
  in-flight ECRT files (`create_event_test.dart` compile error — `base()`
  undefined; `create_event_screen.dart` unjustified `ListView(children:)` in
  the perf guard). Neither is I-55's; they clear when I-54 lands.

## Commands

```bash
tools/agent_lock.sh acquire <path> --owner I-55   # per file, see report
dart analyze
flutter test test/features/events/event_detail_test.dart
flutter test test/router/app_router_test.dart test/l10n/
flutter test integration_test/events_flow_test.dart
```

## Gap flags for the orchestrator

- **S-07/EEDG**: client cancel cannot return the pool — needs a server-side RPC/Edge
  Function (or the Go admin path) exposed to promotores, per MVP spec §6.3 cancellation.
- **url_launcher**: direct dep needed for the tappable-location spec item.
- **I-54**: `event_form_data.dart` reuse after ECRT lands.
