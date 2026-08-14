# Plugged UI — Dead-End Elimination: Home Games, Live Actions, Chat, Collage (2026-08-13)

**Agent:** plugged-entries session (docs↔code audit follow-up) · **Branch:** `fixes` · **Worktree:** post-`18b8c8b` (uncommitted session, same date)

## What was built

Eliminates the remaining dead-ends the audit flagged: screens that existed but had **no button wiring** anywhere. Every new entry is **flag-gated**, rendering-only (routes/providers/flows/E2EE untouched).

| Entry | Where | Behavior |
|---|---|---|
| Games quick-access row | `feed_screen.dart` (`_GamesSection`) | 5 minigame cards + Party Finder card under the hero, `sectionLabel` heading, cyan `VGlassCard`s. Tap: no groups → "No groups yet" snackbar; 1 group → straight to `RoutePaths.minigames(groupId)`; several → "Choose a group" bottom sheet. Flags: `minigames` / `partyFinder` |
| Live-actions row | `event_detail_screen.dart` (`_buildLiveActions`) | QR attendance + promotor scanner + photo gallery buttons; hidden once status is `ended`/`cancelled`. Flags: `qr` / `photoUpload` |
| Minigames hub button | `group_detail_screen.dart` | Adjacent to the promote button, flag `minigames` |
| Collage-wall entry | `photo_gallery_screen.dart` | `photos-wall-button` IconButton in the gallery AppBar → `RoutePaths.eventCollage` |
| "Enviar mensaje" | `public_profile_screen.dart` (`_openChat`) | Only for `accepted` + unblocked friends, flag `chat`; resolves/creates the E2EE direct chat via `createDirectChat` → `/chat/:chatId` |
| Shared game meta | `lib/features/minigames/logic/minigame_meta.dart` | `minigameGameName` + `minigameIcon` extracted from `minigames_screen.dart` so home/hub/session list name & icon each game identically |

Supporting changes:

- **l10n:** 6 new keys en/es (`profileMessage`, `homeGamesTitle`, `homePartyFinderBody`, `minigamesChooseGroup`, `minigamesNoGroups`, `minigamesNoGroupsBody`) + the 3 generated files (gen-l10n output, hand-applied).
- **Tests:** `test/features/plugged_entries_test.dart` (10 `testWidgets` — every entry navigates to its real route; blocked-user hides "Enviar mensaje"; closed event hides live actions). `feed_test.dart`/`restyle_test.dart` now pin the feed's event layout with `minigames/partyFinder` flags off (coverage lives in plugged_entries_test). `conventions_test.dart` raw-spinner allowlist line refreshed for the gallery AppBar (148 → 157).
- **Misc:** `supabase/seed.sql` + `supabase-testing/seed.sql` system-admin email → `system@samay.example.com` (DEPLOYMENT-PLACEHOLDER R03 convention; audit P3). `cmd/samay-api-server/main.go` stale 8080 comment removed (PORT is 8090).

## Decisions

- **Flag-gated everywhere, kill-switch style** — same policy as the I-69 route-gating sweep; `ref.isEnabled` (Ref) read, no new config keys.
- **Hidden-on-closed** for live actions (ended/cancelled events show no QR/scanner/photos) — a closed event has no attendance to scan.
- **Groups resolution lives in the feed entry** (await `myGroupsProvider.future` on first tap; never a synchronous `.valueOrNull` — always null/loading on first build).
- **No new route, no new screen** — every target already existed; only entry points were added.

## Mistakes / gotchas

- **MISTAKE:** `public_profile_screen.dart:314` — two statements on one line (`final l10n = ...; if (_isBlocked) {`) slipped in; caught by the docs↔code re-audit format probe (`dart format --set-exit-if-changed`). Fixed + verified. Lesson: run the format gate on the whole session before committing.
- **MISTAKE:** the feed's games cards must NOT be covered by feed_test's event-layout pins — the suites pin different concerns; explicit flag-off overrides keep both green.

## Commands run

```bash
dart format --set-exit-if-changed lib/features/profile/screens/public_profile_screen.dart
dart analyze
flutter test test/features/plugged_entries_test.dart test/features/feed/
go test ./...
```

## Validation

- `dart analyze` 0 issues · `dart format` clean · `flutter test` full suite green · `go test ./...` 182 green.
- Manual QA: `test_runner.sh` +13 cases (section 8, plugged entries) → 68 total.

## Follow-ups

- COLL PNG export still pending (photo wall reachable only); PUSH/FLMT/RCBH/etc. unchanged (still correctly ❌ in cross-refs).
- Party-finder match-card "Enviar mensaje" (TODO I-60 deferred) is a different surface — still open.
