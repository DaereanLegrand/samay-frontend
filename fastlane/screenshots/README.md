# Store screenshots

Captured from the iOS **simulator** against the **testing** API
(`samay-api-testing.qallariy.lat`), app build `make build TARGET=simulator`.
The UI is Spanish-only (the app forces `Locale('es')`), so the set is `es-419`.

## Sizes (App Store slots)

- `iphone-6.9-*.png` — 1320×2868 (6.9" iPhone slot)
- `ipad-13-*.png` — 2064×2752 (13" iPad slot)

The app ships `TARGETED_DEVICE_FAMILY = 1,2`, so both slots are required.

## Coverage

Pre-auth screens only (login / signup / forgot password). Capturing the
authenticated experience (feed, events, chat, groups) needs a signed-in account,
which requires typing into the simulator (not automatable with the exposed
tooling) — the owner can capture those manually by running `make dev` and
signing in.

Candidates for a richer set (via `make dev TARGET=simulator`, signed in):
feed · event detail · QR check-in · event album · group chat · profile.
