# Phase 08 — Social Feed & Photos · PLAN

> Compiled by D-12 (2026-08-09) from `docs/specs/steps/phase-08-social-feed-photos/*`
> and `docs/specs/steps/cross-references.md`. Read-only planning aid for I-49..I-78.

## Summary

Build the social feed (main screen), featured-events flow, event photo
upload/gallery, and the after-party photo collage. The feed shows promoted events
pinned, nearby public events by radius, and group activity posts; only PRO/VIP
users post (cost: `economy.feed_post_cost_shards` = 25, config-driven). Photos
live in a **private** Storage bucket, always served via signed URLs from an Edge
Function that verifies event access.

Key mechanics (from specs):
- Feed order: featured carousel → nearby public events by `starts_at` ASC →
  group posts by `created_at` DESC.
- Radius filter from `app_config`: `feed.nearby_radius_km_options` (`5,20,50,999`)
  and `feed.nearby_radius_km_default` (50). Location permission requested on first
  open; denied → unfiltered + "Sin filtro de ubicación".
- Posting deducts shards from `personal_shards` + `shard_ledger`
  (`reason=feed_post`); insufficient → error message with the cost.
- Photos: `events/{event_id}/photos/{uuid}.jpg` in private bucket; upload window =
  live + `events.photo_upload_window_hours` (24h) after `ends_at`; signed URL via
  Edge Function (1h expiry), Hive-cached client-side; likes one-per-user
  (`event_photo_likes` + `likes_count`); long-press report.
- Collage: top `events.collage_top_n_photos` (9) by `likes_count`, client-side grid
  layouts by count, export via `RepaintBoundary` → PNG, watermark + share.

## Steps & dependency status (cross-references.md, verified 2026-08-09)

| Step | Direct deps | Dep status | Step status |
|------|-------------|------------|-------------|
| `FEED` | `ECRT`❌, `AUTH`⚠️, `SBAS`✅, `DSNG`✅ | 2/4 green | 🔄 **I-58 (2026-08-09): real feed foundation landed** — providers + screen (featured carousel pinned, upcoming public events by `starts_at` ASC, radius chips from `app_config`, empty/error states, pull-to-refresh, tap → detail); group posts + composer + distance filter remain (geolocation service = future work) |
| `FEET` | `FEED`⚠️, `EVTC`✅, `DATA`✅ | 2/3 green | ❌ No code (CLI side done) |
| `PHUP` | `ECRT`❌, `SBAS`✅, `DATA`✅ | 2/3 green | ✅ **I-59 (2026-08-09/10, session 4 — COMPLETE): photo upload + gallery foundation landed** — providers (signed-URL cache, optimistic like, report, bytes upload) + grid screen (tiles, hearts, report dialog, upload button, window notice, empty/error) behind `photoUpload` flag; service seams (uploadEventPhotoBytes/listEventPhotos/getSignedPhotoUrl/like/unlike/getMyPhotoLikes) + 14 ARB keys ×2 (gen-l10n landed, session 4) + unit/widget/integration tests; **session-4 fixes**: report dialog controller-lifetime bug (disposed-controller crash), photo_gallery_test upload tests (dart:ui codec FakeAsync hang → fake notifier seam + `runAsync` PNG generation), scanner router test bounded pump, I-60 flow-test imports, runner.sh `photos_flow_test.dart` entry restored |
| `COLL` | `PHUP`❌, `DSNG`✅ | 1/2 green | ❌ No code |

## Orchestration agents starting here

| Agent | Scope (per ORCHESTRATION.md / FILE-OWNERSHIP.md) |
|-------|--------------------------------------------------|
| I-58 | `lib/features/feed/feed_screen.dart` + `feed_providers.dart` — **real feed foundation landed (2026-08-09)**; ⚙️ U-08 later restyles |
| I-59 | `lib/features/photos/photo_gallery_screen.dart` + upload flow |
| I-49/I-50/I-51 | Feature flags / repositories / typed REST client |
| I-52 | Realtime lifecycle (feed refresh signals) |
| I-72 | Pagination utilities (feed + gallery lists) |
| I-74 | Shared loading/error/empty state views (feed sections) |
| I-76 | `test/opt-004-photos.sh` (backend opt-test: signed URL access, like, report) |
| I-77 | pgTAP expansion (event_photos/event_photo_likes invariants) |
| I-78 | Full-matrix sweep |

