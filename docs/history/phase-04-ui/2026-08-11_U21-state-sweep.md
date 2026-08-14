# 2026-08-11 — U-21: State-widget sweep — M-28/UI-04 completion

**Agent:** U-21 (state-widget sweep — `VLoadingView`/`VEmptyView`/`ErrorView` adoption)
**Phase:** 04-ui (4.4) | **Status:** DONE
**Scope:** migrate every remaining hand-rolled spinner/empty/error site in `lib/features` to the shared state widgets (`lib/shared/widgets/state_views.dart` — I-74) + `ErrorView` (I-06), per DISCO-DESIGN-SYSTEM §5.8/§5.9; lock the result with a conventions guard; update per-feature tests; docs.

## Audit — hand-rolled state sites (pre-change)

`rg "CircularProgressIndicator" lib/features` → **29 sites / 19 files**. Plus bare `Center(Text)` empty states (chat, group_members, my_groups, group_detail tabs) and 5 private empty-state classes (`_EmptyGallery` photos, `_EmptyState` shard/minigames/party_finder×2, `_EmptyCatalog` cosmetics) that hand-rolled the §5.9 pattern.

## Migration table

| File | Loading | Empty | Error | Notes |
|---|---|---|---|---|
| `photos/screens/photo_gallery_screen.dart` | → `VLoadingView` | `_EmptyGallery` deleted → `VEmptyView(photo_library_outlined, photosEmpty, photosEmptyBody, CTA only while window open)` | kept `ErrorView` | 18px upload-button spinner kept (inline, allowlisted) |
| `events/widgets/event_invite_route.dart` | → `VLoadingView` | — | kept `ErrorView` | |
| `groups/screens/my_groups_screen.dart` | → `VLoadingView` | `Center(Column 2×Text)` → `VEmptyView(group_outlined, groupsNoneYet, groupsNoneYetSubtitle)` inside `VRefreshable` (pull-to-refresh preserved) | kept `ErrorView` | |
| `shards/screens/shard_ledger_screen.dart` | → `VLoadingView` | `_EmptyState` deleted → `VEmptyView(receipt_long, shardsLedgerEmpty, shardsLedgerEmptyBody)` | kept `ErrorView` | pixel-identical (§5.9 match) |
| `events/screens/event_detail_screen.dart` | → `VLoadingView` | — | kept `ErrorView` | |
| `minigames/screens/minigames_screen.dart` | → `VLoadingView` | `_EmptyState` deleted → `VEmptyView(sports_esports, minigamesEmpty, minigamesEmptyBody)` | kept `ErrorView` | pixel-identical |
| `party_finder/screens/party_finder_screen.dart` | 2× → `VLoadingView` | `_DiscoveryOffState` + `_EmptyState` deleted → `VEmptyView(travel_explore / people_outline + title/body)` | kept `ErrorView` | pixel-identical |
| `events/screens/event_edit_screen.dart` | → `VLoadingView` | — | kept `ErrorView` | |
| `groups/screens/group_detail_screen.dart` | 3× → `VLoadingView` | members-empty + both coming-soon tabs → `VEmptyView` inside new `_scrollableTabBody` (U-19 §7.3) | kept `ErrorView` | **MISTAKE→FIX:** bare `VEmptyView` in the chat tab overflowed the 120px-min tab area at 1.5× scale (79px) — responsive test caught it; wrapped in scroll-safe body |
| `subscriptions/screens/paywall_screen.dart` | → `VLoadingView` | — | kept `ErrorView` | |
| `qr/screens/qr_scanner_screen.dart` | checking → `VLoadingView` | unavailable/denied → `VEmptyView` + retry CTA (`commonRetry`) | — | 16px scan-chip spinner kept (inline, allowlisted) |
| `cosmetics/screens/cosmetics_shop_screen.dart` | → `VLoadingView` | `_EmptyCatalog` deleted → `VEmptyView(style_outlined, cosmeticsEmptyCatalog)` | kept `ErrorView` | icon color muted→`border`, text → headlineSmall (§5.9) |
| `profile/screens/profile_screen.dart` | → `VLoadingView` | — | kept `ErrorView` | |
| `qr/screens/attendance_qr_screen.dart` | 2× → `VLoadingView` | — | kept `ErrorView` | |
| `profile/screens/public_profile_screen.dart` | → `VLoadingView` | — | — | |
| `profile/screens/edit_profile_screen.dart` | → `VLoadingView` | — | — | 16px avatar-upload spinner kept (inline, allowlisted) |
| `groups/screens/invite_screen.dart` | → `VLoadingView` | — | kept `ErrorView` | 20px AppBar send spinner kept (inline, allowlisted) |
| `chat/screens/chat_screen.dart` | → `VLoadingView` | bare `Center(Text)` → `VEmptyView(chat_bubble_outline, chatEmpty)` | bare `Center(Text)` → **`ErrorView` with retry** (`ref.invalidate`) | 20px pagination spinner kept (inline, allowlisted) |
| `groups/screens/group_members_screen.dart` | → `VLoadingView` | bare `Center(Text(Colors.grey))` → `VEmptyView(people_outline, groupsNoMembers)` | — | also killed a raw `Colors.grey` |

