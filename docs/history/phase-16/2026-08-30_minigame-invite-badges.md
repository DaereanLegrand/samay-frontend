# 2026-08-30 — Minigame invite badges + invitee partida-N

## What was built

When a user invites friends to a partida, the invited friends now (a) get a
red `VCountBadge` per game on the feed's minigame tiles, and (b) SEE the
invited partida — with its name (`partida-1`) — in the minigame UI ready to
accept, without already being a participant.

- **Migration `170_minigame_invite_badges`** (`supabase/migrations/` +
  byte-identical `supabase-testing/` mirror):
  - `minigame_sessions.auto_name text` — the SERVER-computed `partida-N`
    running number per `game_type` among ACTIVE sessions. Canonical for
    creator AND invitee (resolvable from the row in isolation). The 160
    client-side index-based name is kept only as a fallback for rows fetched
    before 170. Duplicate names are explicitly allowed.
  - `create_minigame_session` (`CREATE OR REPLACE`, same 5-arg signature)
    computes + stores `auto_name` at creation.
  - `notify_minigame_invite` redefined: the 140 early-return for DIRECT
    sessions (`group_id IS NULL`) is GONE — direct invites (the feed's
    default scope) now notify the invitee. The payload also carries
    `gameType` + `sessionName` so the client groups the badge per game type
    without an extra round-trip.
- **`MinigameService.listMyPendingInvites()`** — the invitee's pending
  invites as SESSION rows (two reads: pending `minigame_invites` via
  `mi_read_own`, then one `getSession` per id via `ms_read_invitee`).
  `_columns` gained `auto_name`.
- **Providers** (`minigames_providers.dart`):
  - `pendingMinigameInvitesByTypeProvider` — unread `minigame_invite`
    notifications grouped by `data['gameType']`.
  - `myPendingInvitesProvider` — the pending-invite session list, live via
    the notification stream (`await ref.watch(notificationsProvider.future)`).
- **Feed** (`feed_screen.dart`): `_HomeGameCard` renders a top-right
  `VCountBadge` (count of invited matches for that game type) — the same
  badge voice as the shell Grupos-tab badge.
- **Per-game page** (`minigame_detail_screen.dart`): the ongoing list now
  also renders the user's PENDING invited matches (`partida-N` + a
  "Invitación pendiente" chip), tap → session detail accept/decline. The
  empty state respects pending invites.
- **Session detail** (`minigame_session_detail_screen.dart`): shows the
  partida name (user title or canonical `partida-N`) under the game title.
