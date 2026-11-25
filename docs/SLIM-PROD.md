# slim-prod — branch documentation

Everything on this page describes the `slim-prod` branch as it exists today.
It records **what was done** and **what this branch is for**. It does not plan
future work.

---

## 1. What I want (in plain terms)

Samay is a party-games app for a group of friends in the same room.

The goal of this branch is a version you can install, open, and be playing a
game on in seconds, with no account and no setup. Everything that got in the
way of that was removed. The removed features will be added back over time,
one at a time, on top of this branch.

The rules I set for this build:

1. **Games first.** Opening the app shows the games. Nothing else competes for
   attention. No bottom navigation bar.
2. **No account required.** A guest can play forever. Signing in with Apple or
   Google is optional and must **never** be required to play.
3. **One tap to the first game.** Onboarding is a single button. Playing the
   first round costs one more tap.
4. **Nothing pops up before the first screen.** No system dialogs (especially
   no notification-permission dialog) on a brand-new install.
5. **Two ways to play:** everyone on one phone, or one phone each joined by QR
   code.
6. **Still compliant.** The 18+ confirmation and the Terms/Privacy acceptance
   must be recorded, and the documents must be reachable — but without turning
   onboarding into a form.
7. **Removal is reversible.** Removed features keep their database tables and
   their data. Bringing one back should be small work, not a rebuild.
8. **Small, readable commits.** One commit per idea, so any single change can
   be understood or undone on its own.

---

## 2. What this branch ships

| Area | State |
|---|---|
| Games | 4 games: Verdad o Reto, Botella, 2 Mentiras 1 Verdad, Charadas |
| Play modes | Single device (pass the phone) and multi-device (QR / 6-char code) |
| Auth | Anonymous guest by default; optional Apple/Google that links to the same account |
| Onboarding | One button: accepts 18+ / Terms / Privacy and creates the guest account |
| Profile / settings | Kept |
| Notifications | In-app center + push kept |
| Friends / groups | Kept |
| Prompt packs | Served by the backend, cached for offline play, some gated by subscription |
| Events | Removed |
| Chat (E2EE) | Removed |
| Feed | Removed |
| Photos | Removed |
| Rankings | Removed |
| Shards / wagers | Removed |
| Cosmetics | Removed |
| Bottom navigation | Removed |

---

## 3. Frontend — what was done

Commits on top of `4db6702` (count: `git rev-list --count 4db6702..HEAD`).

### 3.1 New: single-device game engine
`lib/features/minigames/local/` — pure Dart, no server, no plugins.

- Judge rotates through the seats and wraps around.
- The subject is always the next seat after the judge.
- A prompt is never drawn twice in the same match.
- "done" scores +1, "skip" scores +0.
- The match ends when the round target is reached.
- `renamePlayer()` allows names to be corrected **during** a match.

This last point is what makes the fast first run possible: the match starts
with default seat names, and the group fixes the names from the header while
playing. Nothing is typed before the first prompt.

37 unit tests cover rotation, scoring, prompt stream, persistence and renaming.

### 3.2 New: prompt packs with offline cache
`lib/core/services/prompt_pack_service.dart`, `lib/features/packs/`

- Packs are read from the backend (`list_prompt_packs`, `get_prompt_pack`).
- Every fetched pack is stored in the encrypted Hive box `prompt_pack_cache`.
- A cached pack plays with no network at all.
- `ensurePackFor()` serves the cached copy when warm and fetches once when cold.
- Paid packs are refused with a typed error and route to the paywall.
- Cache failures degrade to "no cache" and never crash the app.

33 unit tests.

### 3.3 New: guest-first onboarding
`lib/features/auth/screens/onboarding_screen.dart`

- One button (`onboardingStart`). The tap **is** the acceptance.
- Terms and Privacy are inline, tappable links (the previous screen did not
  offer them at all).
- Acceptance and account creation happen in one server call
  (`bootstrap_profile`), so the client cannot record consent without it.

### 3.4 New: optional account linking
`lib/features/auth/screens/sign_in_screen.dart`, `AuthService`

- Apple/Google sign-in lives behind the menu, never in front of play.
- For a guest, the identity is **linked** onto the existing session
  (`linkIdentityWithIdToken`), so the user id and all progress are kept.
- The account is then promoted out of guest state (`confirm_my_account`).

### 3.5 New: no bottom navigation
`lib/core/router/`

- `main_shell.dart` and the six-tab bar were deleted.
- The root screen is the vertical games deck (one card per game, drag to cycle,
  tap to open; header is just the `samay` wordmark).
- Social, packs, notifications, profile, settings and sign-in live in a header
  menu sheet.
- The redirect logic is now tiny: no account or no profile → onboarding; banned
  → ban screen; otherwise the games list.

### 3.6 New: QR join and leave
`lib/features/minigames/screens/join_scanner_screen.dart`

- The lobby shows the join code as a QR (`samay://join/<CODE>`) next to the
  copyable code.
