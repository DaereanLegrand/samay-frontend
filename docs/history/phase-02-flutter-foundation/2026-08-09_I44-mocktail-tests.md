# 2026-08-09 — I-44: Mocktail behavioral + error-state test coverage (TST-02..TST-05 / H-15..H-18)

**Agent:** I-44 (mocktail behavioral tests)
**Status:** DONE
**Scope:** behavioral + error-state test coverage for every service in
`lib/core/services/` and every provider in `lib/core/providers/` +
`lib/features/{friends,groups,profile}/` — mocktail-based, TST-02/TST-03/TST-04/TST-05
(H-15/H-16/H-17/H-18). This was a FIRST FULL RUN (a prior dispatch died on prompt
truncation before any work started).

## Coverage audit (before → after)

| Service | Public methods | Before | After |
|---|---|---|---|
| AuthService | checkSignupEmail, upsertSignupTracker, signIn, signUp, signOut, sendOtp, verifyOtp, getCurrentUser, refreshSession, updateUser, softDeleteUser, userHasProfile, createUserProfile | 5 (via facade test) | **15** — full passthrough + shapes + error paths |
| UserService | getUserProfile, updateAvatarUrl, updateBio, getFriendshipStatus, getFriendshipIdForUser, getFriendshipDetail, sendFriendRequest, accept/declineFriendRequest, blockUser, unblockUser, searchUsers, getFriends, removeFriend, getFriendRequests, getBlockedUsers, getBlockStatus | 2 (updateAvatarUrl only) | **21** — incl. search blocked-filter logic + duplicate-request error |
| GroupService | createGroup, joinGroup, leaveGroup, getGroup, getGroupMembers, getGroupInvites, accept/declineGroupInvite, updateGroup, kickMember, transferPromotor, setMemberRole, getUserGroupCount, getMyGroups, inviteMembers | 0 | **16** — 3-table createGroup shape, orphan deletion, invites, my_role enrichment |
| EventService | createEvent, listEvents, getEvent, updateEvent, likePhoto | 3 (likePhoto only) | **9** — 3-table createEvent shape verified vs migration §3.10-3.17, dynamic_qr flag, filters/order |
| ChatService | loadMessages, sendMessage, subscribeToMessages | 0 | **6** — ordering/pagination, sanitize, realtime delegation (sync channel, I-38 signature) |
| NotificationService | getNotifications, markNotificationRead, subscribeToNotifications | 0 | **6** |
| ShardsService | donateToGroup, getGroupContributions, getUserContributionToGroup, purchaseCosmetic, getLeaderboard | 0 | **10** — insufficient-shards guard, RPC shape + boost window, aggregation |
| ModerationService | reportContent | 0 | **3** |
| MediaService | uploadGroupCover, uploadUserAvatar, uploadEventPhoto, getSignedPhotoUrl | 7 (covers/avatars only) | **11** — event-photo file upload + signed URL |
| RealtimeService | subscribeToMessages/Notifications/EventStatus/QRToken | 0 | **8** — channel naming, event/table wiring, payload extraction, no-session errors |
| ConfigService | fetchAppConfig, getSignupShardGrant | 3 (via facade test) | **8** — mapping, 256 fallback (missing key / fetch failure / bad int) |
| BanService | checkBanStatus, invalidate | 0 | **8** — banned/fail-open/cache/in-flight/invalidate |
| PermissionService / Storage / SecureSessionStorage | (already covered) | 20 | unchanged |

| Provider | Before | After |
|---|---|---|
| AuthProvider | 11 (init/signIn/refresh/token-refresh) | **21** — signUp, sendOtp, verifyOtp, createProfile, signOut, deleteAccount, checkEmail success+error |
| ConfigProvider | 1 ("is defined") | **3** — AsyncData/AsyncError/refresh |
| UserProvider (currentUserProvider) | 0 | **2** |
| Friends/Groups providers | 6 (refresh contracts only) | **16** — +9 AsyncError states |
| Profile providers | 6 | unchanged (already had success/error/refresh) |

**Test counts:** `test/services/` 184 pass (was ~74) · `test/providers/` 48 pass (was ~24).
Zero implementation files touched — no test seams were needed (constructor injection
already exists everywhere).

## What was built

1. **`test/support/resolving_builder.dart` (new, shared):** mocktail mocks for
   SupabaseClient/GoTrueClient/QueryBuilder/RealtimeChannel/ConfigService/storage, the
   network-free `ResolvingBuilder<T>`/`ResolvingTransform<T>` Postgrest chain subclasses
   (the I-11 MISTAKE pattern), `captureError()` + `expectMapped()` failure-path helpers
   that assert propagation AND the real `error_mapper` mapping.
2. **Service tests:** user_service (rewritten + expanded), group_service (new),
   event_service (expanded), chat_service (new), notification_service (new),
   moderation_service (new), shards_service (new), config_service (new), ban_service
   (new), auth_service (new), media_service (expanded), realtime_service (new).
3. **Provider tests:** auth_provider (expanded), config_provider (rewritten),
   user_provider (new), feature_providers (expanded with AsyncError states).
