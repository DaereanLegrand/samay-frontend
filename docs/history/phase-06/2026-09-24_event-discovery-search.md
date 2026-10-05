# 2026-09-24 — Event discovery search + Events tab (RPC, map, header scrim)

## What was built

- **`131_events_search/01_events_search.sql`** (authored in `supabase/migrations/`,
  mirrored byte-identical into `supabase-testing/migrations/`; applied
  incrementally to the running testing stack):
  - `public.haversine_km(lat1,lng1,lat2,lng2)` — NULL-safe great-circle
    distance (plain SQL maths; no PostGIS/cube).
  - `public.search_events(p_query, p_lat, p_lng, p_radius_km, p_limit)` —
    SECURITY DEFINER, `search_path=''`, mirrors the `search_users` OWASP API4
    hardening: auth gate (`SR003`), query length 2..50 (`SR002`), shared
    60/rolling-minute quota (`search_rate_limits` → `SR001`), LIKE-wildcard
    escaping, `events_read_access` scope, plus **server-side distance
    filtering hard-capped at 100 km** and the accepted-friend signal
    (`friends_going`, `friends_pending`, `score = going + 0.5*pending`).
    Order: score → distance → `starts_at`; `LEAST(p_limit, 50)`.
- **Tests**: pgTAP Section 61e (`plan 1001 → 1023`, +22) in both
  `schema_test.sql` mirrors; `test/opt-033-events-search.sh` (7/7);
  `test/run_all_backend.sh` + `test/README.md` updated (32 scripts).
- **Config**: `feed.nearby_radius_km_options` `5,20,50,999` → `5,20,50,100`
  (both seeds; running testing DB `app_config` updated).
- **Flutter**: `Event` gains `location_lat/lng` (numeric-safe decode);
  `EventDiscoveryHit`; `EventService.searchEvents`; `eventDiscoveryProvider`
  (+ query/nearby/reference providers); `error_mapper` maps `SR002`/`SR003`;
  the Events tab now has search / filter / `+` header actions, a collapsible
  search + km panel ("Cerca de mí" — device GPS or manual picker), and
  friend/distance card badges; a shared location picker
  (`LocationPickerSheet` — link / coords / map, `tiles.qallariy.lat`) and
  `RetryVectorTileProvider` / `MapsLinkService` / `LocationService`;
  `create_event_screen` + `event_edit_screen` capture coordinates;
  `VHeaderSliver` gets a top scrim gradient.
- Platform: iOS `NSLocationWhenInUseUsageDescription`; Android
  `ACCESS_FINE/COARSE_LOCATION`.

## Decisions

- New migration folder `131_…` (not `060_events/10`) so it sorts **after**
  `130_search` and can reuse `search_rate_limits` on a fresh init.
- Radius is *clamped* to 100 km server-side (not rejected), so a custom
  reference point (e.g. NYC) is still searched within 100 km.
- Selected tiles/location stack matches the reference app for consistency;
  `geolocator` pinned to `^14.0.2` (14.0.3's `package_info_plus`/`win32`
  bump conflicts with `flutter_secure_storage 9.2.4`).

## MISTAKE / gotcha

- **LATERAL with no outer reference is evaluated once.** The first Arequipa
  seed produced 100 identical rows (same type/status/coords). Fix: correlate
  the lateral (`WHERE g IS NOT NULL`) to force per-row evaluation.
- **`is(double precision, numeric, unknown)` has no pgTAP overload** — cast
  both sides (`score::numeric`, `1.5::numeric`).
- **`assert_event_capacity` freezes capacity to the free tier (7)** — pgTAP
  fixtures must use `capacity <= 7`.
- **`apply_migrations.sh` re-runs the whole tree**, so a new migration on an
  already-initialised DB must be applied file-by-file (done via
  `docker exec samay-testing-db psql`), never by re-running the flow.

## Commands run

```bash
docker exec -i samay-testing-db psql -U postgres -d postgres -v ON_ERROR_STOP=1 \
  < supabase-testing/migrations/131_events_search/01_events_search.sql
make supabase-db-test            # 1023 assertions; only pre-existing test 210 fails
bash test/opt-033-events-search.sh
docker exec samay-testing-db psql ... -c "UPDATE app_config SET ... WHERE key='feed.nearby_radius_km_options';"
flutter pub get && dart run build_runner build && flutter gen-l10n
dart analyze lib                 # 0 issues
```

## Notes / follow-ups

- `make supabase-db-test` test 210 ("users table empty after init/reset") fails
  on this stack by design: it asserts a zero-user DB but the stack carries the
  explicit `@tester` seed + the seeded Arequipa organizers. Pre-existing /
  environmental, not introduced here.
- The shared header change landed as a **top scrim gradient** only. Making the
  expanded hero *not reserve layout space* (true overlay) is a larger,
  app-wide sliver refactor — left out pending an explicit visual pass.
