# Live-Path RPCs + Notification Producers (2026-08-13, `e0eab3c`)

**Agent:** R2-log-backfill (docs-remediation sweep) · **Branch:** `fixes` · **HEAD:** `e0eab3c`

## What was built

Docs-to-code audit fix wave: shipped screens were dead ends on a live stack — no
code could reach the DB paths they called. 25 files, +2280/−23:

1. **Direct-chat path (`20260814000001_chat_direct_rls.sql`, 162 lines):**
   `cp_read_participant` policy (own-participant-only `cp_read_own` broke
   `_resolvePeerUserId`), `is_chat_participant` SECURITY DEFINER helper
   (recursion-safe), `create_direct_chat` RPC (chat + both participants
   atomically, reuses an existing pair chat), `messages_insert_participant`
   guard (no cross-chat message injection). `ChatService.createDirectChat`
   added (`lib/core/services/chat_service.dart` +23).
2. **Block-exclusion views (`20260814000002_user_views_block_exclusion.sql`):**
   blocked users excluded from `user_search_view`/`discovery_view` in both
   directions, `security_barrier` preserved.
3. **Rank decay + cron (`20260814000003_rank_recalc_decay_cron.sql`):**
   `recalculate_ranks` gets boost decay + bracket-change notifications +
   `search_path=''` hardening; `ranks-recalculate` daily cron scheduled reading
   the `ranks.update_cron` app_config key; `groups.rank_bracket` normalized to
   `b0_20` on INSERT. Also introduces the guarded `insert_notification` helper
   (SECURITY DEFINER writer, EXECUTE revoked).
4. **QR rotation (`20260814000004_qr_token_rotate_rpc.sql`, 112 lines):**
   `rotate_qr_token` issues/rotates tokens atomically — advisory-lock serialized
   (:74), window + invite gates, old tokens invalidated.
   `MyQrTokenNotifier` self-issues on first fetch (`qr_providers.dart` +42).
5. **Notification producers (`20260814000005_notification_triggers.sql`, 339
   lines):** 8 SECURITY DEFINER `notify_*` triggers (event invite, friend
   request, event live, event cancelled, attendance confirmed, new message with
   E2EE-safe generic body, minigame invite, feature request approved/rejected)
   writing in-app `notifications` via `insert_notification`.
6. All 5 migrations mirrored byte-identical in `supabase-testing/`.

## Tests / validation

- pgTAP: plan **344 → 385** (+41 cases) in both `schema_test.sql` mirrors;
  live stack applied, `opt-003` caught + fixed an RLS recursion in the first
  policy draft.
- Flutter: +11 test cases (`test/services/chat_service_test.dart` +42,
  `test/features/qr/event_qr_service_test.dart` +45,
  `test/features/qr/attendance_qr_screen_test.dart` +55; 4 existing files +3
  registration lines) — suite **2209/2209**.

## Decisions

- In-app notifications are produced DB-side (triggers + RPC) while EEDG stays
  blocked — documented deviation in the migration header; push-notifier +
  per-user preference check remain Edge Function territory (PUSH/NTRG 8/16).
- E2EE server never sees message content — the `notify_new_message` body is
  generic, per E2EE §9.2.

## Commands run

```bash
git show e0eab3c --stat            # 25 files, +2280/−23
supabase db test                   # plan 385
flutter test                       # 2209/2209
```

## Follow-ups

- Remaining NTRG dispatch points (8/16): push pipeline, preference gating,
  QR-activation notifications, CLI-sourced events.
- `override-reconciler` cron still pending (MPGR).
