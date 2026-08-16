# 2026-08-15 — C-search-accept: ISSUE 5 — accept inbound requests from search

Agent: `C-search-accept` — ISSUE 5 fix.

## What was built

When user A sends a friend request to B, and B searches for A, B saw the
static "Solicitado" badge with no way to accept. Now an INBOUND pending
request (I'm the addressee) renders a primary mint-outlined **Aceptar**
button that accepts the request directly from the search row. Outbound
requests (I'm the requester) keep the static "Solicitado" badge.

- **C1** `lib/core/services/user_service.dart` — `searchUsers` now fetches
  `id, requester_id, addressee_id, status` in both friendship queries and,
  for `pending` rows only, enriches each result with `friendship_id`
  (row `id`) and `friendship_direction` (`sent` when I'm the requester,
  `received` when I'm the addressee). `friendship_status` and block
  behavior unchanged; non-pending rows carry neither new key.
- **C2** `lib/features/friends/screens/search_screen.dart` —
  `_buildButton`: `pending` + `friendship_direction == 'received'` →
  `VButton.outlined` (`l10n.commonAccept`, mint, width 104) calling the new
  `_acceptFriendRequest(user)`; any other pending row keeps the
  `VBadge.accent(friendsStatusPending)`. `_acceptFriendRequest` reads
  `friendship_id`, calls `friendsRepositoryProvider.acceptFriendRequest(id)`,
  invalidates `searchResultsProvider(_query)`, `friendRequestsProvider`,
  `friendsListProvider`, shows the `profileRequestAccepted` snackbar, and
  surfaces errors via `AppLogger` + `showErrorSnackBar` (same pattern as
  `_sendFriendRequest`).

## Decisions

- Success snackbar reuses the existing `l10n.profileRequestAccepted`
  ("Solicitud aceptada") — no new l10n keys (per assignment).
- `restyle_test.dart` needed NO changes: its pending fixture has no
  `friendship_direction`, which per spec keeps the badge.
- Invalidation assertion requires the non-watched providers
  (`friendsListProvider`/`friendRequestsProvider`) to be pre-loaded in the
  `ProviderContainer` — `ref.invalidate` on a never-initialized provider is
  a no-op (found while debugging the first test run).

## Commands

```bash
flutter test test/services/user_service_test.dart --plain-name "ISSUE 5"   # RED: 1 pass + 2 fail
flutter test test/features/friends/flow_test.dart --plain-name "ISSUE 5"   # RED: sent-test pass, received-test fail
dart analyze lib/core/services/user_service.dart lib/features/friends/screens/search_screen.dart \
  test/services/user_service_test.dart test/features/friends/flow_test.dart test/features/friends/restyle_test.dart  # 0 issues
flutter test test/services/user_service_test.dart test/features/friends/flow_test.dart test/features/friends/restyle_test.dart  # 99 pass / 0 fail
```

## MISTAKE

Asserting provider invalidation with a counting notifier fails when the
provider was never read before the invalidate: `ref.invalidate` on an
uninitialized provider is a no-op, so the first post-tap read is build #1,
not #2. Fix: pre-load the non-watched providers
(`await container.read(provider.future)`) before pumping the widget, so the
invalidation has live state to invalidate.
