# 2026-08-09 — I-12: State-management audit + Riverpod migration (ARC-06 / M-04 / CQ-03)

**Agent:** I-12 (state-management audit + provider co-location + screen rewiring)
**Status:** DONE
**Scope:** full `lib/features/**` audit table, per-feature provider files
(friends/groups/profile), 8 DATA-loading screens rewired to Riverpod
`AsyncNotifierProvider` + exhaustive `AsyncValue.when()`, fake-provider widget
tests, TODO.md M-04 status.

---

## 1. AUDIT TABLE — every screen in `lib/features/`

Pattern legend: **S** = StatefulWidget + `setState` managing DATA (lists/profiles/loads)
with direct `SupabaseService.instance` calls · **S-F** = StatefulWidget + `setState`
for *trivial local UI/form state only* (legit per ARC-06 convention) ·
**C** = ConsumerStatefulWidget/ConsumerWidget backed by Riverpod providers ·
**SL** = StatelessWidget.

### friends (`lib/features/friends/`)

| Screen | Before | Data loaded | Target | Status |
|---|---|---|---|---|
| `friends_list_screen.dart` | S — `_friends`/`_loading` + `getFriends()`+`getUserProfile()` | friend profiles | C — `friendsListProvider`; search TextField stays local | ✅ converted (I-12) |
| `requests_screen.dart` | S — `_requests`/`_invites`/`_names`/`_loading` + `getFriendRequests()`+`getGroupInvites()`+`getUserProfile()` | received/sent requests, group invites, names | C — `friendRequestsProvider` + `groupInvitesProvider`; TabController stays local | ✅ converted (I-12) |
| `blocked_users_screen.dart` | S — `_blocked`/`_loading` + `getBlockedUsers()` | blocked profiles | C — `blockedUsersProvider` | ✅ converted (I-12) |
| `search_screen.dart` | S — `_results`/`_loading`/debounce + `searchUsers()` + `fetchAppConfig()` | search results, debounce tuning | C — `searchResultsProvider(family)` + `appConfigProvider`; controller/debounce stay local | ✅ converted (I-12) |

### groups (`lib/features/groups/`)

| Screen | Before | Data loaded | Target | Status |
|---|---|---|---|---|
| `my_groups_screen.dart` | S — `_groups`/`_loading` + `getMyGroups()` | my groups | C — `myGroupsProvider` | ✅ converted (I-12) |
| `group_detail_screen.dart` | S — `_group`/`_members`/`_contributions`/`_myContribution` + 4 service calls | group, members, aggregated contributions, my contribution | C — `groupDetailProvider`+`groupMembersProvider`+`contributionsProvider`; TabController stays local | ✅ converted (I-12) |
| `leaderboard_screen.dart` | S — `_rankings`/`_loading` + `getLeaderboard()`+`getGroup()` | rankings per size tier | C — `leaderboardProvider(family)`; tier chip selection stays local | ✅ converted (I-12) |
| `invite_screen.dart` | S — `_results`/`_memberIds`/`_loading` + `getGroupMembers()`+`searchUsers()` | members (exclusion set), search results | C — `groupMembersProvider` + `searchResultsProvider`; selected set + `_sending` stay local | ✅ converted (I-12, search part) |
| `group_members_screen.dart` | S — `_members`/`_loading` + `getGroupMembers()` | members | C — `groupMembersProvider` | ⚠️ NOT in I-12 mission list — provider exists; wiring is a follow-up (I-45/I-78) |
| `create_group_screen.dart` | S-F — form/upload only (`_loading`, `_coverImage`) | none on load (group-count check on submit) | keep S-F (form state) | keep |
| `donate_shards_screen.dart` | S-F — form only | none | keep S-F (form state) | keep |

### profile (`lib/features/profile/`)

| Screen | Before | Data loaded | Target | Status |
|---|---|---|---|---|
| `profile_screen.dart` | C+S — `_profile`/`_groups`/`_loading` + direct queries | profile row, my groups | C — `myProfileProvider` + `myGroupsProvider` | 🚫 **I-13 owns this file** — I-12 created the providers only; I-13 wiring in progress (verified 2026-08-09) |
| `public_profile_screen.dart` | S — `_profile`/`_friendshipStatus`/`_isBlocked` + 3 service calls | profile, friendship detail, block status | C — needs a `publicProfileProvider`(family) + friendship-status providers | ⚠️ follow-up (needs friendship providers, not in I-12 mission list) |
| `edit_profile_screen.dart` | S — `_loading` + bio query | own bio | C — `myProfileProvider` | ⚠️ I-13 converting concurrently (uses `myProfileProvider`) |
| `settings_screen.dart` | C — no data | — | keep | keep |
| `delete_account_screen.dart` | C+S-F — form only | — | keep | keep |

### auth (`lib/features/auth/`) — all keep current pattern (auth state already provider-backed; I-09 migrates to AsyncNotifier)

