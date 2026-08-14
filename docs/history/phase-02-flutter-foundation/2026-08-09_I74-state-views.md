# 2026-08-09 — I-74: Shared state views (loading/empty + VStateView switch)

**Agent:** I-74 (shared state widgets — `lib/shared/widgets/state_views.dart`)
**Status:** DONE
**Scope:** `VLoadingView`/`VEmptyView`/`VStateView` (const-constructible, themed per DISCO-DESIGN-SYSTEM §5.8/§5.9), migration of 6 screens, widget tests, TODO.md + 07-UI-DESIGN.md statuses.

## What was built

### `lib/shared/widgets/state_views.dart` (new, single barrel)
- **`VLoadingView`** — centered white `CircularProgressIndicator` (24px, `strokeWidth: 2`) on black + optional `mutedStrong` caption. **Spinner is white, not pink** (decision, §5.8): loading is not a brand moment (P3 "accents are privileges, not defaults"; pink reserved for welcome/checkout-class moments — the design doc's own wording).
- **`VEmptyView`** — `xxl` (48px) icon in `#333333` (`AppColors.border`), `headlineSmall` title, optional `mutedStrong` description, optional outlined CTA (`VButton.outlined`, 200px wide — mirrors `ErrorView`'s retry button). Props: `icon` (default `Icons.inbox_outlined`), `title`, `description?`, `actionLabel?`, `onAction?`. Default action label falls back to `l10n.commonContinue` (same pattern as `ErrorView.retryLabel ?? commonRetry`).
- **`VStateView`** — dumb switch: `VStateView(loading:, error:, errorMessage:, onRetry:, child:, empty:, loadingLabel:)`. Priority **loading > error > child ?? empty**. `AsyncValue`-agnostic: screens pass plain bools and the already-mapped `errorMessage` (`Object.toAppError()`), so the widget has zero Riverpod/Supabase imports. `errorMessage == null` falls back to `error.toString()` (documented; screens should always map).

### Screens migrated (6)
| Screen | Change |
|---|---|
| `friends/friends_list_screen.dart` | loading → `VLoadingView`; empty → `VEmptyView(icon: person_search, title: friendsNoneYet, description: friendsSearchPrompt)` |
| `friends/blocked_users_screen.dart` | **full `VStateView` adoption** (loading/error/empty/data); empty → `VEmptyView(icon: block, title: friendsNoneBlocked)` |
| `friends/requests_screen.dart` | both nested `loading:` branches → `VLoadingView` (empty states intentionally untouched — plain centered text, mission scoped loading only) |
| `groups/leaderboard_screen.dart` | **full `VStateView` adoption**; empty → `VEmptyView(icon: leaderboard_outlined, title: groupsNoRankingData)`; `error_view.dart` import dropped (VStateView renders ErrorView internally) |
| `feed/feed_screen.dart` | loading → `VLoadingView`; `_EmptyState` class deleted → `VEmptyView` inside the existing `SliverFillRemaining(hasScrollBody: false)` (keeps pull-to-refresh on empty) |
| `notifications/notification_center_screen.dart` | loading → `VLoadingView`; `_EmptyState` class deleted → `VEmptyView(icon: notifications_none, title: notificationsEmpty, description: notificationsEmptyBody)` |

`VStateView(loading: asyncValue.isLoading, …)` is behavior-identical to the old `AsyncValue.when(loading:)` triad — verified against riverpod 2.6.1 source: `isRefreshing => isLoading && (hasValue || hasError) && this is! AsyncLoading`, so a pull-to-refresh still swaps to the spinner exactly like `.when()` default (no `skipLoadingOnRefresh`).

### Tests — `test/widgets/state_views_test.dart` (22, TDD RED→GREEN)
- `VLoadingView` (5): spinner renders, label renders, label hidden, **spinner color == `AppColors.white`** (§5.8), const-constructible.
- `VEmptyView` (8): default inbox icon + title, custom icon + description, description hidden, action fires, default label `commonContinue`, action hidden when `onAction == null`, icon `border`/description `mutedStrong` colors, const-constructible.
- `VStateView` (9): loading wins over error, error → `ErrorView` with mapped message, `toString()` fallback, retry fires `onRetry`, data branch, child-wins-over-empty, empty branch, idle → nothing, const-constructible.
- No existing test needed edits: `friends_screens_test.dart` (113-targeted run incl.) asserts texts + `find.byType(CircularProgressIndicator)` (still satisfied — `VLoadingView` contains one).

## Decisions & rationale

1. **`VStateView` API** — the mission asked to "decide the simplest API": `{bool loading, Object? error, String? errorMessage, VoidCallback? onRetry, Widget? child, Widget? empty, String? loadingLabel}`. `errorMessage` pre-mapped keeps the widget dumb and decoupled from `error_mapper`/supabase; `child ?? empty` lets screens pass `null` child for empty data without extra branches.
2. **White spinner** — design doc §5.8 is explicit ("white `CircularProgressIndicator` (24px)… accent variant `glowPink` for brand moments"). Existing screens' spinners were already white (theme `primary` is white) but 36px default; the shared widget normalizes to **24px** per spec.
3. **`VEmptyView` title style** — `headlineSmall` (20/w600) per §5.9, matching the I-53/I-58 empties (notifications/feed already conformant). `friends_list`'s old empty used `headlineMedium` (24/w700) — migrating it to `VEmptyView` changes that one title 24→20. Documented as design-doc alignment (MISTAKE-class deviation flagged below).
4. **Empty-state icons** — design doc §5.9 allows a neutral `#333333` icon; screens that previously showed bare centered text (blocked_users, leaderboard, friends_list) now show an icon. Visual-diff note: **blocked_users/leaderboard/friends_list empties gain an icon**; feed + notifications empties are pixel-identical to before (same icon/size/colors/gaps — verified against the deleted private classes).
5. **`requests_screen` empties untouched** — mission listed requests for loading only; the three plain-text empty tabs are a different (simpler) pattern, left for U-21.

## MISTAKE blocks

- **MISTAKE (test):** first RED run failed to compile with `Exception('boom')` inside `const VStateView(...)` — `Exception`'s constructor is not const. Dropped `const` on the three error-branch instances. The const-constructibility of the widgets themselves is asserted separately with real const instances.
- **MISTAKE (API):** invented `l10n.friendsBlockedHint` for the blocked_users empty description without checking the ARB — key doesn't exist. Removed the description rather than adding a new ARB key + regen (kept scope minimal; the previous empty state had no description anyway).
- **MISTAKE (lint):** `sort_child_properties_last` fired on `VStateView(child: …)` invocations — fixed by putting `empty:` before `child:` in test call sites (named args order is free); screens were already written child-last.
- **Pre-existing (not mine, reported):** `dart analyze` baseline has 2 infos in `lib/core/services/user_service.dart:176` (`curly_braces_in_flow_control_structures`) — left untouched.

## Commands run

```
dart analyze                                   # 0 errors (2 pre-existing info, user_service.dart)
flutter test test/widgets/state_views_test.dart test/features/friends_screens_test.dart test/features/groups_screens_test.dart test/features/notifications/ test/features/feed/
                                               # 113/113
flutter test                                   # FULL SUITE 1629/0
```

## Docs updated
- `docs/to-fix/TODO.md` — M-28 ✅ (I-74, 2026-08-09) + workstream paragraph.
- `docs/to-fix/categories/07-UI-DESIGN.md` — UI-04 status → 🔄 (I-06 error widgets + I-74 state views shipped; remaining ad-hoc sites → U-21).
