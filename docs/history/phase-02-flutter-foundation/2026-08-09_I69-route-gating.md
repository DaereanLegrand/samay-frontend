# 2026-08-09 — I-69: Feature-flag route gating audit + meta guard

**Agent:** I-69-route-gating · **Role:** `lib/core/router/**` feature-flag route gating (FILE-OWNERSHIP.md: `lib/core/router/**` feature-flag route gating | ⚙️ I-49)
**Deps:** I-49 (flag system: `AppFeatureFlag` enum, `featureFlagsProvider`, `FlagGate`, `ref.isEnabled`) ✅ · I-54 (events gate) ✅ · I-57 (qr gate) ✅ · I-59 (photoUpload gate) ✅ · I-61 (subscriptions gate) ✅ · I-62 (cosmeticsSection gate) ✅ · I-63 (minigames gate) ✅ · I-48 (conventions_test.dart guard suite) ✅ · I-64 (shards ledger live decision) ✅

---

## 1. Mission

Audit **every** `GoRoute` in `lib/core/router/app_router.dart`: each must be either
(a) live-unflagged or (b) wrapped in `FlagGate` with the correct flag. Close gaps,
then add a **meta guard** in `test/meta/conventions_test.dart` (I-48's file) that
enforces the audit forever (string/regex-based, no flutter binding). Verify
`ref.isEnabled` (Ref variant) usage. Keep `feature_flags_test` + `app_router_test`
green; full suite 0 failures.

## 2. Route → flag audit table (built from `app_router.dart` @ 459 lines, read line by line)

| Route | Screen | Flag | Verdict |
|---|---|---|---|
| `/` welcome | WelcomeScreen | — (auth) | ✅ live |
| `/banned` | BannedScreen | — (auth) | ✅ live |
| `/login` | LoginScreen | — (auth) | ✅ live |
| `/auth/signup` | SignupContactScreen | — (auth) | ✅ live |
| `/auth/verify` | OtpVerificationScreen | — (auth) | ✅ live |
| `/auth/age-gate` | AgeGateScreen | — (auth) | ✅ live |
| `/auth/privacy-terms` | PrivacyTermsScreen | — (auth) | ✅ live |
| `/auth/profile-setup` | ProfileSetupScreen | — (auth) | ✅ live |
| `/main/feed` | FeedScreen | **feed (LIVE)** | ⚠️ **GAP → closed**: flag documented as kill-switch (I-58) but route unwired; knob did nothing |
| `/main/groups` | MyGroupsScreen | — (live groups) | ✅ live |
| `/main/events` | VComingSoonScreen | events | ✅ gated (I-49) |
| `/main/notifications` | NotificationCenterScreen | notifications | ✅ gated (I-49) — kill-switch for the live tab |
| `/main/profile` | ProfileScreen | — (live profile) | ✅ live |
| `/event/:eventId` | EventDetailScreen/EventInviteRoute | — (live detail) | ✅ live (mission allowlist) |
| `/event/:eventId/edit` | EventEditScreen | — (live edit) | ✅ live |
| `/event/:eventId/invite` | VComingSoonScreen | **NO GATE** | ⚠️ **GAP → closed**: placeholder route with no flag knob (EINV feature) |
| `/event/:eventId/photos` | PhotoGalleryScreen | photoUpload | ✅ gated (I-59) |
| `/event/:eventId/collage` | VComingSoonScreen | **NO GATE** | ⚠️ **GAP → closed**: placeholder route with no flag knob (COLL feature) |
| `/group/create` | CreateGroupScreen | — (live groups) | ✅ live |
| `/group/:groupId` | GroupDetailScreen | — (live groups) | ✅ live |
| `/group/:groupId/members` | GroupMembersScreen | — (live groups) | ✅ live |
| `/group/:groupId/donate` | DonateShardsScreen | — (live shards) | ✅ live |
| `/group/:groupId/create-event` | CreateEventScreen | events | ✅ gated (I-54) |
| `/group/:groupId/invite` | InviteScreen | — (live groups) | ✅ live |
| `/minigames/:groupId` | MinigamesScreen | minigames | ✅ gated (I-63) |
| `/groups/leaderboard` | LeaderboardScreen | — (live groups) | ✅ live |
| `/chat/:chatId` | ChatScreen | **chat (LIVE)** | ⚠️ **GAP → closed**: live flag never consulted; kill-switch knob did nothing |
| `/user/search` | SearchScreen | — (live friends) | ✅ live |
| `/user/:userId` | PublicProfileScreen | — (live profile) | ✅ live |
| `/friends/requests` | RequestsScreen | — (live friends) | ✅ live |
| `/friends/list` | FriendsListScreen | — (live friends) | ✅ live |
| `/settings/blocked` | BlockedUsersScreen | — (live friends) | ✅ live |
| `/qr/:eventId` | AttendanceQrScreen | qr | ✅ gated (I-57) |
| `/scanner/:eventId` | QrScannerScreen | qr | ✅ gated (I-57) — same flag, correct |
| `/subscriptions` | PaywallScreen | subscriptions | ✅ gated (I-61) |
| `/party-finder` | PartyFinderScreen | partyFinder | ✅ gated (I-60) |
| `/cosmetics` | CosmeticsShopScreen | cosmeticsSection | ✅ gated (I-62) |
| `/shards/ledger` | ShardLedgerScreen | — (I-64 decision: live) | ✅ live |
| `/settings` | SettingsScreen | — (live) | ✅ live |
| `/settings/delete-account` | DeleteAccountScreen | — (live) | ✅ live |
| `/profile/edit` | EditProfileScreen | — (live) | ✅ live |

**Wrong-flag check:** none found — every pre-existing gate carries the flag of its
feature (events→events ×2, qr→qr ×2, photoUpload, minigames, subscriptions,
partyFinder, cosmeticsSection, notifications). The scanner shares the `qr` flag
with the attendance screen by design (QRAT/QRSC one knob — I-57).

## 3. Gaps closed (minimal diffs, all in `app_router.dart`)

1. **`/main/feed`** → wrapped in `FlagGate(flag: AppFeatureFlag.feed, child: const FeedScreen())`.
   I-58 flipped `feed` to `true` calling it the kill-switch/remote-config knob, but
   the route never consulted it — flipping the flag changed nothing. The gate makes
   the documented knob functional (default on → zero visual diff).
2. **`/chat/:chatId`** → wrapped in `FlagGate(flag: AppFeatureFlag.chat, fallback:
   VComingSoonScreen(comingSoonChatTitle/Body), child: ChatScreen(...))`. Same class
   of gap as feed: I-38 made chat live but the flag was a dead knob. The fallback
   restores the pre-I-38 localized coming-soon copy when the kill-switch is pulled
   (keys already exist in the ARB pair — no l10n churn).
3. **`/event/:eventId/invite`** → wrapped in `FlagGate(flag: AppFeatureFlag.events,
   fallback + child: VComingSoonScreen(comingSoonEventInviteTitle/Body))`. The
   placeholder had no release knob; EINV's invite screen belongs to the events
   feature, so the `events` flag is the knob. Both flag states render the identical
   coming-soon copy today (fallback = child), so zero visual diff; the feature agent
   swaps the child when the real screen lands.
4. **`/event/:eventId/collage`** → wrapped in `FlagGate(flag: AppFeatureFlag.photoUpload,
   fallback + child: VComingSoonScreen(comingSoonCollageTitle/Body))`. COLL is a
   phase-08 photos feature (`features/photos/collage_screen.dart` per spec), so the
   `photoUpload` flag is the knob (not `events`). Same zero-diff pattern as #3.

## 4. The meta guard (enforcement forever)

Extended I-48's `test/meta/conventions_test.dart` with group
**"feature-flag route gating (I-69)"**:

- **`liveRoutes` allowlist** (27 path expressions) — the (a) list: the 8 auth routes,
  `mainGroups`, `mainProfile`, `eventDetail`/`eventEdit`, the 6 group routes +
  leaderboard + donate, friends (search/requests/list/blocked), `userProfile`,
  `shardsLedger`, `settings`, `deleteAccount`, `profileEdit`. These are conscious
  live decisions (I-64's ledger note, mission allowlist).
- **`gatedRoutes` map** (14 route expressions → expected `AppFeatureFlag.*`) — the
  (b) list. NOTE: the mission brief's (a) list included feed/chat/notifications, but
  all three have documented kill-switch flags — `mainNotifications` was already
  gated, and this session wired feed + chat — so they live in `gatedRoutes` and the
  guard *requires* their gates. If a future agent flips one live and removes the
  gate, the guard forces a conscious move to `liveRoutes` instead of silently
  breaking the knob.
- **Parser** (no flutter binding, `dart:io` only): scans `app_router.dart` for every
  `GoRoute(`, extracts the balanced-paren block, pulls the `path:` value as its
  `RoutePaths` expression (`[A-Za-z0-9_.:'"/()]+` — formatting-agnostic, never
  resolves the literal string), then:
  - non-`liveRoutes` path without a `gatedRoutes` entry → **fail** ("no gate decision");
  - non-`liveRoutes` path whose block lacks `FlagGate` **or** its expected flag →
    **fail** ("expected FlagGate(<flag>)"); this also catches WRONG-flag regressions;
  - `gatedRoutes` entry missing from the file → **fail** (stale-map guard).

**RED evidence:** temporarily stripped the `FlagGate` from `/subscriptions` (held
lock, restored after) → guard failed with exactly
`RoutePaths.subscriptions: expected FlagGate(AppFeatureFlag.subscriptions) in its builder`.
Restored → green.

## 5. `ref.isEnabled` (Ref variant) — verified, NOT needed

The mission's item 4: `routerProvider`'s only redirect is `AuthGuard.call` (auth/banned
only — `lib/core/router/auth_guard.dart`). **No flag-dependent redirect exists or is
needed**: gated routes render their `FlagGate` fallback instead of redirecting, which
keeps deep links registered and the back-stack intact. `Ref.isEnabled`
(`extension AppFeatureFlagsRef on Ref`, feature_flags.dart:245) therefore has **no
call site in routerProvider today**; it remains the documented seam for a future
kill-switch redirect (the `authGuard` already holds the same `ref`). The extension
itself is covered by `test/core/feature_flags_test.dart` (`_refProbeProvider`, 2
tests) — documented as "the seam I-69's router gating will use", which is where it
stays by design. No code change.

## 6. Files modified (lock evidence — all `tools/agent_lock.sh`, owner `I-69-route-gating`)

| Path | Action | Lock |
|---|---|---|
| `lib/core/router/app_router.dart` | 4 gates (feed/chat/invite/collage) + RED probe | acquire 2026-08-10T16:22:15Z / held until release |
| `test/meta/conventions_test.dart` | guard group added (6th guard) | acquire 2026-08-10T16:22:15Z / held |
| `docs/to-fix/TODO.md` | I-69 workstream note (§8) | acquire 2026-08-10T16:22:15Z / held |
| `docs/history/phase-02-flutter-foundation/2026-08-09_I69-route-gating.md` | this log | acquire / held |

No locks were held by other agents at acquire time (`tools/agent_lock.sh list` empty).

## 7. Tests + results

| Command | Result |
|---|---|
| `flutter test test/meta/conventions_test.dart` (after gate edits) | **6/6 pass** (5 pre-existing + new route-gating guard) |
| RED probe (subscriptions gate stripped) | guard **fails** with the expected violation → restored |
| `flutter test test/meta/ test/router/ test/core/feature_flags_test.dart` | **151/151 pass** |
| `dart analyze` | **0 errors** (2 pre-existing non-errors in I-57's `qr_flow_test.dart` unused import + I-60's `user_service.dart` curly-braces info — untouched, reported) |
| `flutter test` (FULL suite) | **1516 pass / 0 fail** |

Behavior parity proof: `app_router_test.dart` (68 tests) stays green with the four
new gates because every default-flag state renders the identical screen —
`feed`/`chat` default `true` (real screens), `events`/`photoUpload` default `false`
(coming-soon fallback = previous copy, exact same widgets/text). The
`RoutePaths coherence` + `coming soon routes` groups are unchanged and pass.

## 8. TODO.md workstream note (queued in this log while I-52 held the lock — appended by I-69 under its own lock)

```
> **Route-gating audit + meta guard (I-69, 2026-08-09/10):** every GoRoute in
> `lib/core/router/app_router.dart` audited (38 routes) → route/flag table in the
> I-69 daily log. Gaps closed: `/main/feed` + `/chat/:chatId` now FlagGate-wrapped
> (their LIVE flags were documented kill-switches but dead knobs — the gates make
> them functional; chat fallback = existing comingSoonChat ARB copy), and the two
> orphan placeholders `/event/:eventId/invite` + `/event/:eventId/collage` gained
> FlagGate knobs (`events` resp. `photoUpload`; fallback = previous localized copy,
> zero visual diff). No wrong-flag gates found. `ref.isEnabled` (Ref) verified not
> needed in routerProvider — no flag-dependent redirect exists; the seam stays
> documented. NEW META GUARD in `test/meta/conventions_test.dart` (I-48's file):
> string-based (no flutter binding) — every non-liveRoutes GoRoute must contain
> FlagGate with its mapped flag; unknown routes fail with "no gate decision";
> stale gatedRoutes entries fail. RED-proven (stripped subscriptions gate → guard
> failed). Full suite 1516/0, dart analyze 0 errors.
```

## 9. Commands run (reproducibility)

```bash
export AGENT_NAME=I-69-route-gating
tools/agent_lock.sh list                                  # empty → acquire all 4 locks
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME"  # app_router, conventions_test, TODO.md, log
# edits (4 gates) + guard + RED probe (strip/restore subscriptions gate)
export PATH="/opt/homebrew/share/flutter/bin:$PATH"
flutter test test/meta/conventions_test.dart              # 6/6 → RED probe → 6/6
flutter test test/meta/ test/router/ test/core/feature_flags_test.dart   # 151/151
dart analyze                                              # 0 errors
flutter test                                              # full suite 1516/0
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"
```

## 10. Issues found (out of scope, reported — do not fix)

1. `integration_test/qr_flow_test.dart:1` unused `material.dart` import (I-57 file,
   warning) + `lib/core/services/user_service.dart:176` curly-braces info (I-60
   file) — pre-existing, not mine, blocked `dart analyze` from a perfect 0/0.
2. Feed kill-switch fallback is the generic coming-soon shell (no `feed` case in
   `FlagGate._defaultFallback`, no `comingSoonFeed*` ARB keys; I-58 left
   `feedWelcome`/`feedEmpty` unused). Acceptable for an emergency knob; a tailored
   fallback would need ARB keys (I-15 territory) — flagged, not touched.
3. NAV-08 (default tab transitions) and `/event/create` shadowing NOTE remain open
   (I-03/I-04/I-55 territory) — unchanged by this audit.

*Sources: go_router 14.x route matching (pub.dev/packages/go_router), Riverpod
Ref/WidgetRef extensions (pub.dev/packages/riverpod), repo conventions
(FlagGate fallback pattern per I-54/I-57/I-59/I-62; conventions_test style per I-48).*