- Scanning joins the match. A bare 6-character code also works. The
  `https://…/j/<CODE>` and `samay://join/<CODE>` links are parsed by
  `core/deep_links/deep_link_handler.dart`. The scanner's own `extractJoinCode`
  accepts a bare code or any URI whose host is `join` (it does not require the
  `samay` scheme).
- `leave_minigame_session` backs a "salir" action for participants.

### 3.7 New: first run has no system dialogs
Three separate causes were fixed:

1. `permission_handler` was removed. Its iOS plugin asked for notification
   permission at startup, which is what actually raised the dialog on the first
   screen. It was unused after the QR scanner was removed.
2. `Info.plist` now sets `FirebaseMessagingAutoInitEnabled=false` and
   `FirebaseAppDelegateProxyEnabled=false`, so the Firebase SDK does not
   register for remote notifications at launch.
3. Push is activated by `PushNotificationListener` only after onboarding, and
   the permission request is deferred to the **second** launch.

`PushNotificationListener` also had to be mounted again — it was orphaned when
the navigation shell was deleted, so push had silently stopped working.

### 3.8 Removed: six feature directories and their support code

Deleted: `events`, `chat`, `feed`, `photos`, `shards`, `cosmetics`, and the
rankings screen. With them went the chat/event/shards/location services, the
chat repository, the event/chat/photo/feed/ledger models, and the old
credential-first auth funnel (welcome, login, signup, OTP, age gate, privacy
terms, profile setup, password recovery).

### 3.9 Changed: kept features decoupled
Groups, friends, profile, settings and notifications stopped referencing
anything removed:

- Group chat tab and its notice refresh removed.
- Donate-shards dialog and contribution/leaderboard reads removed.
- Group events section removed.
- Feed avatar-physics widget replaced with a local overlapping avatar stack.
- Rankings entry removed from the social header.
- Shard / cosmetics / read-receipts rows removed from settings and profile.
- `pendingCountsProvider` moved next to its data sources in friends providers.

### 3.10 Changed: dependencies dropped
`permission_handler`, `flutter_map`, `vector_map_tiles`,
`vector_map_tiles_pmtiles`, `vector_tile`, `latlong2`, `geolocator`,
`flutter_svg`, `forge2d`.

### 3.11 Changes made after first device testing
- The games carousel was replaced with a plain list. The carousel clipped game
  names mid-word and hid three of the four games behind gestures. **Reverted:**
  the vertical finger-tracked deck is back as the root, and the root header is
  just the `samay` wordmark. Each card is only the game name (centred, one word
  per line for short names, never clipped) plus a circular symbol-only play
  button in the bottom-right corner. Title lines alternate colours: odd lines
  are soft pastels (random per game, distinct per card), even lines are a white
  outline. The circulating name bands and the match bubbles were removed.
- The match screen title used a 40px display widget and clipped
  "verdad o reto"; it now uses the fitted header title.
- Menu labels were normalized to lowercase.

---

## 4. Backend — what was done

Commits on top of `09e74ae` (count: `git rev-list --count 09e74ae..HEAD`).

### 4.1 New: the `300_slim/` migration layer
`supabase/migrations/300_slim/` is a forward-fix layer numbered `300` so it
sorts before the `940`-`970` infrastructure migrations. It is the only place
this branch changes feature schema, and it is idempotent: it applies cleanly to
a fresh stack and to an existing one.

| File | What it does |
|---|---|
| `01_onboarding.sql` | guest columns, `is_onboarded()`, `bootstrap_profile()`, `confirm_my_account()` |
| `02_prompt_packs.sql` | `prompt_packs` table, prompt→pack link, 8 seeded packs, `list_prompt_packs()`, `get_prompt_pack()` |
| `03_remove_wagers.sql` | wager-free session creation; escrow/ledger writes removed from every play RPC |
| `04_leave_session.sql` | `leave_minigame_session()` with host transfer |
| `05_revoke_removed.sql` | revokes client access to every removed-feature table |

**What `bootstrap_profile()` does:** records the 18+/terms acceptance and
creates the guest `users` row in one transaction, generating a unique
`invitado-NNNN` name. Game creation returns `not_onboarded` until this has run,
so consent cannot be skipped by calling the game RPC directly.

**What `05_revoke_removed.sql` does:** client roles lose all access to events,
chat, photos, cosmetics, shard ledgers, rankings and search surfaces. **The
tables and their data stay.** Re-adding a feature is a `GRANT` plus the feature
code — not a migration rebuild. Every server path that still needs those
tables runs as `SECURITY DEFINER`, so nothing breaks.

### 4.2 Changed: anonymous accounts and linking
`supabase/config.toml`, `supabase/docker-compose.yml`, `.env/example.env`

- `GOTRUE_EXTERNAL_ANONYMOUS_USERS_ENABLED`
- `GOTRUE_SECURITY_MANUAL_LINKING_ENABLED`