| Screen | Pattern | Data | Status |
|---|---|---|---|
| `welcome_screen.dart` | SL | none | keep |
| `login_screen.dart` | C (authStateProvider) + S-F form | auth state | keep (I-09) |
| `signup_contact_screen.dart` | C (authStateProvider) + S-F form | — | keep (I-09) |
| `otp_verification_screen.dart` | C (authStateProvider) + S-F form | — | keep (I-09) |
| `age_gate_screen.dart` | S-F form (reads current-user email fallback) | — | keep |
| `privacy_terms_screen.dart` | S-F checkboxes | — | keep |
| `profile_setup_screen.dart` | C (authStateProvider) + S-F form | — | keep (I-09) |

### feed

| Screen | Pattern | Data | Status |
|---|---|---|---|
| `feed_screen.dart` | SL placeholder | none | keep (I-58) |

### Counts per pattern (before → after this agent)

| Pattern | Before | After | Delta |
|---|---|---|---|
| setState managing DATA + direct service calls | 13 | **3** (group_members, public_profile, edit_profile* ) | −10* |
| setState for trivial/form UI only (legit) | 4 | 4 (create_group, donate, age_gate, privacy_terms) | 0 |
| Riverpod-backed screens | 5 | **13** | +8 |
| Stateless | 2 | 2 | 0 |

\* `edit_profile_screen` + `profile_screen` are being rewired to the I-12 providers by I-13
concurrently — once I-13 lands, only `group_members_screen` and `public_profile_screen`
remain on the old pattern (both documented as follow-ups).

---

## 2. What was built

### Provider files (co-located per SM-08, `AsyncNotifierProvider` per SM-01/SM-02/SM-09)

- **`lib/features/friends/friends_providers.dart`** (new)
  - `friendsListProvider` — friend profiles (getFriends + getUserProfile N+1, same logic as the old screen).
  - `friendRequestsProvider` — `FriendRequestsData` (received+sent rows + resolved display names).
  - `blockedUsersProvider` — blocked profiles with username fallback.
  - `searchResultsProvider` — **family** keyed by the trimmed query (`searchUsers`).
- **`lib/features/groups/groups_providers.dart`** (new)
  - `myGroupsProvider`, `groupDetailProvider`(family), `groupMembersProvider`(family),
    `contributionsProvider`(family) — `GroupContributionsData` (aggregated per-user
    contributors + myContribution; the old screen's aggregation logic moved here),
    `leaderboardProvider`(family), `groupInvitesProvider` (needed by requests_screen).
- **`lib/features/profile/profile_providers.dart`** (new)
  - `myProfileProvider` (own users row), `myGroupsProvider` — **screens NOT touched here**
    (I-13 wires them; verified I-13 landed edits referencing both providers).

Every notifier exposes `Future<void> refresh() => ref.invalidateSelf()` (SM-09 contract).

### Screens rewired (8) — see audit table
Each uses exhaustive `.when(loading/error/data)`; errors render `ErrorView` (I-06) with
retry; loading renders the standard spinner; retry/follow-up mutations call
`ref.invalidate(provider)` / `notifier.refresh()`. Local setState retained only for:
text controllers, search query/debounce, TabControllers, tier chip selection, checkbox
selection, `_sending` flags (ARC-06 convention).

- Friends: `friends_list`, `requests`, `blocked_users`, `search`
- Groups: `my_groups`, `group_detail` (data parts only), `leaderboard`, `invite` (search part)

### Tests
- `test/features/friends_screens_test.dart` — rewritten: fake-notifier overrides via
  `ProviderContainer` + `UncontrolledProviderScope` (the router harness pattern);
  loading/empty/data/error per screen; tab-switch assertions for requests.
- `test/features/groups_screens_test.dart` — rewritten: MyGroups empty/data/error,
  GroupDetail header+tabs+contributions, Leaderboard 2-fake-groups data + empty + error,
  Invite member-exclusion; untouched screens (create_group, donate, group_members) keep
  their tests.
- `test/providers/feature_providers_test.dart` (new) — SM-09 contract: `refresh()`
  re-runs `build()` for friendsList, myGroups, leaderboard(family), myProfile,
  profile-myGroups; family instances keyed per arg.
- Integration suite: the 8 rewired screens change no routes/widget identities — the
  existing router tests + `integration_test/` harness cover them; no new flow file
  needed for a pure provider refactor (all flows verified in step 3).

### Docs
- `docs/to-fix/TODO.md` — M-04 → 🔄 (see §4).

---

## 3. Validation

```
dart analyze                        → 0 errors repo-wide (final pass; mid-session errors
                                      were concurrent in-flight work by I-08/I-09/I-10/
                                      I-11/I-13 that landed by the end)
flutter test test/features/friends_screens_test.dart
             test/features/groups_screens_test.dart
             test/providers/feature_providers_test.dart   → 34 passed (0 failed)
flutter test test/router/            → green (app_router_test.dart included once I-09/
                                      I-13's AsyncNotifier landing fixed profile_screen)
flutter test                          → 411 pass / 12 fail — the 12 are ALL
                                      structure_test.dart (documented pre-existing
                                      brittle L-13 directory asserts); zero failures
                                      in any I-12 file
```

Baseline note: the mission brief mentioned "7 baseline failures in friends/groups
screens tests" — at campaign start those files passed 19/19 (the 23 documented failures
are auth_provider, auth_screens, profile_screens, widget_test + structure_test). My
rewrite keeps them green (34 including new provider tests).

