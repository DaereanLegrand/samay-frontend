# Phase Inventory — Phases 00–15 (last verified 2026-08-13)

**Agent:** D-12 (Phase 4.1 — documentation) · **Date:** 2026-08-09 · **Branch:** `fixes`
**R-3 refresh (2026-08-13):** status column refreshed for the phase-05+ foundations
that landed since 2026-08-09 (I-54..I-71, M-, U-, S-, XL-series); the I-02 port-remap
item and the `.env.example` anon-key finding are resolved; FLMT/EDG-family steps are
intentionally left ❌ (`supabase/functions/` holds only the M-07 boot stub — no
business function code; QR/rank/notify mechanics shipped as SQL RPCs + pg_cron).
**R-4 refresh (2026-08-13):** baselines re-verified (`flutter test` 2209/2209,
`go test` 182, pgTAP plan 385), AUTH/PRFL remaining-gap lists updated, migration
counts 33/33, `ranks.update_cron` scheduled (20260814000003).

This inventory verifies every phase 00–15 against three sources of truth:
`docs/history/**/*.DONE` markers, `docs/specs/steps/cross-references.md`
statuses, and the actual working tree (code + migrations + routes).

Status key (same as cross-references.md): ✅ implemented · ⚠️ partially implemented ·
❌ not started · 🔴 blocked by missing dependency.

---

## Phase 00 — Foundation & Infrastructure

| Step | DONE marker | Cross-ref status | Implementation spec | Dev logs | Reality check (verified) |
|------|-------------|------------------|---------------------|----------|--------------------------|
| `REPO` | ✅ `REPO.DONE` | ✅ | `REPO-repository-setup.md` | 2 logs | Go module `github.com/samay-app/samay`, repo layout intact |
| `INFR` | ✅ `INFR.DONE` | ✅ (Edge Functions not deployed) | `INFR-supabase-deployment.md` | 2 logs | Self-hosted compose + `config.toml` exist; `supabase/functions/` = M-07 boot stub only |
| `DATA` | ✅ `DATA.DONE` | ✅ | `DATA-database-schema.md` | 2 logs | 33 migrations in both `supabase/` and `supabase-testing/`; 30+ tables, 21 enums |
| `SECU` | ✅ `SECU.DONE` | ✅ (signup_tracker fixed, C-01) | `SECU-rls-policies.md` | 2 logs | Migrations `20260724000001`/`20260724000002` present |
| `TRIG` | ✅ `TRIG.DONE` | ✅ (9 base triggers; `shard_distribution_dispatch_trigger` = `RAISE LOG` placeholder) | `TRIG-database-triggers.md` | 2 logs | 20 total: 9 base in `20260510000001_full_schema.sql` + 3 `assert_safe_*` (`assert_safe_user_update_trigger` 20260809000002:143; `assert_safe_group_update_trigger` + `assert_safe_event_update_trigger` 20260811000001:168,208) + 8 notification triggers in `20260814000005` |
| `CRON` | ✅ `CRON.DONE` | ✅ (status-poll, end-events, hard-delete scheduled) | `CRON-postgres-cron-jobs.md` | 2 logs | `20260510000002_cron.sql` schedules 3 jobs; `ranks.update_cron` scheduled 2026-08-13 (`20260814000003`, with decay); `override-reconciler` pending |
| `FLMT` | ❌ no marker | 🔴 blocked by `EEDG` | `FLMT-edge-functions-rate-limiting.md` | none | Spec itself documents "Current Implementation Status" |

**Phase 00 gaps:** `FLMT` (edge-function rate limiting) unstarted, blocked on the
missing Edge Functions infrastructure (`EEDG`). All 6 `.DONE` marker files exist
(empty files — see note below).

---

## Phase 01 — Admin CLI (Go)

All 14 steps carry `.DONE` markers; all are ✅ in cross-references; implementation
specs exist for all 14. Dev logs: `2026-05-10_CLI-full-implementation.md`,
`2026-07-30_C07-CLI-entry-point*.md`.

