# Samay — Flutter client

Samay is a party/minigames app for groups of friends: four games, one-tap
guest onboarding, and either a single shared phone or a multi-device session.

- Client: <https://github.com/DaereanLegrand/samay-frontend>
- Backend: <https://github.com/DaereanLegrand/samay-backend>

## What this is

- **Games only.** Verdad o Reto, Botella, 2 Mentiras 1 Verdad and Charadas.
  There is no bottom navigation: the app opens on a list of the four games, and
  social, packs, notifications, profile and settings live in the header menu.
- **Guest-first.** One tap ("aceptar y jugar") creates an anonymous account and
  records the 18+/terms acceptance. Apple/Google sign-in is optional and links
  onto the same account (same uid).
- **Two play modes.**
  - Single device ("pass the phone"): fully local, no server session, two or
    more players on one phone, prompts from a cached pack.
  - Multi-device: a server session joined with a 6-character code or QR
    (`samay://join/<CODE>`), with E2EE answers.
- **Prompt packs** are served by the backend, cached on device for offline play,
  and some are gated by subscription tier (RevenueCat).
- **This is a slim build.** Events, chat, feed, photos, rankings, shards/wagers
  and cosmetics were removed and will be re-added progressively.

## Requirements

- Flutter 3.44.1 (the version the Android wrapper and pods were verified
  against); the app requires Dart SDK `^3.11.4` (`pubspec.yaml`)
- Xcode with CocoaPods (iOS) or the Android SDK and a device/emulator
- `gum` — `make init` is an interactive script
- A reachable backend: run the [backend
  repo](https://github.com/DaereanLegrand/samay-backend) locally, or point `.env`
  at your own project

## Quick start

Run the backend first. For `ENV=testing-local` the Makefile reads the local
stack's JWT secret and anon key from the backend checkout (override the location
with `LOCAL_JWT_ENV`) and expects Kong on port 54386. Then:

```sh
flutter pub get
make init ENV=testing-local    # interactive; choose "local" to write .env
make start ENV=testing-local   # = make dev; runs against the local stack
```

`ENV` is required on every run/build verb and is one of
`testing-local | testing | staging | prod`.

## Project layout

| Path | What lives there |
|---|---|
| `lib/core/` | config, no-nav router, providers, services, theme |
| `lib/features/minigames/` | the four games; the single-device engine is in `local/` |
| `lib/features/packs/` | prompt-pack service, cache-first repository, catalogue |
| `lib/features/auth/` | the single consent gate and optional account linking |
| `lib/features/{friends,groups,notifications,profile,social}/` | header-menu screens |
| `lib/crypto/` | E2EE primitives used by multiplayer answers |
| `test/` | Dart tests, including `local_match_test.dart` |

The server side (self-hosted Supabase + Go admin API) lives in the
[backend repo](https://github.com/DaereanLegrand/samay-backend).

## Testing

```sh
flutter test     # Dart unit tests (102 currently)
make analyze     # dart analyze
make test        # Makefile static gate (test/opt-008-makefile-static.sh)
make check       # dart analyze + flutter analyze + secret scan
```