**Justified exceptions (kept raw, documented):** `v_button.dart` button spinner (shared widget, outside `lib/features`); photo upload button 18px; requests R11 per-row 16px; edit-profile avatar 16px; qr scan-processing chip 16px; chat pagination 20px; invite AppBar action 20px.

## Conventions guard (`test/meta/conventions_test.dart`, +1 test)

New group **"state-widget sweep guard (U-21)"**: `RegExp(r'CircularProgressIndicator\s*\(')` over all `lib/features/**/*.dart` must be empty except the 6 documented inline-spinner sites in `rawSpinnerAllowlist` (path:line pinned). RED-proven: first run flagged `photo_gallery_screen.dart:149` (line drift after the CTA edit) — allowlist corrected to `:148`, GREEN.

## Tests updated (spinner/empty assertions → widget types)

- `test/features/groups_screens_test.dart` — GroupMembersScreen loading → `find.byType(VLoadingView)`; empty → `find.byType(VEmptyView)`.
- `test/features/chat/chat_screen_test.dart` — empty → + `VEmptyView` assertion.
- `test/features/events/invite_token_route_test.dart` — loading → `VLoadingView`.
- `test/features/profile_screens_test.dart` — loading → `VLoadingView`.
- `test/features/photos/photo_gallery_test.dart` — empty → + `VEmptyView`.
- `test/features/minigames/minigames_screen_test.dart` — empty → + `VEmptyView`.
- `test/features/party_finder/party_finder_screen_test.dart` — empty → + `VEmptyView`.
- `test/features/cosmetics/cosmetics_shop_screen_test.dart` — empty → + `VEmptyView`.
- `test/features/shards/shard_ledger_screen_test.dart` — empty → + `VEmptyView`.
- `test/features/qr/qr_scanner_screen_test.dart` — denied → + `VEmptyView`.

## MISTAKE blocks

- **MISTAKE (layout):** group_detail chat tab `VEmptyView` overflowed the tab area at 1.5× on 320×568 (RenderFlex +79px) — the §5.9 view (48px icon + sectionGap + headlineSmall) is taller than the `_minTabArea` 120px U-19 guarantees. Fix: `_scrollableTabBody` (`LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight)`), applied to all three empty/coming-soon tabs. Caught by `test/features/responsive_test.dart` — the sweep's zero-visual-change rule made this the only regression, and the test suite found it before any review.
- **MISTAKE (test):** photo_gallery allowlist line drifted `149→148` after removing the `VButton` import — the new guard proved itself by failing; corrected.
- **MISTAKE (edit):** a test-file import edit merged two lines into one (`events_providers.dart` + `photo_gallery_screen.dart`); caught by `dart analyze`? No — by visual check; fixed before running the suite.

## Commands run

```
rg -n "CircularProgressIndicator" lib/features          # audit (29 sites / 19 files)
dart analyze                                            # 0 issues
flutter test test/features/ test/widgets/ test/meta/    # 773/773
flutter test                                            # FULL SUITE 1961/0 (baseline 1960 + 1 new guard test)
```

## Docs updated

- `docs/to-fix/TODO.md` — U-21 completion block + M-28 row → ✅ (I-74 + U-21).
- `docs/to-fix/categories/07-UI-DESIGN.md` — UI-04 → ✅ RESOLVED.
- `docs/history/phase-04-ui/2026-08-11_U21-state-sweep.md` (this log).

## Issues for U-22 handoff

- **U-22 (skeletons):** §5.8 skeleton/shimmer loading is still unbuilt — `VShimmer` exists (U-06) but no screen uses skeleton cards; the sweep's `VLoadingView` full-screen spinners are the §5.8 default, skeletons remain the next agent's scope.
- **Pre-existing (not touched):** `create_event_screen.dart:338-359` + `create_group_screen.dart:162` cover-picker placeholders use inline icon+text (form placeholders, not state views) — out of sweep scope, still `Colors.grey[900]`/`muted` mixes; U-26 contrast pass should review the `grey[900]` one.
- **Pre-existing (not touched):** `qr_scanner_screen.dart` `_cameraError` path (mobile_scanner `errorBuilder`) predates the sweep's permission panels — consistent enough, flagged for U-25 review.
- **Pre-existing (reported):** `docs/design/DISCO-DESIGN-SYSTEM.md:216` documents the button loading spinner as "current behavior" — still accurate post-sweep (`v_button.dart` spinner untouched).