Anonymous users are real GoTrue users with `role=authenticated`, so every
existing grant and RLS policy applies unchanged.

### 4.3 Removed: admin API and CLI surface
`cmd/`, `internal/`

- API server: events, groups, shards and subscription-override route groups
  removed. Kept: health, users, reports, appeals, config, feature requests.
- Admin CLI: events, groups, shards and subs commands removed. `users ledger`
  added because dropping `shards ledger` left no ledger command.
- Ops packages for the removed domains deleted. `GetShardLedger` moved to
  `shared.go` because the kept users-ledger route still uses it.

### 4.4 Changed: tests
- `schema_test.sql` rewritten from 1319 to **901** assertions. The old suite
  aborted midway (removed relations are no longer readable) and 18 assertions
  encoded behaviour this branch deliberately changes.
- `slim_test.sql` added: **52** assertions covering the new contracts.
- Opt suite trimmed from 46 to **34** scripts (12 deleted). `opt-067` (economy)
  was entirely shard economy, so it was deleted rather than trimmed; `opt-070`
  (group theme) kept because groups remain a feature.
- Contract fixtures for removed features deleted. The fixture list is now
  directory-derived, so deleting a fixture cannot break the check.

### 4.5 Known leftovers
- `supabase/.temp/` (backend) — an auto-generated CLI cache directory. It is
  gitignored (`.gitignore` in the backend repo) and is not tracked; no action
  needed.

---

## 5. Verification performed

| Check | Result |
|---|---|
| `flutter analyze` | clean |
| `flutter test` | 115 passing |
| `flutter build ios --simulator` | succeeds |
| `flutter build apk --debug` | succeeds |
| `go build ./…` / `go vet ./…` / `go test ./…` | clean, all packages pass |
| pgTAP `schema_test.sql` | 901 / 901 |
| pgTAP `slim_test.sql` | 52 / 52 |
| Backend opt suite | 34 / 34 |
| On device: guest onboarding → games list → game page → single-device match | played 5/5 rounds, correct rotation, scoreboard shown |
| On device: first launch | no permission dialog |

Live API checks against a local stack: anonymous sign-in works; `create_minigame_session`
returns `not_onboarded` before acceptance and succeeds after; free pack returns
prompts; paid pack returns `locked`.

---

## 6. Repository state

| | Client | Backend |
|---|---|---|
| Branch | `slim-prod` | `slim-prod` |
| Commits on top of the old branch | see `git rev-list --count 4db6702..HEAD` | see `git rev-list --count 09e74ae..HEAD` |
| Public repo | `github.com/DaereanLegrand/samay-frontend` | `github.com/DaereanLegrand/samay-backend` |
| Mirrored to | Gitea | Gitea |
| `main` | protected; see `git rev-parse main` | protected; see `git rev-parse main` |

Both `main` branches are protected: changes must arrive by pull request, and
force-push and deletion are blocked. Only the repository owner can bypass.

Contributors invited with write access: `bryansucabs`, `felix-gy`.

Historical commits authored by those two contributors were repaired so the
author and committer both record them; no commit content changed.

---

## 7. Adding a removed feature back

The pattern is the same for every removed feature:

1. Re-grant client access to its tables in a new migration (SQL only — the data
   is still there).
2. Add the feature code to the client.
3. Add its route and a menu entry.
4. Add tests for whatever logic it brings.

Nothing needs to be rebuilt or restored from history.

---

## 8. Notes

- **Offline play on an unsigned iOS simulator build:** `HiveService.init` fails
  with an entitlement error, so the encrypted caches (including the pack cache)
  do not persist there. The app degrades safely and packs still load over the
  network. This is a signing limitation, not a code defect.
- **Public repos:** infrastructure and release-operation material is not part
  of this repository. Release signing and deployment provisioning are handled
  by the operator out-of-band. No credentials are exposed.
- **License:** AGPL-3.0 — see `LICENSE`, `NOTICE`, and §9 below.

---

## 9. License

Samay is licensed under the **GNU Affero General Public License, version 3**
(AGPL-3.0), as published in `LICENSE` at the root of both this repository and
the backend repository. The text is the unmodified official license.

Why AGPL-3.0: Samay is a network-delivered application. AGPL-3.0 keeps the
source of the deployed service available to the people using it, which matches
how this project is intended to be published and run.

- Third-party assets and components, the AI-assistance disclosure, and the
  pre-licensing commit note are in `NOTICE`.
- The license applies to the project as published from this point forward.
  Commits made before `LICENSE` existed carry no license and no contributor
  consent for one (see `NOTICE`); this is not a retroactive grant.
- Running a modified version of Samay as a network service obliges the operator
  to offer its corresponding source to that service's users.

### Internal-ops history

Infrastructure and release-operation documentation is not part of this
repository. It was removed from the current trees and from the published
history so that only Samay application code and its own engineering history
remain.