- **l10n**: `minigamesInvitePending` ("Invitación pendiente" / "Pending
  invite") added to both `.arb` files + regenerated.

## Decisions

- **Server-side auto_name over client index.** 160's client-side `partida-XX`
  (list index) is not resolvable for a session shown by itself, and it could
  differ between creator and invitee. Storing the canonical `partida-N` makes
  the invitee's detail/pending row match the creator's list exactly. The
  user-supplied `name` still wins in display.
- **Notification-driven badge count.** Reusing the unread `minigame_invite`
  notifications (already the source for the shell badge) avoids a new query;
  the realtime listener keeps the feed badge live. The `gameType` in the
  payload lets the feed group per tile without a round-trip.
- **Both scopes notify.** The old early-return meant direct sessions (the
  feed's default scope) never notified — a silent hole in the invite flow.
- **`myPendingInvitesProvider` watches `notificationsProvider.future`**, not a
  plain `ref.watch` — the plain watch caused a Riverpod double-build deadlock
  (the notifier rebuilt while its dependency was loading).

## Tests

- `test/features/minigames/minigame_rpc_migration_test.dart` (+1 group):
  migration 170 exists in both stacks (byte-identical), adds `auto_name`,
  redefines create via CREATE OR REPLACE storing `auto_name`, notify fires
  for both scopes with `gameType`/`sessionName`, pgTAP Section 49f pinned.
- `supabase/tests/schema_test.sql` + mirror: **Section 49f (+7 assertions →
  plan(765))**.
- `test/features/minigames/minigame_service_test.dart` (+2): `listMyPendingInvites`
  filter shape (`invitee_id` + `status=pending`) and stale-session skip.
- `test/features/minigames/minigames_providers_test.dart` (+4):
  `pendingMinigameInvitesByTypeProvider` grouping (read excluded, non-minigame
  excluded, empty-while-loading) + `myPendingInvitesProvider` load/refresh.
- `test/features/plugged_entries_test.dart` (+1): the feed tile's `VCountBadge`
  count equals the game type's unread invite count; games without invites
  render none.
- `test/features/minigames/minigame_detail_screen_test.dart` (+1): a pending
  invite renders `partida-1` + "Invitación pendiente".
- `integration_test/minigames_flow_test.dart` (+1): invitee perspective — the
  per-game page shows the invited `partida-1` and tapping it opens the
  accept/decline detail.
- `test/opt-016-minigames-invites.sh` (+TEST H): a DIRECT invite notifies the
  invitee with `gameType` in data, and the session row carries `auto_name`.
- Full `flutter test` = **1892 pass / 0 fail** (+13); `flutter analyze` 0
  issues; `go vet` + `go test ./...` green.

## Commands run

```bash
make test-file FILE=test/features/minigames/minigame_rpc_migration_test.dart   # 61 pass
make test-file FILE=test/features/minigames/minigame_service_test.dart          # 47 pass
make test-file FILE=test/features/minigames/minigames_providers_test.dart       # 28 pass
make test-file FILE=test/features/minigames/minigame_detail_screen_test.dart    # 5 pass
make test-file FILE=test/features/plugged_entries_test.dart                     # 5 pass
make test-feature FEATURE=minigames                                             # 182 pass
flutter gen-l10n                                                               # regenerate l10n from .arb
flutter test integration_test/minigames_flow_test.dart -d <sim>                 # 4 pass
make flutter-test                                                               # 1892 pass / 0 fail
make flutter-analyze                                                            # 0 issues
go vet ./... && go test ./...                                                   # green
bash -n test/opt-016-minigames-invites.sh                                       # syntax ok
# pgTAP + opt-016 runtime need the Samay stack up — not available this session
```

## Files created/modified

- `supabase/migrations/170_minigame_invite_badges/invite_badges.sql` (new)
- `supabase-testing/migrations/170_minigame_invite_badges/invite_badges.sql` (mirror)
- `supabase/tests/schema_test.sql` + `supabase-testing/tests/schema_test.sql`
  (Section 49f, plan 758 → 765)
- `lib/core/services/minigame_service.dart` (`auto_name` column,
  `listMyPendingInvites`)
- `lib/features/minigames/providers/minigames_providers.dart`
  (`pendingMinigameInvitesByTypeProvider`, `myPendingInvitesProvider`)
- `lib/features/minigames/logic/minigame_meta.dart` (`minigameSessionName`
  prefers `auto_name`)
- `lib/features/feed/screens/feed_screen.dart` (per-game badge)
- `lib/features/minigames/screens/minigame_detail_screen.dart` (pending rows)
- `lib/features/minigames/screens/minigame_session_detail_screen.dart`
  (partida name)
- `lib/l10n/app_{es,en}.arb` + regenerated `app_localizations*.dart`
- Tests: `minigame_rpc_migration_test.dart`, `minigame_service_test.dart`,
  `minigames_providers_test.dart`, `plugged_entries_test.dart`,
  `minigame_detail_screen_test.dart`, `integration_test/minigames_flow_test.dart`,
  `test/opt-016-minigames-invites.sh`
- `docs/specs/steps/cross-references.md` (GMCR note), `README.md` (baselines)

## MISTAKE blocks

- **MISTAKE (Riverpod double-build deadlock):** `MyPendingInvitesNotifier.build`
  used a plain `ref.watch(notificationsProvider)` to stay live on the
  notification stream — the notifier rebuilt while its dependency was still
  loading and the future never completed (30s timeouts). The settled pattern
  is `await ref.watch(notificationsProvider.future)` (from
  `recentFriendsProvider`). The probe test isolated it immediately.
- **MISTAKE (manual l10n edits overwritten):** I added `minigamesInvitePending`
  directly to the generated `app_localizations*.dart` files — a simulator
  build regenerated them and the getter vanished. The source of truth is the
  `.arb` files; `flutter gen-l10n` after editing them.
- **MISTAKE (integration test assumed live stack):** the invitee-perspective
  integration test reached the real `notificationServiceProvider` (no fake)
  → the pending list errored against the absent stack. Hermetic flows must
  override every service provider the screen touches.

## Bug fix (same session): non-square home game tiles

**Reported:** on the feed, some `_HomeGameCard`s — e.g. the second
"Preguntas" — rendered at a different width from the others.

**Root cause:** the row `SizedBox` height was text-scaled
(`AppSpacing.scale(context, 132)`) but the tile width was a **fixed 120px**.
At a larger font setting the row grew while the tiles kept their fixed width
→ every card became a rectangle (120 × 171.6 at 1.3×), and text-wrap
differences between the game names could make one tile measure wider than
the others. The user wanted perfect squares of the same width AND height.

**Fix:** the tile is now a proper square — width == height == the same
scaled value. `_homeTileSize(context) => AppSpacing.scale(context, 132)`
feeds both the row height and every `_HomeGameCard`'s `SizedBox(width:
tileSize, height: tileSize)`, so all cards are identical at any font
setting.

**Second pass (same report — background still narrower):** the tile was a
square but the **VCard BACKGROUND** inside it shrank to the name's width for
short names (e.g. "Preguntas"), while the InkWell press-splash still covered
the full square. Root cause: the badge's `Stack` gives non-positioned
children **loose** constraints, so the `VCard` shrink-wrapped to its content
width — before the badge change there was no `Stack` and the tight
`SizedBox(width: 120)` made the card fill the tile. Fix: `Positioned.fill`
around the `VCard` inside the `Stack`, forcing it to span the entire square.
Probe-verified: tile and card rects now identical (171.6×171.6 at 1.3×).

**Regression test:** `test/features/plugged_entries_test.dart` — at a 1.3×
text scale, every BUILT game tile is asserted square (width == height) and
identical in size to the others, AND each tile's `VCard` background must
match the tile's width and height exactly (guards the shrink-wrap symptom).
Full `flutter test` = **1893 pass / 0 fail** (+1).

## Notes / follow-ups

- `supabase db test` + `bash test/run_all_backend.sh` need the Samay stack up
  (not this session); the plan-count guard already validates count ==
  assertions.
- The 4-arg/5-arg `create_minigame_session` pgTAP checks noted as
  migration-order/seed-state artifacts in the previous log remain pre-existing
  and unrelated.