4. Every tested service method has ≥1 failure path: mocktail `thenThrow`s
   `PostgrestException` (codes 42501/23505/P0001/28000/PGRST116) or `AuthException`
   (invalid_credentials/otp_expired/rate-limit) and the test asserts both the raw
   exception AND its `toAppError()` mapping (PermissionError/ValidationError/ServerError/
   NetworkError/UnauthorizedError/RateLimitError) — the real `error_mapper`.

## Decisions & rationale

1. **No lib/ changes at all.** All services are constructor-injected; providers take
   Riverpod overrides or the established notifier-subclass stub pattern — so TST-02's
   mocktail adoption required zero production seams.
2. **Friends/groups feature providers call `SupabaseService.instance` directly**
   (pre-existing legacy-coupling). Error-state tests use the notifier-subclass throw
   pattern (same as `profile_providers_test.dart`) — the underlying service behavior
   (search filter pass, contribution aggregation) is covered at the service layer
   instead. Reported as a legacy-coupling note for I-50 (repository layer).
3. **Realtime subscription lifecycle** is tested with a mocktail `RealtimeChannel`
   (channel naming, event/table wiring, `subscribe()` called, callback payload
   extraction) — a real socket lifecycle test is impossible without a live stack and is
   I-52's scope (reconnect/backoff provider).
4. **I-38 concurrency:** I-38's E2EE chat integration landed mid-run
   (`chat_service.dart`/`realtime_service.dart` changed under their lock): `subscribeToMessages`
   became sync (`RealtimeChannel` return). I re-read both files and adapted my two test
   files to the new signature; my tests exercise the plaintext path (no E2EE deps
   injected → `e2eeEnabled == false`). No lib files touched by me.

## MISTAKE blocks

- **MISTAKE (synchronous `then` in ResolvingBuilder):** the original `Future.value(onValue(_value))`
  called the awaited continuation synchronously. A continuation that THROWS escaped to the
  test zone as an *uncaught* error — even a plain `try { await ... } catch` could not catch
  it. Fix: `Future(() => onValue(...))` — defer like a real Future. Symptom: service
  methods "throwing" broke tests that correctly expected a caught error.
- **MISTAKE (list typing in builder values):** `ResolvingBuilder<PostgrestList>([...])` with
  an untyped literal infers `List<dynamic>` and the `as T` cast fails at runtime. Fix:
  `coerce()` normalizes lists into `List<Map<String, dynamic>>` before the cast.
- **MISTAKE (mocktail named matchers):** `params: captureAny()` without
  `captureAny(named: 'params')` throws "argument matcher not used as an immediate argument".
  Named args need `named:` — always.
- **MISTAKE (verify double-count):** `verify(...).called(1)` marks the call as verified;
  a second `verify(...).called(2)` then counts only the unverified calls → "Expected 2,
  Actual 1". Use a single end-state verify.
- **MISTAKE (per-call service instances):** BanService caches per-*instance*; tests that
  called `service()` twice per test saw two DB hits. Keep one instance per test.
- **MISTAKE (enum fallbacks):** `any(named: 'event')`/`any(named: 'type')` on enums
  (`PostgresChangeEvent`, `OtpType`) and on `UserAttributes` need `registerFallbackValue`
  in `setUpAll`.
- **MISTAKE (function-type contravariance):** capturing a `void Function(PostgresChangePayload)`
  callback into a `void Function(dynamic)` variable fails at runtime — type the capture
  variable precisely.
- **MISTAKE (throwsA on async):** `expect(() => future, throwsA(predicate))` failed
  weirdly with the raw exception when the future's error was produced through the (then)
  sync-`then` builder — the sync-`then` fix made the matcher work again. Keep failure
  paths on `captureError()` where matcher weirdness appears.

## Concurrency notes

- I-38 (chat E2EE) holds lib/features/chat/* + app_router + chat_screen_test; their
  `realtime_service.dart`/`chat_service.dart` edits landed mid-run — adapted to, not fought.
- I-45/I-46/I-47/I-48 working in parallel on other test files; no lock conflicts.
- Full suite: 949 pass / 2 fail — the 2 failures are I-38's in-flight `/chat/` route
  tests in `test/router/app_router_test.dart` (I-47's lock), pre-existing concurrent
  work, NOT regressions from this agent.

## Commands run

```
dart analyze test/support test/services test/providers   # 0 issues
dart analyze                                             # 0 errors (1 pre-existing info in I-38's chat_e2ee_test)
flutter test test/services/                              # 184 pass
flutter test test/providers/                             # 48 pass
flutter test test/services/ test/providers/              # 232 pass
flutter test                                             # 949 pass / 2 fail (I-38 in-flight chat route tests)
```

## Issues found (out of scope, reported)

1. **Feature providers call the legacy singleton** `SupabaseService.instance` directly
   (`friends_providers.dart`, `groups_providers.dart`) — unmockable at the service
   boundary; recommend the I-50 repository layer / service-provider refactor.
2. **`RealtimeService.subscribeToMessages` return-type churn** (Future<void> → sync
   RealtimeChannel) is a breaking API change for any call site that `await`s it — the
   facade (`SupabaseService.subscribeToMessages`) still returns Future<void>; verify I-38
   migrates call sites.
3. `mocktail` needed `registerFallbackValue` for 3 SDK types (OtpType, UserAttributes,
   PostgresChangeEvent) — worth a shared test bootstrap later (I-48 meta-guards scope).
