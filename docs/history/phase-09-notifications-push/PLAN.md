# Phase 09 — Notifications & Push · PLAN

> Compiled by D-12 (2026-08-09) from `docs/specs/steps/phase-09-notifications-push/*`
> and `docs/specs/steps/cross-references.md`. Read-only planning aid for I-49..I-78.

## Summary

Build the in-app notification center (Realtime subscription on `notifications`) and
the push pipeline. Push is delivered via **Pusher Beams** (single SDK abstracts
FCM/APNs; users subscribe to `user_{userId}` + `global` interests — no device-token
column needed). Edge Function `push-notifier` publishes to Beams and inserts the
in-app `notifications` row; per-user category preferences gate the push (in-app row
is always inserted).

Key mechanics (from specs):
- 16 trigger types in NTRG (event_invite, friend_request, event_starting, qr_active,
  attendance_confirmed, shard_received, rank_update, chat_message, minigame_invite,
  poke_received, invite_approval, feature_approved/rejected, report_warned,
  content_removed, event_cancelled), each mapping to a dispatch point (Postgres
  trigger / Edge Function / CLI / app logic) and a recipient.
- Notification center: unread styling, tap → deep link (from `data` JSON) → mark
  read, "mark all read", empty state.
- Preferences stored in `users.notification_preferences` (JSONB, seeded '{}');
  categories: Eventos, Chat, Social, Juegos, Economía, Promociones.
- Secrets/placeholders in `.env.example`: `PUSHER_BEAMS_INSTANCE_ID`,
  `PUSHER_BEAMS_SECRET_KEY` — never hardcode.
- Note: `lib/core/services/supabase_service.dart` already has `getNotifications`,
  `markNotificationRead`, `subscribeToNotifications`.

## Steps & dependency status (cross-references.md, verified 2026-08-09)

| Step | Direct deps | Dep status | Step status |
|------|-------------|------------|-------------|
| `NOTI` | `AUTH`⚠️, `SBAS`✅, `DATA`✅ | 3/3 green | ✅ **Done (I-53, 2026-08-09)** — notification center at `/main/notifications` (real screen + providers + tests) |
| `PUSH` | `NOTI`✅, `INFR`✅ (Pusher Beams) | 2/2 green | ❌ No code |
| `NTRG` | `PUSH`❌, `DATA`✅ | 1/2 green | ❌ No code |

## Orchestration agents starting here

| Agent | Scope (per ORCHESTRATION.md / FILE-OWNERSHIP.md) |
|-------|--------------------------------------------------|
| I-53 | ✅ Done (2026-08-09) — `lib/features/notifications/notification_center_screen.dart` + `notifications_providers.dart`, router swap, 27 unit/widget tests, hermetic integration flow. See `2026-08-09_I53-notification-center.md` |
| I-49/I-50/I-51 | Feature flags / repositories / typed REST client |
| I-52 | Realtime lifecycle (notification stream) — I-53 used the service-subscription pattern (`notification_service.subscribeToNotifications`, chat precedent) instead of `realtimeProvider`; see I-53 log |
| I-68 | Telemetry service (PostHog placeholder) — feeds BLNC funnel metrics later |
| I-66 | Deep-link handler — notification taps route via `data.deepLink` |
| I-77 | pgTAP expansion (notifications table invariants) |
| I-78 | Full-matrix sweep |

Push infra (Pusher Beams account, FCM/APNs config, `push-notifier` Edge Function)
has no dedicated I-agent in the 4.2 list — flag to the orchestrator; I-76 opt-tests
can exercise the `push-notifier` HTTP surface once it exists.

## Acceptance checklist (from the step specs)

**NOTI (`NOTI-notification-center.md`) — DONE (I-53, 2026-08-09):**
- [x] Realtime subscription: `from('notifications').stream().eq('user_id', currentUserId)` — via `notification_service.subscribeToNotifications` (user-scoped channel, chat precedent; disposal-safe channel handle added to the service)
- [x] List: type icon, title, body, timestamp (relative, l10n), read/unread indicator (unread = bold + `surface` highlight + glowPink dot)
- [x] Tap → parse `data` → navigate (deep link, registered-route guard) → `UPDATE notifications SET read = true`
- [x] "Mark all read" in app bar; empty state "Sin notificaciones"
- [x] All 16 type rows render correctly (icon mapping covers all 16 types; titles/bodies ship in the row from the push pipeline — verified via the spec table icon mapping + tests)

**PUSH (`PUSH-push-notification-edge-functions.md`):**
- [ ] Client init `PusherBeams.instance.start(instanceId)`; subscribe `user_{userId}` + `global` after auth; `clearDeviceInterests()` on logout; idempotent re-subscribe on app open
- [ ] `push-notifier` Edge Function: Beams publish (interests, apns, fcm payloads incl. `deepLink`), insert in-app `notifications` row; push failure → log + still insert in-app
- [ ] Foreground handling (`onMessageReceived` → local banner/context-aware silence); background/terminated tap → deep link via GoRouter
- [ ] Preferences check before dispatch (category disabled → skip push, keep in-app)

**NTRG (`NTRG-notification-triggers-routing.md`):**
- [ ] All 16 dispatch points wired (source event → Edge Function/trigger/CLI → `push-notifier`) with the exact recipient mapping from the spec table
- [ ] Per-user preference check before push

## Phase exit gate

All 3 steps green in cross-references.md; notifications tab real; push delivered
on device (sandbox); preferences respected; opt-test for `push-notifier` +
pgTAP green; full matrix green.
