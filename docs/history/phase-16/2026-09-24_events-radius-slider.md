# 2026-09-24 — Events tab: single 0-off radius slider (chips + "Cerca de mí" gone)

Agent: `events-radius-slider` / `events-radius-slider-2`. Branch:
`truth-or-dare-leaderboard`.

## What was built

The Events-tab distance filter is now one **radius `Slider`** with its value to
the right. The km chip row (`RadiusFilterBar`) and the "Cerca de mí" `Switch`
are removed.

- **Slider:** 0–100 km in 5 km steps. **`0` = deactivated** (no distance
  filter); the user drags up to activate. At 0 only the faint inactive track
  paints and the thumb stays visible.
- The slider is **disabled until a reference point exists**. Setting the point
  is via **"Usar mi ubicación"** (device GPS) or **"Elegir ubicación"** (the map
  picker). Once a point exists the pick button's label **becomes the chosen
  location** — `Coordinates: {lat, lng}` (`locationPickerCoordinates`; there is
  no geocoder). The "Sin ubicación disponible…" notice is gone.
- The header filter action icon changed `tune` → `location_on`
  (`location_on_outlined` when closed).

## Code

- `event_radius_filter.dart`: `RadiusFilterBar` / dead `EventRadiusHeader`
  deleted; new `RadiusSlider` = `Row[ Expanded(Slider), "{n} km" ]`.
- `event_radius_providers.dart`: `kEventRadiusMinKm` → **0**, `MaxKm` 100,
  `StepKm` 5; `EventRadiusFilterNotifier.build()` → 0; removed the now-unused
  `eventRadiusDefaultProvider` / `parseEventRadiusDefault`.
- `event_discovery_providers.dart`: `eventDistanceFilterEnabledProvider` (the
  old checkbox bool) and its notifier deleted; the filter gate is now
  `hasNearby = point != null && radius > kEventRadiusMinKm`.
- `my_events_screen.dart`: `_LocationControls` keeps both buttons, drops the
  notice, and the pick button morphs to the coordinates; the boolean writes in
  `_useMyLocation` / `_pickLocation` are gone.
- `app_theme.dart`: monochrome `sliderTheme` (white active/thumb, `border`
  inactive, `muted`/`surfaceAlt` disabled, trackHeight 2).
- l10n: removed `feedRadiusAnywhere`, `eventsNearbyToggle`,
  `eventsFilterByDistance`; `eventsPickLocation` value → "Elegir ubicación" /
  "Pick location"; regenerated (`flutter gen-l10n`).

## Decisions

- **0 = off**, not a separate checkbox: the slider position itself is the gate
  (per user directive "default 0, drag up to activate").
- Slider **disabled without a location** — picking a point is the explicit
  prerequisite, so the control never sits in a silent no-op state.
- Both location buttons are kept (explicit user directive); the map picker
  already opens in map mode and carries its own "my location" FAB.

## Commands

```bash
flutter gen-l10n
dart analyze lib    # No issues found!
```

## Notes

- `feed.nearby_radius_km_default` / `feed.nearby_radius_km_options` remain
  seeded server-side but are no longer read by the client (slider bounds and
  default are code constants).
- No dev events seed exists (the old one lived in the retired `seed-dev.sql`);
  sample events with `location_lat/lng` would still be useful to exercise the
  slider. Tracked separately.