| Step | DONE | Status | Verified in code |
|------|------|--------|------------------|
| `DBCL` | ✅ | ✅ | `internal/db/client.go` (PostgREST client), `models.go` (30+ structs) |
| `FMTT` | ✅ | ✅ | `internal/format/table.go` (table + JSON) |
| `ROOT` | ✅ | ✅ | `cmd/samay-admin/root.go` (cobra, env vars, `--json`) |
| `USRS` | ✅ | ✅ | `cmd/samay-admin/users.go` + `internal/ops/users.go` (ban/grant/delete, RPCs `grant_shards`/`grant_preshards`) |
| `EVTC` | ✅ | ✅ | `cmd/samay-admin/events.go` + `internal/ops/events.go` (feature/cancel/distribute via `distribute_shards` RPC) |
| `FREC` | ✅ | ✅ | `cmd/samay-admin/feature_requests.go` + ops |
| `GRPS` | ✅ | ✅ | `cmd/samay-admin/groups.go` + ops |
| `RPTS` | ✅ | ✅ | `cmd/samay-admin/reports.go` + ops |
| `SHRD` | ✅ | ✅ | `cmd/samay-admin/shards.go` + ops (`recalculate_ranks` RPC) |
| `CONF` | ✅ | ✅ | `cmd/samay-admin/config.go` + ops (set/reset w/ `--confirm`) |
| `SUBS` | ✅ | ✅ | `cmd/samay-admin/subs.go` + ops (override/revoke) |
| `SYST` | ✅ | ✅ | `cmd/samay-admin/system.go` + `internal/ops/system.go` (stats/health) |
| `AUDT` | ✅ | ✅ | `internal/ops/audit.go` (`LogAction`) — every mutation calls it |
| `BLD1` | ✅ | ✅ | `make build-cli`/`build-linux` produce `samay`/`samay-linux` binaries (present at repo root) |

**Phase 01 status:** COMPLETE (14/14 steps done). `go test ./...` = 182 pass (re-verified 2026-08-13, 5 packages).

---

## Phase 02 — Flutter App Foundation

All 6 steps `.DONE` + ✅. Specs + 4 dev logs (scaffold, H-01, H-02).

| Step | DONE | Status | Verified in code |
|------|------|--------|------------------|
| `FLUT` | ✅ | ✅ | `pubspec.yaml` (Riverpod, GoRouter, Supabase, Hive, qr_flutter, mobile_scanner, purchases_flutter, image_picker) — `share_plus` removed by I-23 |
| `DSNG` | ✅ | ✅ | `SamayTheme.dark` + `SamayDurations`; shared widgets `v_*` |
| `STAT` | ✅ | ✅ | `auth_provider.dart`, `config_provider.dart`, `user_provider.dart` (appConfigProvider live — C-03) |
| `ROUT` | ✅ | ✅ | `route_paths.dart` (28 constants + 16 builders, H-02) + `app_router.dart` (H-01 placeholders replaced by real screens; `VComingSoonScreen` deleted 2026-08-13) |
| `SBAS` | ✅ | ✅ | Decomposed feature services (I-11) — `supabase_service.dart` facade deleted by I-78 |
| `STOR` | ✅ | ✅ | `storage_service.dart` (SecureStorage + Hive boxes) |

**Phase 02 status:** COMPLETE (6/6). Note: `realtime_provider.dart` basic
`StreamProvider` exists; full lifecycle (reconnect/backoff) is I-52.

---

## Phase 03 — Auth & Profiles

| Step | DONE | Cross-ref status | Spec | Dev logs | Notes |
|------|------|------------------|------|----------|-------|
| `AUTH` | ✅ `AUTH.DONE` | ⚠️ 37/64 requirements | `AUTH-signup-login.md` | 3 logs | Signup = email+password+OTP+age gate+terms+username. OTP auto-submit + resend countdown (I-29), avatar upload (I-36), client ban screen (I-35) landed. Missing: phone entry, server-side ban-enforcement Edge Function, brand logo. `users_search` → `user_search_view` security barrier. |
| `PRFL` | ✅ `PRFL.DONE` | ⚠️ | `PRFL-profile-screen-edit.md` | 3 logs | Avatar upload + interest tags (I-36) + privacy/notification settings screens (2026-08-13) landed. "Enviar mensaje" landed 2026-08-13 (plugged chat entry: `createDirectChat` → `/chat/:chatId`, flag-gated, accepted-and-unblocked friends only). Missing: cosmetics display in profile, "Bloquear" from profile, mutual friends |
| `DELE` | ✅ `DELE.DONE` | ✅ | `DELE-account-deletion.md` | 3 logs | Soft-delete screen + `hard_delete_expired_users` cron |

