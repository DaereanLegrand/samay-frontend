# 2026-08-17 — VAurora ambient background: removed entirely from the codebase

## What was built

The `VAurora` widget (`lib/shared/widgets/v_aurora.dart`) — the LUXE ambient
aurora background of 2–3 huge drifting radial pastel blobs mounted on every
screen — was **deleted entirely**. The user reported a "rounded, blueish glow"
artifacting on the always-black background (the cyan/violet radial blobs at
α0.04–0.10); the directive was to remove the aurora completely.

## What was removed

1. **`lib/shared/widgets/v_aurora.dart`** — deleted (StatefulWidget, blobs,
   drift controller, `_anchors`/`_blobScale` geometry).
2. **`test/widgets/v_aurora_test.dart`** — deleted (its whole suite).
3. **`AppGradient.radial()`** (`lib/core/design_tokens/app_gradients.dart`) —
   dead after the removal (aurora-only consumer); the two `radial(...)` tests
   in `test/design_tokens/app_gradients_test.dart` were removed too.
4. **All 46 screens/widgets that mounted `VAurora(...)`** — every usage was
   unwrapped to its `child:` (the blobs were a background layer only), the
   `import .../v_aurora.dart` was dropped, and per-screen "one aurora per
   screen" doc comments were updated. Screens had one of these shapes:
   - `body: VAurora(... child: X)` → `body: X`
   - `SafeArea(child: VAurora(... child: X))` → `SafeArea(child: X)`
   - `return VAurora(... child: X)` → `return X`
   - `_ambient(child)` helper (event_detail, event_invite_route) → removed,
     call sites pass the child directly
   - `Expanded(child: VAurora(... child: X))` → `Expanded(child: X)`

   Full file list (46): all `lib/features/auth/screens/*`, chat_list/chat,
   cosmetics_shop, all events screens + event_invite_route, feed, friends
   (search/list/blocked/requests), groups (my_groups/create/group_detail ×2/
   members/invite/leaderboard/donate), minigames, notification_center,
   party_finder, photos, profile (profile/settings/edit/public/delete/
   notification_settings/privacy_info), attendance_qr, shard_ledger, paywall.
5. **Stale test assertions** — `find.byType(VAurora)` / `widget<VAurora>().gradients`
   pins in `test/features/{auth,feed,friends,groups}/restyle_test.dart` were
   removed (feed kept its black-Scaffold assertion, renamed off-aurora).
6. **Stale comment/doc mentions** of VAurora/aurora across `lib/` and `test/`
   were swept; bounded-pump comments now cite the snackbar's 4s timer instead
   of "the aurora drift".

## Layout-preservation verification

3 parallel read-only agents re-checked all 44 edited lib screens (16+13+15)
for structural/bracket integrity, child-subtree preservation, and shrink-wrap
regression: **all PASS**. Rationale: VAurora was a `StackFit.expand` Stack that
FORCED its child full-bleed; every screen's child was already a self-filling
root (LayoutBuilder→scrollable, `when(...)`, ListView/CustomScrollView,
Column-with-Expanded, Center-based state views), so the loss of the forced
tight fill is a no-op — no bare `Column`/`Padding` shrink-wrap hazard exists.

## Test fix (my regression, indirect)

`test/features/chat/chat_screen_test.dart` "peer-reinstall notice shows ONCE
per peer" FAILED after the removal: pump #1 shows a 4s SnackBar; pump #2's
`pumpAndSettle` previously relied on VAurora's *continuous* 10s drift
animation to advance the fake clock and fire the SnackBar's dismiss timer
before the fresh-tree assertion. Without VAurora the stale snackbar
persisted → `findsNothing` failed. Fix: advance the clock past the snackbar's
4s lifetime (`pump(5s)` + `pumpAndSettle`) before opening the second session —
deterministic, no dependency on ambient animation.

## Mistakes / gotchas

- **MISTAKE (manual group_detail edit):** my first closing-paren edit for the
  second VAurora unwrap matched `_buildInvitedPanel` instead, removing its
  closing `)` and breaking the file (analyze: `expected_token`). Caught by
  `dart analyze`; restored the paren and re-applied the intended removal.
- **MISTAKE (comment sweep scope):** the first comment-sweep agent missed
  `test/features/events/*`, `profile_screens_test.dart`,
  `auth_interactions_test.dart`, and two event-screen doc comments — a second
  sweep caught them.
- **Not-a-mistake, documented:** `SamayDurations.auroraDrift` (10s) remains a
  locked duration token only (no widget consumers left); its value is pinned
  by `test/theme/samay_durations_test.dart`, so it was left in place rather
  than churned away.

## Commands run (reproducibility)

```bash
dart format lib/features/groups/screens/ lib/features/events/ \
  test/features/groups/flow_test.dart test/features/chat/chat_screen_test.dart
dart analyze lib/      # 0 errors; 3 pre-existing info hints (error_mapper)
dart analyze test/     # 0 errors (pre-existing warnings unrelated)
flutter test           # 2455 pass / 0 failures (baseline 2440 → net +15 from pre-existing work)
```

## Test counts

- Full Flutter suite: **2455 pass, 0 failures** (was 2440 baseline).
- AppGradients suite: contracted by 2 (removed radial tests).
- Chat reinstall test: fixed +1 green.

## Deviations

- 3 pre-existing `prefer_const_constructors` info hints in
  `lib/core/extensions/error_mapper.dart` — untouched, unrelated.
- Pre-existing uncommitted agent work in the working tree (typed `GroupMember`
  migrations, `test/support/stub_auth_notifier.dart`, integration_test
  warnings) was left as-is and is outside this change's scope.