## Acceptance checklist (from the step specs)

**FEED (`FEED-social-feed.md`):**
- [x] Feed foundation (I-58, 2026-08-09): featured carousel pinned + upcoming public events list sorted by `starts_at` ASC, radius chips (5/20/50/anywhere from `app_config`), empty/error states, pull-to-refresh, tap → event detail
- [ ] Three ordered sections (featured carousel, nearby events w/ distance, group posts) with empty states — distance display + group posts pending (geolocation + posts workstreams)
- [ ] Geo filter (options + default from `app_config`), location permission flow, denied → unfiltered + notice — chips + notice landed; device location permission is future work (`LocationService` doesn't exist)
- [ ] FAB → composer: multiline text + optional image + optional event-context selector (only own promotor events)
- [ ] Publish: deduct cost from config (`economy.feed_post_cost_shards`), insert `shard_ledger` (feed_post); insufficient-shards error with the required amount
- [ ] Free users: read-only feed; publish affordance shows "Publicar (solo PRO y VIP)" → upgrade prompt

**FEET (`FEET-featured-events.md`):**
- [ ] Feature request form (from event detail): contact info required, duration 7/14/30 days, notes; inserts `feature_requests` (pending); confirmation text per spec
- [ ] Status display on event detail: pendiente / aprobada / rechazada
- [ ] Featured display on feed: pinned carousel, subtle badge, expires at `featured_until`; unfeature drops to normal position
- [ ] Admin side already implemented (`samay events feature/unfeature/reject-feature` + push notifications wired by NTRG later)

**PHUP (`PHUP-photo-upload-gallery.md`):**
- [x] Foundation (I-59, 2026-08-09): gallery grid via signed URLs (`SignedUrlCache`: 1h TTL + 5m grace, per-photo, refresh on expiry), like toggle (optimistic + rollback, `event_photo_likes` + `likes_count` trigger), "{N} likes", long-press → report dialog (reason → `reports` row, `target_type='photo'`; photo stays visible), upload (gallery pick → PermissionService → compress → bytes upload → reload; progress spinner in the app bar)
- [x] Report dialog is crash-free (session 4: `TextEditingController` lifetime bug fixed — controller now owned by a `State` inside the dialog route)
- [x] Upload window enforcement (client): open while live + `events.photo_upload_window_hours` (24, config-driven) after `ends_at`; closed → notice + hidden upload (fail-closed on unknown end); server-side window check still open (S-03)
- [ ] Camera capture source ("tomar foto" option in the picker — currently gallery-only; `ImageSource.camera` behind `Permission.camera` is a follow-up), preview step before "Subir", access-verification Edge Function (attendee/group-member gate for `signed-url` — client uses the PostgREST RLS-gated `eph_read_access` for listing; the EF is the server-side hard gate), Hive caching of downloaded images (deferred to I-67)
- [ ] Fullscreen viewer with swipe navigation (follow-up; the grid + like/report/upload are the foundation)

**COLL (`COLL-photo-collage.md`):**
- [ ] Post-event "Collage del evento" section: top-N by likes (limit from config), grid layouts per photo count (1/2/3/4/5–6/7–9)
- [ ] Export: `RepaintBoundary` + GlobalKey → PNG → save to gallery; share; event name/date watermark
- [ ] Empty state: "No hay fotos del evento. ¡Sé el primero en subir una!"

## Phase exit gate

All 4 steps green in cross-references.md; feed no longer a static welcome; private
bucket + signed-URL access enforced (opt-004 tests both authorized and
unauthorized access); collage exportable; full matrix green.
