# 2026-09-20 — Feed match-card avatar physics (gravity right + scroll)

**Branch:** worktree. Flutter-only: no backend/migration/pgTAP change. Adds one
pub dependency (`forge2d`).

## What was built

- **`AvatarPhysicsCluster`** (`lib/features/feed/widgets/avatar_physics_cluster.dart`):
  the feed match card's participant bubbles are now a tiny Box2D world
  (`forge2d`). Circular bodies (40–56 px, seeded per participant id) collide and
  pile against the card's right wall under a rightward base gravity
  (`7 m/s²`). The world is fixed-timestep stepped on a `Ticker`; the ticker
  stops once every body is asleep (Box2D sleeping) and restarts on scroll.
- **Scroll coupling**: the cluster binds the enclosing feed's `ScrollPosition`
  (in `didChangeDependencies`, so it re-binds if reparented) and converts each
  pixel delta into a vertical + horizontal velocity kick. Damping brings the
  bodies back to a right-wall rest, so the pile visibly surges while the
  timeline scrolls.
- **No direct drag, no accelerometer** (2026-09-20 directives).
- **Reduced motion**: `MediaQuery.disableAnimationsOf` skips the simulation and
  renders the previous deterministic static scatter.
- **Pool prize** (prior change) stays on the left as a bare shard icon + total;
  usernames are still not listed.

## Decisions / iterations (important)

The motion source changed three times in one session — record it so the final
state is not re-litigated:

1. First cut: scroll **and** tilt (accelerometer). User rejected the scroll
   reaction as too weak/unwanted and asked for gravity-right only.
2. Second cut: gravity + tilt only.
3. **Final**: gravity-right + **scroll** only, **no accelerometer**. The scroll
   kick was made much stronger (`_scrollKick = 14`, clamped) and the listener
   moved to `didChangeDependencies` — the earlier weak kick (~0.06 m/s) was
   imperceptible.

Other decisions:

- **forge2d pinned to `^0.14.0`** — 0.15+ binds native Box2D v3 through build
  hooks (C toolchain / native assets); 0.14.x is the pure-Dart port and adds no
  toolchain requirement.
- **`fixedRotation: true` on the bodies**: readable avatars, no spin.
- **Gravity is right-only** (`Vector2(7, 0)`): bubbles always pile on the right
  wall; scroll supplies the visible motion.

## Changes since the first cut

- Deleted `lib/features/feed/providers/device_tilt_provider.dart` and the
  `sensors_plus` dependency; removed `NSMotionUsageDescription` from
  `ios/Runner/Info.plist`.
- `pubspec.yaml` now carries only `forge2d: ^0.14.0`.
- **Card layout is now two columns** (`_MinigameMatchCard` is a `ConsumerWidget`):
  a fixed `_kMatchCardHeight = 128` row with the copy + pool stacked on the left
  (flex 2) and the avatar cluster filling the right (flex 3) at that full height
  — the bubble box is as tall as the card (2026-09-20 directive). The old
  `_MatchFooter` band was removed and the roster is watched once in the card.
- Bubble sizes tightened to **44–52 px** (was 40–56) and starting positions use
  an **unseeded** `Random()` per card instance (was id-seeded deterministic).
- Bubbles **pop in** on first appearance: a 260 ms ease-out-back scale, each
  starting ~100 ms after the previous (± up to 40 ms random). Driven off the
  existing physics ticker's `_age` accumulator (no extra controller), and the
  ticker now stays alive until both the pop and the settling are done.

## MISTAKE blocks

- **MISTAKE — `flutter pub get` re-downgraded `intl`/`meta`/`vector_math`.**
  Running it to add/remove deps re-resolved to intl 0.20.2 / meta 1.18.0 /
  vector_math 2.2.0 (the SDK-pinned trio documented in
  `2026-09-20_social-games-tab.md`). Restored the HEAD versions (intl 0.20.3 /
  meta 1.19.0 / vector_math 2.4.2, with their sha256 blocks) by hand-editing
  `pubspec.lock`. `dart analyze lib` (not `flutter pub get`) is the safe
  day-to-day check.
- **MISTAKE — `.flutter-plugins-dependencies` churn.** `pub get` rewrites its
  `date_created` (and, while `sensors_plus` existed, its plugin list). Restored
  to HEAD with `git show HEAD:.flutter-plugins-dependencies > …` so the commit
  carries only the intentional change.

## Commands run

```bash
export AGENT_NAME=feed-match
tools/agent_lock.sh acquire pubspec.yaml pubspec.lock \
  lib/features/feed/widgets/avatar_physics_cluster.dart ios/Runner/Info.plist \
  docs/specs/steps/phase-08-social-feed-photos/FEED-social-feed.md --owner feed-match

flutter pub get                 # then restored intl/meta/vector_math in the lock
dart analyze lib                # No issues found
```

## Verification / open items

- `dart analyze lib`: clean.
- Scroll feel/gain (`_scrollKick`, damping) is tunable but not device-tuned by
  an agent; the numeric constants live at the top of the widget.
- No native plugin remains, so a plain hot reload works (no `pod install`).