**Phase 03 status:** ⚠️ AUTH + PRFL partially met despite `.DONE` markers
(marker = "as-built at time", not "spec complete" — same convention as GLIM/GROU).
Remaining gaps listed in the rows above (R-4 refresh, 2026-08-13).

---

## Phase 04 — Friends & Groups

| Step | DONE | Cross-ref status | Spec | Notes |
|------|------|------------------|------|-------|
| `FRND` | ✅ `FRND.DONE` | ✅ | `FRND-friends-system.md` | 3-tab requests incl. Invitaciones (addition not in spec). Screens: search, requests, friends list, blocked. Freshness (2026-08-14): every mutation invalidates `friendsListProvider` (accept/decline/send/block) AND a shell-mounted realtime listener (`FriendshipsRealtimeListener`, `friendships` channel) refreshes both sides live |
| `GROU` | ⚠️ `GROU.DONE` (text: PARTIALLY MET) | ⚠️ | `GROU-groups-core.md` | Missing: promotor transfer UI, co-promotor UI, cosmetics display, group chat (E2EE 1:1-only — chat tab is an explanatory R2 card). Cover upload done (image_picker + Storage); real `CreateEventScreen` route at `/group/:groupId/create-event`; minigames hub button on group detail (flag-gated, 2026-08-13) |
| `GLIM` | ⚠️ `GLIM.DONE` (text: PARTIALLY MET) | ⚠️ | `GLIM-group-limits-subscription-enforcement.md` | Member limit hardcoded `14` (`group_detail_screen._getMemberLimit`), group-count limit hardcoded `5` (`create_group_screen`), not wired to `app_config`. Freeze banner UI done |
| `SDON` | ✅ `SDON.DONE` | ✅ | `SDON-shard-donations.md` | Donation RPC (auth-checked C-06), contribution display, top contributors; boost-expiry days display deferred |
| `RANK` | ✅ `RANK.DONE` | ✅ (UI only) | `RANK-group-rank-display.md` | Leaderboard + RankBadge complete; **data empty until Phase 11 `GRCK` cron** |

**Phase 04 status:** ⚠️ GROU/GLIM partially met (their `.DONE` files document the
gaps). FRND/SDON/RANK done (RANK pending GRCK data).

---

## Phase 05 — Events  → `docs/history/phase-05-events/PLAN.md`

| Step | DONE | Cross-ref status | Spec | Reality |
|------|------|------------------|------|---------|
| `ECRT` | ⚠️ no marker | ⚠️ foundation landed (I-54) | `ECRT-event-creation-flow.md` | `lib/features/events/` landed (2026-08-09): `screens/create_event_screen.dart` + `logic/event_form_data.dart` + `events_providers.dart`; `create_event_test.dart` green (suite 2151/2151, XL-22 gate) |
| `EDET` | ⚠️ no marker | ⚠️ foundation landed (I-55) | `EDET-event-detail-edit.md` | `event_detail_screen.dart` + `event_edit_screen.dart` + `my_events_screen.dart`; client cancel flips `status=cancelled` only — preshard pool return + invitee accept/decline server-side (ESTA/EINV/EEDG). Live-actions row (2026-08-13): QR attendance + promotor scanner + photo gallery buttons, flag-gated, hidden once the event is ended/cancelled |
| `ESTA` | ❌ | ❌ Blocked by `EEDG` | `ESTA-event-status-machine.md` | No code |
| `EINV` | ❌ | ❌ No code | `EINV-event-invites-static-qr.md` | Client invite route wrapper exists (`events/widgets/event_invite_route.dart`); server-side invite flow pending |
| `EEDG` | ❌ | ❌ No Edge Functions | `EEDG-edge-functions-event-lifecycle.md` | `supabase/functions/` = M-07 boot stub only; QR/rank/notify mechanics shipped as SQL RPCs + pg_cron (documented deviations, `20260814000003/04/05`); `shard_distribution_dispatch_trigger` = `RAISE LOG` placeholder |

