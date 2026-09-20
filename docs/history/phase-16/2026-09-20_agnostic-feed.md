# 2026-09-20 — Agnostic feed revamp (remove games row + Party Finder)

Agent: `agnostic-feed`. Branch: `truth-or-dare-leaderboard` (working tree).

## What was built

- **Agnostic feed** (`lib/features/feed/`): the timeline now mixes public
  upcoming events with the user's minigame matches instead of events only.
  - `FeedItem` sealed union (`lib/core/models/feed_item.dart`):
    `FeedEventItem` + `FeedMinigameItem`, with `activityAt` /
    `fromParticipant` and JSON round-trip.
  - `FeedNotifier` composes `EventService.listEvents('upcoming')` (public
    only) with `MinigameService.listMySessions()` and
    `listMyPendingInvites()`; sorts pending participant matches first, then
    featured events, then most-recent activity.
  - On-device cache: new `feed_cache` Hive box + `cacheFeed`/`getCachedFeed`/
    `clearCachedFeed` in `HiveService`; cache-first render, network refresh.
- **Removed from the feed**: the games quick-access row and the Party Finder
  card. New minimal, match-specific card.
- **Match card redesign**: bare row on black (no muted outlined `VCard`) with
  right-aligned overlapping Apple-Watch-style avatar bubbles and the
  participants' usernames as individual labels (never comma-joined), driven
  by `minigameParticipantsProvider`.
- **Empty state**: `feedAllCaughtUp` "Estás al día" / `feedComeBackLater`
  "Regresa más tarde" (replaces "No hay eventos próximos").
- **Party Finder removed** (client): deleted `lib/features/party_finder/`,
  `RoutePaths.partyFinder`, `AppFeatureFlag.partyFinder`, the router import +
  route, the notifications route entry, the auth-scope reset entry,
  `DiscoveryService.findMatches`, `UserService.get/setDiscoveryOptIn` +
  `getMyInterestTags`, and all `partyFinder*` / `homePartyFinderBody` l10n
  keys. `DiscoveryService.searchUsers` stays (user search).
- **Unplugged minigames removed** (client): `MinigameType` reduced to the four
  plugged games (`truth_dare`, `drunk_bottle`, `two_lies_one_truth`,
  `charades`); dropped `poke_chain`, `questions`, `challenge` from
  `minigame_meta.dart` switches, the minigames hub meta, and their l10n keys.
- **Radius filter moved to the Events tab**: new
  `lib/features/events/providers/event_radius_providers.dart` +
  `lib/features/events/widgets/event_radius_filter.dart`; `MyEventsScreen`
  renders `EventRadiusHeader` at the top (also when empty). Removed from the
  feed and from `feed_providers.dart`.
- **l10n**: added `feedAllCaughtUp`, `feedComeBackLater`, `feedMinigameInvite`;
  removed event/party/game-specific keys; regenerated.

## Evaluation (3 rounds, iPhone simulators)

- Round 1 (iPhone 17 Pro): no games row / no Party Finder PASS; agnostic card
  rendered; empty state code-correct but not visually reachable on the test
  account; radius chips missing on the Events tab when empty (fixed).
- Round 2 (iPhone 18 Pro Max): card content correct but participant block was
  center-left, not flush-right (root cause: `_MinigameMatchCard` Column
  `crossAxisAlignment.start` shrink-wrapped `_ParticipantsRow`).
- Round 3 (iPhone 18 Pro Max): right-align fix verified — usernames flush to
  the card's right gutter, bubbles flush within ~2 pt (container ring inset),
  no overflow/clipping, no crash; no games/party entries; Events radius chips
  + "Sin ubicación disponible" present with zero events.

## Decisions / notes

- `feedMinigamePlayers` was added then removed once the card switched from a
  count to the roster bubbles.
- Backend cleanup is still pending and intentionally out of this session's
  shipped scope: dropping `discovery_view` / `users.discovery_opt_in` /
  `set_discovery_opt_in`, recreating the `mini_game_type` enum without the
  three unplugged values, and mirroring both to `supabase-testing/`. The
  client no longer references any of them, so they are inert.
- The feed does not yet use a server-side `get_feed` RPC; recency is derived
  client-side from existing timestamps (matches + events), cached on device.

## Commands run

```bash
flutter pub get
flutter gen-l10n
dart analyze lib            # No issues found
# Xcode MCP: DeviceInteractionInstallAndRun → subagent screenshots per round
```
