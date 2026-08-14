# 2026-08-09 — I-50: Repository layer + feature-provider/screen rewiring (ARC-05 / M-38 / H-14)

**Agent:** I-50 (repository layer)
**Status:** DONE
**Scope:** create `lib/core/repositories/` (FriendsRepository, GroupsRepository,
ChatRepository, ProfileRepository + barrel + Riverpod providers); rewire every
`lib/features/` consumer off the `SupabaseService.instance` singleton (providers
AND screens — `rg "SupabaseService.instance" lib/features/` → 0); mocktail-based
repository tests; docs + TODO.md status.

---

## What was built

### 1. Repository layer — `lib/core/repositories/` (all new)

Dependency direction doctrine (DEVELOPMENT-WORKFLOW §5): providers → repositories
→ services → Supabase client. Repositories are thin, typed, injectable; they
delegate to the decomposed I-11 services and carry the typed shapes where the
I-10 freezed models match, `Map<String, dynamic>` passthrough where not modeled.

| File | Class | Wraps | Typed methods | Map passthrough |
|---|---|---|---|---|
| `friends_repository.dart` | `FriendsRepository(UserService)` | user_service | `getUserProfile → UserProfile?`, `getFriends → List<FriendshipSummary>` | searchUsers (friendship_status enrichment), getFriendRequests, getBlockedUsers, getFriendshipDetail, getFriendshipStatus, getFriendshipIdForUser, getBlockStatus |
| `groups_repository.dart` | `GroupsRepository(GroupService, ShardsService)` | group_service + shards_service | `getMyGroups → List<Group>` (my_role), `getGroup → Group?`, `getGroupMembers → List<GroupMember>` | getGroupInvites (joins `groups`, not `users`), getLeaderboard (rank snapshots), getGroupContributions (aggregation shape), getUserContributionToGroup → `int` |
| `chat_repository.dart` | `ChatRepository(ChatService, RealtimeService)` | chat_service + realtime_service | — | loadMessages/sendMessage/subscribe (E2EE — see below) |
| `profile_repository.dart` | `ProfileRepository(UserService)` | user_service | `getMyProfile → UserProfile?`, `updateBio(String)`, `updateAvatarUrl(String)` (current user resolved via `users.auth.currentUser`) | — |

**E2EE invariant (documented on `ChatRepository`, E2EE-ARCHITECTURE.md §12.2):
E2EE lives in `ChatService`** — encrypt on send, decrypt on load/realtime. The
repository MUST NOT bypass it: `loadMessages`/`sendMessage`/`subscribe` all
delegate to the injected `ChatService`; `subscribe` goes through
`ChatService.subscribeToMessages` (the decrypting realtime path), never a raw
`RealtimeService.subscribeToMessages`. The `RealtimeService` is accepted and
exposed for future non-message subscriptions only; the message path never
touches it (pinned by a `verifyNever` test).

- `repositories.dart` — barrel export.
- `repository_providers.dart` — `friendsRepositoryProvider`,
  `groupsRepositoryProvider`, `profileRepositoryProvider` (singletons per
  container, overridable). **No core `chatRepositoryProvider`** by design: the
  chat feature is the only message consumer and always goes E2EE, so the chat
  repository provider lives feature-scoped in `chat_providers.dart`
  (`chatE2eeRepositoryProvider`, wrapping `chatE2eeServiceProvider`). A core
  plaintext chat repository would be both dead code and an E2EE bypass
  footgun.

### 2. Rewired feature providers (zero public-API change)

| Provider file | Before | After |
|---|---|---|
| `friends_providers.dart` | `SupabaseService.instance.*` (7 sites) | `friendsRepositoryProvider`; typed `FriendshipSummary` + `UserProfile.toJson()` at the provider boundary (I-12 decision 2 — models slot in at the provider boundary) |
| `groups_providers.dart` | `SupabaseService.instance.*` (7 sites) | `groupsRepositoryProvider`; `Group`/`GroupMember.toJson()` conversions |
| `profile_providers.dart` | `userServiceProvider`/`groupServiceProvider` via ref | `profileRepositoryProvider.getMyProfile()` + `groupsRepositoryProvider.getMyGroups()` |
| `chat_providers.dart` | `chatE2eeServiceProvider` via ref | `chatE2eeRepositoryProvider` (feature-scoped, E2EE-wired) |

### 3. Rewired screens (all `SupabaseService.instance` call sites → repositories via `ref`)

friends: search_screen (sendFriendRequest), blocked_users_screen (unblock),
requests_screen (accept/decline friend + invite). groups: group_detail_screen
(leaveGroup), group_members_screen (getGroupMembers), donate_shards_screen
(donateToGroup). profile: public_profile_screen (10 sites — converted
`StatefulWidget` → `ConsumerStatefulWidget`, profile row typed via
`UserProfile.toJson()`), delete_account_screen (current user email now via
`authServiceProvider`). chat: chat_screen (realtime subscribe via
`chatE2eeRepositoryProvider`). auth: age_gate_screen (current user email via
`authServiceProvider`).

`rg "SupabaseService.instance" lib/features/` → **0 hits**. The only remaining
facade reference in `lib/` is `supabaseServiceProvider` in
`lib/core/providers/auth_provider.dart` (I-09 seam, no consumers left).

