# 2026-09-20 — Games tab + Social redesign + unified Rankings

**Branch:** `truth-or-dare-leaderboard` (working tree). Flutter-only; no
backend/migration/pgTAP change. Built on top of the `agnostic-feed` commit
(8a3f112), which had already reduced `MinigameType` to the four plugged games
and removed the feed games row + Party Finder.

## What was built

- **Games bottom-nav tab** (`/main/games`, `games_tab_screen.dart`): a minimal
  column list of the four plugged games (`MinigameType.values` — Verdad o
  Reto, Botella, 2 Mentiras 1 Verdad, Charadas), icon + Title Case name, whole
  row tappable → the per-game page. Per-game pending-invite `VCountBadge`.
  Gated on `AppFeatureFlag.minigames` like the other shell tabs.
- **Compact 6-tab nav** (`main_shell.dart`): Feed · Social · **Games** ·
  Eventos · Notis · Perfil. Smaller icons (22), per-tab padding 8×6, container
  6×6, outer padding 16/12, radius 14 ("smaller, tighter rounded corners, less
  spacing"). Badges are now per-tab: Social = friend requests + group invites,
  Games = pending minigame invites.
- **Social redesign** (`social_screen.dart`, `groups_tab_screen.dart`,
  `amigos_tab_screen.dart`): the per-segment action-tile rows are gone. Header
  carries search + a single shared **trophy → `/rankings`** entry, plus one
  contextual action ("+" create group on Grupos; requests icon with the pending
  badge on Amigos). Grupos = big cover cards (`VNetworkImage` 160 band, name,
  shard count, invite badge when invited); Amigos = large 56px avatar rows.
- **Unified Rankings** (`rankings_screen.dart`, `/rankings`): one screen with a
  `Usuarios | Grupos` switch, replacing `/ranking/users` +
  `/groups/leaderboard` and their screens. The Grupos segment keeps the
  Micro/Small/Medium/Large tier chips.
- **l10n**: added `shellGames`, `rankingsUsers`, `rankingsGroups`,
  `groupsCreateGroupAction`; removed the orphaned `groupsRanking`,
  `groupsLeaderboardTitle`. Regenerated with `flutter gen-l10n`.
- Deleted `leaderboard_screen.dart`, `user_ranking_screen.dart`,
  `social_action_tile.dart`.

## Decisions

- **"Fully plugged" = `MinigameType.values`.** The agnostic-feed commit already
  dropped `poke_chain`/`questions`/`challenge`; the Games tab simply iterates
  the enum, so the plugged catalog can never drift from the enum.
- **One Rankings surface.** Two sub-tabs each carried an identical "Ranking"
  tile pointing at different destinations — the user cannot tell which ranking
  they will get. Collapsed to a single entry with an explicit Users|Groups
  switch.
- **Header casing rule.** All visible labels are Title Case; the only verbatim
  surface is the page Header (`VDisplayText`/`VHeaderSliver` title: "social",
  "juegos", "ranking"). This is why `groupsCreateGroup` (the create-group
  **Header**) had to stay lowercase and a new `groupsCreateGroupAction` was
  added for the buttons.
- **Minimalism.** No game imagery (Material icons only), no chevrons, no
  button chrome in lists.

## MISTAKE blocks

- **MISTAKE — `flutter build`/`gen-l10n` downgraded `pubspec.lock`**
  (intl 0.20.3→0.20.2, meta 1.19.0→1.18.0, vector_math 2.4.2→2.2.0). Reverted
  with `git show HEAD:pubspec.lock > pubspec.lock` (agents are denied
  `git checkout`). `dart analyze lib` — not `flutter analyze` — avoids it.
- **MISTAKE — concurrent `flutter run` sessions break `flutter build`.**
  Two live dev sessions held `build/ios`, so `flutter build ios --simulator`
  failed with "Failed to copy Flutter framework" (status 255). The human killed
  them; then the Xcode MCP flow worked.
- **MISTAKE — the xcode MCP `device-interaction` skill is unavailable** and its
  "type text" verb could not be discovered (`type`/`kbd` both rejected). Device
  rounds were driven through the `general` subagent (tap via `t x y`); login
  was never needed because the app restored an authenticated session.
- **Review catch — `groupsCreateGroup` is also the create-group page Header**,
  so changing its value to Title Case leaked "Crear grupo" into a verbatim
  header. Split into `groupsCreateGroupAction`.

## Commands run

```bash
export AGENT_NAME=social-games
tools/agent_lock.sh acquire <paths> --owner social-games

flutter gen-l10n
dart analyze lib            # No issues found
git status --short pubspec.lock   # clean

# Xcode MCP: DeviceInteractionInstallAndRun → subagent screenshots
```

## Verification (agent rounds)

- **Round 1** — device: 6-tab nav, Games column list, Social header icons +
  Grupos cover card, `/rankings` with Users|Groups. Reviewer: 0 analyze issues,
  pubspec.lock clean, no dangling refs; 4 findings (Header casing, route
  allowlist drift, missing invalidate after create-group, no card ripple).
- **Round 2** — fixes applied. Device: create-group Header is lowercase
  `crear`; Games list + cover cards + Ranking chips correct. docs-verifier:
  README / test_runner / cross-references / test/README updated for the Games
  tab, the consolidated Rankings, and the removed feed games row + Party Finder.
- `Amigos` (friends list) and the Users ranking show a **backend server error**
  on the remote prod stack ("Error del servidor") — unchanged providers, a
  backend/env condition, not this UI change; the Grupos ranking is a genuine
  empty state.

## Out of scope / notes

- Group **role** badges (owner/host) were dropped from the Grupos list as part
  of the minimal redesign — role remains visible on group detail.
- The new group cards use the app-wide `InkWell(child: VCard(...))` pattern
  (like the feed event cards), so the ink splash is occluded by the opaque
  card; kept for consistency rather than diverging one card.
- Backend cleanup from the agnostic-feed commit (dropping `discovery_view`,
  `users.discovery_opt_in`, recreating `mini_game_type` without the three
  unplugged values) is still pending and untouched here.