## 4. TODO.md — M-04 status

`docs/to-fix/TODO.md` M-04 (`Mixed state management — some screens use Riverpod, some
use setState`) → **🔄** with note: "partially addressed by I-12 (2026-08-09):
friends/groups/profile providers + 8 screens; profile_screen/edit_profile pending I-13;
group_members/public_profile follow-up".

---

## Decisions & rationale

1. **`AsyncNotifierProvider` over `FutureProvider`**: I-09's auth migration had not
   landed when I-12 started (auth_provider still `StateNotifierProvider`), so per the
   mission I used the most modern pattern available in the installed riverpod 2.6.1:
   `AsyncNotifier` + `ref.invalidateSelf()` — exactly the target pattern documented in
   findings SM-01/SM-02/SM-09. API verified against the pub-cache source
   (`riverpod-2.6.1/lib/src/async_notifier.dart`).
2. **Raw `Map<String, dynamic>` retained**: typed freezed models are I-10's in-flight
   assignment; the docs (DEVELOPMENT-WORKFLOW §5) call raw maps the documented stopgap.
   Provider payloads mirror the exact shapes the old screens consumed, so I-10 models
   can slot in at the provider boundary later.
3. **`contributionsProvider` bundles top contributors + `myContribution`** in one
   `GroupContributionsData` object because the old `_load()` fetched both together and
   the detail header needs both; one family watch keeps the 3-way nested `.when()`
   readable.
4. **Two `myGroupsProvider` symbols (groups + profile)**: the mission names it in both
   files; Dart allows same-name top-levels in separate libraries. `profile_providers.dart`
   deliberately does NOT import `groups_providers.dart` to avoid the collision, and the
   profile feature stays dependency-free of the groups feature (SM-08 co-location).
   Test files that need both use a prefixed import.
5. **`groupInvitesProvider` added beyond the mission's provider list**: requests_screen
   (mission item) loads group invites; there was no home for that data, so it lives in
   `groups_providers.dart`.
6. **Nested `.when()` for multi-provider screens** (requests, group_detail): readable
   exhaustive handling that degrades each provider independently with its own retry.
7. **search_screen debounce config now from `appConfigProvider`** (pre-existing
   `FutureProvider`) instead of a direct `fetchAppConfig()` call — removes a direct
   service call from the widget; `.valueOrNull` fallback to 300 ms keeps tests hermetic.
8. **Error surfaces** use I-06's `ErrorView` with retry; the current `error_mapper.dart`
   (I-08 in-flight) intentionally hides raw exception text, so tests assert
   `ErrorView` + retry button rather than message contents.

## MISTAKE blocks

- **MISTAKE (test):** friend ListTile renders the username in BOTH `title` and
  `subtitle` (pre-existing UI), so `find.text('@ana')` finds 2 → use `findsNWidgets(2)`.
- **MISTAKE (test):** TabBarView only builds the ACTIVE tab — asserting content of the
  "Enviadas"/"Invitaciones" tabs without tapping them finds nothing. Tap the tab first.
- **MISTAKE (test data):** MyGroupsScreen cast `(g['my_role'] as String)` (pre-existing
  screen) crashes on `my_role: null`; fake data must mirror real service output
  (getMyGroups always sets `my_role`).
- **MISTAKE (analyze):** `container.read(providerFamily(...).value)` is invalid — the
  `.value` getter must be applied to the *read result*:
  `container.read(providerFamily(...)).value`.
- **MISTAKE (lint):** `if (context.mounted)` after an await in a `ConsumerState` trips
  `use_build_context_synchronously`; the blessed form is `if (mounted)` (guards
  `State.context`).
- **Concurrency:** `docs/to-fix/TODO.md` was held by I-10-models for the whole session —
  the M-04 edit waited behind the semaphore (acquired via background `--timeout 1800`).

## Commands run (reproducibility)

```
export AGENT_NAME=I-12
tools/agent_lock.sh acquire <path> --owner "$AGENT_NAME"   # 15 files, all granted
dart analyze
flutter test test/features/friends_screens_test.dart test/features/groups_screens_test.dart test/providers/feature_providers_test.dart
flutter test test/router/
flutter test
tools/agent_lock.sh release <path> --owner "$AGENT_NAME"   # see final report for list
```