**Phase 05 status:** ⚠️ ECRT/EDET foundations landed (I-54/I-55); ESTA/EINV
server-side pending; EEDG blocked (no `supabase/functions/`).

---

## Phase 06 — QR System → `docs/history/phase-06-qr-system/PLAN.md`

| Step | DONE | Cross-ref status | Spec | Reality |
|------|------|------------------|------|---------|
| `QRAT` | ⚠️ no marker | ⚠️ client foundation landed (I-57) | `QRAT-dynamic-attendance-qr-attendee.md` | `lib/features/qr/` (2026-08-09): `attendance_qr_screen.dart` + `myQrTokenProvider` + `validate_qr_token` RPC migration `20260809000005`; token rotation landed as SQL RPC `rotate_qr_token` (`20260814000004`, advisory-lock guarded); reachable from the event-detail live-actions row (2026-08-13) |
| `QRSC` | ⚠️ no marker | ⚠️ client foundation landed (I-57) | `QRSC-qr-scanner-promotor.md` | `qr_scanner_screen.dart` (mobile_scanner 6.x, PermissionService camera flow) + scan → `validate_qr_token` RPC; reachable from the event-detail live-actions row for promotors (2026-08-13) |
| `QEDG` | ❌ | ✅ SQL RPC stand-ins | `QEDG-qr-edge-functions.md` | Delivered as SQL SECURITY DEFINER RPCs (`validate_qr_token` `20260809000005`, `rotate_qr_token` `20260814000004`) instead of Edge Functions — documented deviation; no `supabase/functions/` business code |

**Phase 06 status:** ⚠️ QRAT/QRSC client + validate RPC landed (I-57), reachable from the event-detail live-actions row (2026-08-13); QEDG blocked (no `supabase/functions/`).

---

## Phase 07 — Chat → `docs/history/phase-07-chat/PLAN.md`