### 4. Tests — `test/core/repositories/` (new, mocktail)

Per-repository behavioral tests: method delegation with correct args to the
right service, typed-model mapping, error propagation (`captureError` +
`expectMapped` from the shared `test/support/resolving_builder.dart`), and the
E2EE bypass guard (chat subscribe must go through the ChatService —
`verifyNever` on the raw realtime subscribe). Plus a new delegation group in
`test/providers/feature_providers_test.dart`: the real notifiers (with mocked
repositories) delegate to the repository with the right args.

### 5. Docs

- `docs/to-fix/TODO.md` — H-14/M-38 updated (facade now reachable only from
  core `supabaseServiceProvider`; deletion at STOP-100 now realistic).
  ⚠️ TODO.md was **held by I-51** at mission end — see final report.

## Decisions & rationale

1. **Repository providers live in core; chat is feature-scoped.** E2EE wiring
   (`chatE2eeServiceProvider` + key/session stores) is chat-specific; a core
   plaintext `chatRepositoryProvider` would be dead code and an E2EE bypass
   risk. Precedent: the two `myGroupsProvider` symbols (I-12 decision 4).
2. **`getMyProfile`/`updateBio`/`updateAvatarUrl` resolve the current user
   internally** via `users.auth.currentUser` (the service already exposes
   `auth`), so the profile repository API is self-contained
   (`updateBio(String)` instead of `updateBio(userId, bio)`).
3. **`UserProfile.toJson()`/`Group.toJson()` conversions at the provider
   boundary** — providers keep their exact `Map<String, dynamic>`-based public
   API (zero behavior change for screens/tests); the freezed models slot in at
   the repository boundary, exactly the I-12 "slot in later" plan.
4. **`GroupMember` not used for `getGroupInvites`** — the invites select joins
   `groups!inner(name)` (key `groups`), while the model maps `users`; shapes
   don't match → documented Map passthrough.
5. **`ChatRepository` keeps `realtime` exposed** (public field, documented)
   rather than dropping it: the mission names both services, and future
   non-message subscriptions need it; the E2EE-unsafe path is pinned shut by
   tests, not just docs.

## MISTAKE blocks

- **MISTAKE (concurrency):** the `tools/agent_lock.sh acquire docs/to-fix/TODO.md`
  call in my lock batch sat behind I-51's lock and the shell session was
  killed at 600 s. Re-checked: TODO.md still LOCKED by I-51-rest-client at
  mission end → TODO.md edit is the ONE incomplete item (reported, per
  AGENT-RULES §1).
- **MISTAKE (Riverpod family override):** you cannot `overrideWith` a family
  provider for one key only at declaration time; delegation tests use the real
  notifier + `overrideWithValue` on the (plain) repository provider instead.

## Commands run (reproducibility)

```
export AGENT_NAME=I-50
# 27 locks acquired (26 granted; docs/to-fix/TODO.md blocked by I-51 → later I-52)
dart analyze lib/core/repositories test/core/repositories lib/features/friends \
  lib/features/groups lib/features/profile lib/features/chat \
  test/providers/feature_providers_test.dart test/features/chat/chat_screen_test.dart
  # → No issues found
flutter test test/core/repositories/                 # 41 pass
flutter test test/providers/                         # 62 pass (was 48; +9 delegation, I-52 realtime landed)
flutter test test/features/chat/ test/features/friends_screens_test.dart \
  test/features/groups_screens_test.dart test/features/profile_screens_test.dart   # 64 pass
flutter test                                        # 1129 pass / 6 fail (all I-54/I-49 in-flight:
                                                    # events screens/tests, feature_flags l10n, perf guard)
rg "SupabaseService.instance" lib/features/          # → 0 (verified)
```

## Baseline comparison

| Suite | Before (I-49 tree) | After |
|---|---|---|
| dart analyze | 0 errors | 0 errors in all I-50 files (repo-wide errors are I-54/I-55 in-flight events/l10n) |
| test/core/repositories | n/a | **41 pass** (new) |
| test/providers | 48 pass | **62 pass / 0 fail** (+9 I-50 delegation tests) |
| test/features (chat+friends+groups+profile) | green | **64 pass / 0 fail** |
| Full flutter test | 997/997 (I-46 checkpoint) | **1129 pass / 6 fail** — the 6 are I-54 (events: create_event_test load, event_detail_test ×2, app_router /event/ coherence, perf guard on event screens) + I-49/I-55 (feature_flags localized title); verified none touch I-50 files |

## Facade deletion readiness assessment (H-14 / M-38)

After this agent: `rg "SupabaseService.instance" lib/features/` → **0 hits**.
The facade (`lib/core/services/supabase_service.dart`) is now referenced only by
the `supabaseServiceProvider` in `lib/core/providers/auth_provider.dart` — which
has **zero consumers** (`rg "supabaseServiceProvider" lib test` → definition
only). Deleting the facade at STOP-100 now requires: (1) removing
`supabaseServiceProvider` + its import from `auth_provider.dart`, (2) deleting
`supabase_service.dart`, (3) rewriting/removing the 10 facade behavioral tests
in `test/services/supabase_service_test.dart` (they test the facade's
delegation — the same behaviors are covered directly at the service layer by
I-44's per-service suites). No feature code depends on it anymore. **READY.**