| Step | DONE | Cross-ref status | Spec | Reality |
|------|------|------------------|------|---------|
| `CHAT` | ⚠️ no marker | ⚠️ core landed (I-37/I-38/I-56) | `CHAT-chat-system-core.md` | E2EE core `lib/crypto/` (x3dh, double ratchet, key store, envelope) + `chat_screen.dart` + pagination (load 50 + `loadOlder()`, `chat.message_cap` rolling window); `/chat/:chatId` → real screen; direct-chat entry from the public profile "Enviar mensaje" button (`createDirectChat`, flag-gated, 2026-08-13) |
| `CHPT` | ❌ | ❌ No code | `CHPT-chat-participation-access-rules.md` | No code |
| `CHMC` | ❌ | ❌ No code | `CHMC-message-cap-reporting.md` | Trigger exists (TRIG #3); client reporting flow absent |

**Phase 07 status:** ⚠️ CHAT core landed (E2EE + pagination, profile "Enviar mensaje" entry 2026-08-13); CHPT/CHMC pending.

---

## Phase 08 — Social Feed & Photos → `docs/history/phase-08-social-feed-photos/PLAN.md`

| Step | DONE | Cross-ref status | Spec | Reality |
|------|------|------------------|------|---------|
| `FEED` | ⚠️ no marker | ⚠️ foundation landed (I-58) | `FEED-social-feed.md` | `lib/features/feed/` (2026-08-09): `feed_screen.dart` + providers + `feed_flow_test.dart`; full data flows pending server data. Games quick-access row landed 2026-08-13 (5 minigame cards + Party Finder card, flag-gated) |
| `FEET` | ❌ | ❌ No code | `FEET-featured-events.md` | CLI side done (`EVTC` feature/unfeature/reject + `FREC`); in-app form absent |
| `PHUP` | ⚠️ no marker | ⚠️ foundation landed (I-59) | `PHUP-photo-upload-gallery.md` | `lib/features/photos/` (2026-08-09): `photo_gallery_screen.dart` + upload pipeline (`MediaService.uploadEventPhoto` + `ImageProcessor`); `photos_flow_test.dart`; collage-wall entry button in the gallery AppBar (2026-08-13) |
| `COLL` | ❌ | ❌ No code | `COLL-photo-collage.md` | Collage screen file exists (`events/screens/event_collage_screen.dart`); wall reachable via the gallery entry button (2026-08-13, photoUpload-gated); PNG export still pending |

**Phase 08 status:** ⚠️ FEED/PHUP foundations landed (I-58/I-59, home games row + collage-wall entry 2026-08-13); FEET pending, COLL wall reachable but PNG export pending.

---

## Phase 09 — Notifications & Push → `docs/history/phase-09-notifications-push/PLAN.md`

| Step | DONE | Cross-ref status | Spec | Reality |
|------|------|------------------|------|---------|
| `NOTI` | ⚠️ no marker | ⚠️ foundation landed (I-53) | `NOTI-notification-center.md` | `lib/features/notifications/` (2026-08-09): `notification_center_screen.dart` + providers + realtime live-insert + `notifications_flow_test.dart`; `/main/notifications` → real screen |
| `PUSH` | ❌ | ❌ No code | `PUSH-push-notification-edge-functions.md` | No Pusher Beams setup; env placeholders in `.env.example` |
| `NTRG` | ⚠️ no marker | ⚠️ 8/16 dispatch points live (e0eab3c) | `NTRG-notification-triggers-routing.md` | 1 log | `20260814000005_notification_triggers.sql` — 8 SECURITY DEFINER `notify_*` triggers write in-app notifications via the guarded `insert_notification` helper (20260814000003); push + preference check still pending |

**Phase 09 status:** ⚠️ NOTI foundation landed (I-53); NTRG 8/16 dispatch points live (in-app rows); PUSH pending (edge functions).

---

## Phase 10 — Shards Economy & Cosmetics → `docs/history/phase-10-shards-cosmetics/PLAN.md`

| Step | DONE | Cross-ref status | Spec | Reality |
|------|------|------------------|------|---------|
| `SLED` | ⚠️ no marker | ⚠️ foundation landed (I-64) | `SLED-shard-preshard-ledgers.md` | `lib/features/shards/` (2026-08-09): `shard_ledger_screen.dart` + paged providers (`shard_ledger_providers.dart`); `shard_ledger_flow` covered by integration suite |
| `SDIS` | ❌ | ❌ Blocked by `ECRT` + `EEDG` | `SDIS-shard-distribution-logic.md` | Logic specced in detail; `distribute_shards` RPC exists (EVTC) but Edge Function absent |
| `COSM` | ⚠️ no marker | ⚠️ foundation landed (I-62) | `COSM-cosmetics-shop.md` | `lib/features/cosmetics/` (2026-08-09): `cosmetics_shop_screen.dart` + providers + `cosmetics_flow_test.dart`; purchase flow server-side pending |
| `GCOS` | ❌ | ❌ No code | `GCOS-group-cosmetics-voting.md` | No code; `cosmetics`/`user_cosmetics`/`group_cosmetics` tables exist in schema |

**Phase 10 status:** ⚠️ SLED/COSM foundations landed (I-64/I-62); SDIS/GCOS pending (EEDG).

---

## Phase 11 — Gamification & Mini-Games → `docs/history/phase-11-gamification-minigames/PLAN.md`

| Step | DONE | Cross-ref status | Spec | Reality |
|------|------|------------------|------|---------|
| `GRCK` | ❌ | ✅ SQL + cron | `GRCK-rank-calculation-edge-function.md` | No Edge Function; delivered as SQL: `recalculate_ranks` RPC (SHRD) + `ranks.update_cron` with boost decay scheduled (`20260814000003`); RANK leaderboard data now flows |
| `GMCR` | ⚠️ no marker | ⚠️ foundation landed (I-63) | `GMCR-minigames-core.md` | `lib/features/minigames/` (2026-08-09): screens + providers + `minigames_flow_test.dart`; `minigame_sessions` table + join/finish RPCs (migration `20260813000001`); entry points landed 2026-08-13: home games row + group-detail button (flag-gated; single/multi/no-group resolution + shared `minigame_meta.dart` icons/names) |
| `GWAG` | ❌ | ❌ No code | `GWAG-wager-system.md` | No code |

**Phase 11 status:** ⚠️ GMCR foundation landed (I-63) with home/group entry points (2026-08-13); GRCK/GWAG pending (edge functions). RANK leaderboard data depends on `GRCK`.

---

## Phase 12 — Monetization & Subscriptions → `docs/history/phase-12-monetization-subscriptions/PLAN.md`

| Step | DONE | Cross-ref status | Spec | Reality |
|------|------|------------------|------|---------|
| `PLAN` | ⚠️ no marker | ⚠️ foundation landed (I-61) | `PLAN-subscription-plans-paywall.md` | `lib/features/subscriptions/` (2026-08-09): `paywall_screen.dart` + `RevenueCatService` (purchases_flutter 10.8 re-added); `/subscriptions` still flag-gated |
| `RCBH` | ❌ | ❌ No code | `RCBH-revenuecat-webhook-handler.md` | `processed_webhooks` table exists (idempotency); no Edge Function |
| `SOVR` | ❌ | ❌ No code | `SOVR-subscription-override-system.md` | `subscription_overrides` table + `SUBS` CLI override/revoke exist; reconciler absent |
| `PPAC` | ❌ | ❌ No code | `PPAC-preshard-packs-purchase.md` | `purchases_flutter` dep present; no store UI |
| `MPGR` | ❌ | ❌ No code | `MPGR-monthly-preshard-grants.md` | Config keys seeded; `override-reconciler` cron not scheduled |

**Phase 12 status:** ⚠️ PLAN foundation landed (I-61); RCBH/SOVR/PPAC/MPGR pending.

---

## Phase 13 — Party Finder & Video Souvenir → `docs/history/phase-13-party-finder-video/PLAN.md`

| Step | DONE | Cross-ref status | Spec | Reality |
|------|------|------------------|------|---------|
| `PFND` | ⚠️ no marker | ⚠️ foundation landed (I-60) | `PFND-party-finder.md` | `lib/features/party_finder/` (2026-08-09): `party_finder_screen.dart` + providers + `party_finder_flow_test.dart`; interest tags deferred (PRFL gap); home-feed entry card landed 2026-08-13 (flag-gated) |
| `VIDS` | ❌ | ❌ No code | `VIDS-video-souvenir.md` | No code |
| `MUSC` | ❌ | ❌ No code | `MUSC-music-library.md` | No `assets/music/` |

**Phase 13 status:** ⚠️ PFND foundation landed (I-60, home-feed entry card 2026-08-13); VIDS/MUSC pending.

---

## Phase 14 — Alpha & Beta Launch → `docs/history/phase-14-alpha-beta-launch/PLAN.md`

| Step | DONE | Cross-ref status | Spec |
|------|------|------------------|------|
| `ATST` | ❌ | ❌ Blocked (massive gaps) | `ATST-alpha-integration.md` |
| `RSDK` | ❌ | ❌ Blocked by `RCBH` | `RSDK-revenuecat-sdk-wiring.md` |
| `PLAT` | ❌ | ❌ | `PLAT-app-store-play-store-prep.md` |
| `TEST` | ❌ | ❌ | `TEST-alpha-testing.md` |
| `BTA1` | ❌ | ❌ | `BTA1-beta-phase-1.md` |
| `BTA2` | ❌ | ❌ | `BTA2-beta-phase-2.md` |
| `BLNC` | ❌ | ❌ | `BLNC-beta-launch-metrics.md` |

**Phase 14 status:** ❌ (7/7 unstarted; everything downstream of phases 05–13).

---

## Phase 15 — Post-MVP Web Servers → `docs/history/phase-15-post-mvp-web-servers/PLAN.md`

| Step | DONE | Cross-ref status | Spec | Reality |
|------|------|------------------|------|---------|
| `APIS` | ⚠️ no marker | ⚠️ scaffold landed (I-41) | `APIS-go-api-server.md` | `cmd/samay-api-server/` exists (Gin scaffold, 2026-08-09): 31 admin routes + `/api/v1/health` + reserved 501 namespaces; `ADMIN_API_KEY` placeholder gate (JWT/JWKS = S-06/M-21); `make build-api` added; 17 httptest tests green |
| `DASH` | ❌ | ❌ | `DASH-admin-dashboard-react.md` | No code |
| `PORT` | ❌ | ❌ | `PORT-promotor-portal-react.md` | No code |
| `VENU` | ❌ | ❌ | `VENU-vive-venue-app-flutter.md` | No code |
| `DEPL` | ❌ | ❌ | `DEPL-deployment-architecture.md` | Placeholder docs in `<private-ops-repo>/` (DEPLOYMENT-PLACEHOLDER.md) |

**Phase 15 status:** ⚠️ APIS scaffold landed (I-41); DASH/PORT/VENU/DEPL pending.

---

## Cross-phase orchestration workstreams (from cross-references.md)

| Workstream | Status (verified 2026-08-13) |
|------------|-------------------------------|
| `I-01` integration_test suite | ✅ `integration_test/` exists: **18 hermetic flows** + `ui_smoke_test.dart` registered in `runner.sh` (U-29, 2026-08-11), `support/fake_supabase.dart` harness |
| `I-02` + `M-01..M-10` port remap | ✅ resolved — approved map (54382/54381/54384/54386/54388/54443) enforced across compose + `config.toml` + scripts; `tools/check_ports.sh --strict` STRICT PASS (V-04, 2026-08-11: 19 mappings / 205 refs / 0 violations) |
| `I-37`/`I-38` E2EE chat | ✅ `lib/crypto/` landed (x3dh, double ratchet, key store, envelope, codec, session) |
| `D-11` + `U-01..U-30` disco design | ✅ `docs/design/DISCO-DESIGN-SYSTEM.md` + U-01..U-30 landed (2026-08-09..11); LUXE v2 overhaul (XL-01..XL-22, 2026-08-12/13) with `DISCO-LUXE-DESIGN-SYSTEM.md` |
| `I-49..I-78` phase 05+ foundations | ⚠️ most landed (see phase tables 05–13 + cross-cutting: storage `I-25/I-26`, realtime `I-52`, deep links `I-66`, telemetry `I-68`, crash reporter `I-70`, config-cache `I-71`); edge-function-dependent steps (EEDG/QEDG/…) remain ❌ |
| `I-66` deep links | ✅ `lib/core/deep_links/` landed; `/event/:inviteToken` shadowing removed (dead route deleted) |

---

## Global findings

1. **DONE markers:** 34 exist for phases 00–04 (6+14+6+3+5). All are **empty files**
   except `GROU.DONE`/`GLIM.DONE`, which carry "⚠️ PARTIALLY MET" gap notes.
   Cross-references.md agrees (⚠️ GROU/GLIM/AUTH/PRFL). Interpretation rule for
   V-03 and later agents: **a `.DONE` file proves "as-built shipped", not
   "spec 100% satisfied"** — always cross-check the phase step's status column.
2. **FLMT** has no `.DONE` (expected — it is 🔴 blocked by `EEDG`).
3. **Phases 05–15:** zero `.DONE` markers (by convention — phases 05+ use ⚠️ no-marker
   + status columns instead), but all 11 dev dirs exist with `PLAN.md` + daily logs,
   and the foundation implementations listed in the tables above are live.
4. **Spec count:** 45 implementation step specs exist for phases 05–15 (5+3+3+4+3+4+3+5+3+7+5).
5. **supabase-testing/ is now in sync** with `supabase/migrations/` (was one
   migration behind at 2026-08-09; parity restored via I-77, verified 2026-08-13).
6. **`structure_test.dart`** was rewritten by EF-01 (2026-08-09): dynamic
   invariants (live dirs + ≥1 `.dart` per subdir) + `test/meta/conventions_test.dart`
   guards — no longer fooled by empty placeholder dirs.
7. **Route shadowing** `/event/:inviteToken` vs `/event/:eventId` was resolved by
   I-66 (2026-08-09): the dead invite-token route was removed; deep links land
   through `lib/core/deep_links/`.
8. **GLIM hardcodes:** `14` members (`group_detail_screen.dart`) and `5` promotor
   groups (`create_group_screen.dart`) — `app_config` keys `groups.*` are seeded but
   unused by the UI; I-49/I-71 work will wire them.
9. **`.env.example`** anon-key finding **resolved** (I-34, 2026-08-09): the file now
   carries `your_supabase_anon_key_here` + the dev URL placeholder; rotating the
   previously-exposed key in the Supabase dashboard remains an ops action (M-13/S-08).

---

*Inventory compiled by D-12, 2026-08-09; statuses refreshed by R-3 on 2026-08-13.
Every status row verified against the working tree on branch `fixes`.*
