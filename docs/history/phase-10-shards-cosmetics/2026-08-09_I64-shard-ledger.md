# I-64 — Shard & Preshard Ledger UI (SLED) · Daily Log

**Date:** 2026-08-09 · **Agent:** I-64 (I-64-shard-ledger) · **Role:** Shard +
preshard ledger screens (SLED foundation) · **Spec:**
`docs/specs/steps/phase-10-shards-cosmetics/SLED-shard-preshard-ledgers.md` ·
**Flags:** none — the shards economy is LIVE (donations exist), so the ledger
route ships open.

## What was built

- **`LedgerEntry` freezed model** (`lib/core/models/ledger_entry.dart`, exported
  from `models.dart`): the shared shape of `shard_ledger` / `preshard_ledger`
  rows (id, delta, reason, reference_id?, created_at — snake_case JSON). Read-only
  display projection (`sl_read_own` / `pl_read_own` RLS); generated with
  `dart run build_runner build`.
- **`ShardsService.getShardLedger({limit})` + `getPreshardLedger({limit})`**
  (`lib/core/services/shards_service.dart`): own rows only (user_id filter),
  `created_at desc`, bounded `limit(100)`, mapped to typed `List<LedgerEntry>`.
- **`lib/features/shards/shard_ledger_providers.dart`**: `ShardLedgerData`
  (shards + preshards lists, derived `shardTotal`/`preshardTotal` net sums,
  `isEmpty`) + `shardLedgerProvider` (AsyncNotifier, `refresh`).
- **`lib/features/shards/shard_ledger_formatters.dart`**:
  `formatLedgerTimestamp` (repo's `EEE d MMM, HH:mm` intl pattern, matching
  `event_formatters.dart`) + `shortReferenceId` (first uuid segment).
- **`lib/features/shards/shard_ledger_screen.dart`**: balance header (Ganados /
  Comprados/Bonos + the "no expiran / solo eventos" note from the SLED economy
  summary), TabBar Shards/Preshards over the newest-first movement lists; each
  entry = reason icon (SLED icon table → Material glyphs) + localized label +
  delta (`+N` white / `−N` gray strikethrough, gold diamond for positives) +
  timestamp + short reference id; per-tab net header; pull-to-refresh; empty +
  `ErrorView` retry states. Black-minimalist per DISCO §1/§5 (tokens only).
- **Reason label/icon mapping**: `shardReasonLabel` (9 shard_reason enum
  values) + `preshardReasonLabel` (6 preshard_reason values) — every value maps
  to an ARB key; unknown values fall back to the raw data string (future-proof).
- **Route + navigation**: `RoutePaths.shardsLedger = '/shards/ledger'` +
  GoRoute (ungated — LIVE); profile `_BalanceCard` is now tappable
  (`InkWell` + chevron) → `context.push(RoutePaths.shardsLedger)`.
- **L10n**: 21 keys × 2 (es/en) — title, tabs, net, empty/error, balance labels
  + notes, reference, 9 shard reasons, 6 preshard reasons. `flutter gen-l10n`
  regenerated the typed localizations.
- **Tests**: `test/core/models/ledger_entry_test.dart` (roundtrip/snake_case/
  nulls/copyWith), `test/features/shards/` (providers: list/derived
  totals/error/refresh; screen: tabs, entries, delta chips, reference, empty,
  error+retry; navigation: route renders + balance-card tap), reason-mapping
  plain tests (every enum value → non-empty localized label, es+en; icon
  coverage), service tests for the two new methods in
  `test/services/shards_service_test.dart`; router tests updated (27 constants,
  coherence entry, provider pin).

## Decisions

- **Typed freezed model over Map passthrough**: the mission contract asked for
  `ledger_entry.dart` freezed (the repo's I-10 model precedent) and the model is
  shared by both ledger tables; the display-only rationale of I-62's Map
  passthrough doesn't apply to a table-shaped row set that will be reused
  (SDIS/GCOS references).
- **Ungated route**: cosmetics stays flag-dark (its DB RPC blocker), but SLED
  only READS rows — `sl_read_own`/`pl_read_own` exist and donations already
  write the ledger, so the history is real data and ships open.
- **Delta colors**: SLED spec offers "green/white" for `+`; the DISCO palette
  has no green token and forbids ad-hoc colors (§8: add token + ratio first),
  so `+` = white (+ gold diamond icon) and `−` = `mutedStrong` gray with
  strikethrough — the spec's own alternative, token-clean.
- **Reference ids display-only** (shortened first uuid segment): making them
  tappable would need entity lookups per row; the mission's "reference id
  short" contract is satisfied; tappability can layer on later.
- **Net header**: the derived totals from the provider are shown per tab
  (`Neto` row) — proves the derived-sum contract without extra queries.

## Commands run

```bash
dart run build_runner build --delete-conflicting-outputs   # LedgerEntry codegen
flutter gen-l10n                                           # after ARB edits
flutter test test/core/models/ledger_entry_test.dart test/features/shards/ test/router/ test/l10n/
flutter test   # full suite → 1427 pass / 0 fail
dart analyze   # 0 errors (2 pre-existing: qr_flow_test unused import, user_service info)
```

## MISTAKE blocks

- **MISTAKE:** `Future.wait([...])` for the two ledger fetches failed to infer
  the element type (`List<dynamic>` → compile error). Fixed by awaiting the two
  futures separately.
- **MISTAKE (Ahem-font overflow, I-62 déjà vu):** the balance header's fixed
  `label + Spacer + value` Rows overflowed in widget tests (Ahem is 1em/glyph;
  "Comprados/Bonos" ≈ 210px). Fixed with `Expanded` + `maxLines:1` + ellipsis
  on the labels. Lesson from I-62's log applied before the gate: any fixed-width
  Row with a >6-char label needs a flex factor.
- **MISTAKE:** initial test asserted `find.text('120 shards')` against a header
  that composed `'Ganados: 120 shards'` into one string. Redesigned the header
  to label + standalone balance (also matches the SLED "labeled Ganados"
  wording) instead of weakening the assertion.
- **Fallout (expected):** adding two abstract methods to `ShardsService` broke
  the 4 `implements ShardsService` fakes in I-62's cosmetics tests +
  `integration_test/cosmetics_flow_test.dart` — patched with `=> const []`
  stubs under lock. `profile_screens_test.dart` chevron count 1 → 2 (balance
  card now has one) updated under lock.

## Files modified (lock evidence — owner `I-64-shard-ledger`)

Acquired + released (list at session end):
`lib/core/models/ledger_entry.dart` (new, + .freezed/.g generated),
`lib/core/models/models.dart`, `lib/core/services/shards_service.dart`,
`lib/features/shards/shard_ledger_formatters.dart` (new),
`lib/features/shards/shard_ledger_providers.dart` (new),
`lib/features/shards/shard_ledger_screen.dart` (new),
`lib/core/router/route_paths.dart`, `lib/core/router/app_router.dart`,
`lib/features/profile/profile_screen.dart`, `lib/l10n/app_en.arb`,
`lib/l10n/app_es.arb`, generated `lib/l10n/app_localizations*.dart` (gen-l10n),
`test/core/models/ledger_entry_test.dart` (new), `test/features/shards/*` (3 new),
`test/services/shards_service_test.dart`, `test/router/route_paths_test.dart`,
`test/router/app_router_test.dart`, `test/features/profile_screens_test.dart`,
`test/features/cosmetics/*` (3 fakes patched),
`integration_test/cosmetics_flow_test.dart` (fake patched),
`docs/history/phase-10-shards-cosmetics/PLAN.md`, `docs/to-fix/TODO.md`,
this daily log.

## Issues found (reported, NOT fixed — out of scope)

- Pre-existing (unchanged): `dart analyze` info `user_service.dart:176`
  (I-60) + warning `integration_test/qr_flow_test.dart:1:8` (I-57).
- `integration_test/runner.sh` still missing `qr_flow_test.dart` +
  `realtime_flow_test.dart` entries (reported by I-62-final; untouched).
- I-62's DB purchase blocker unchanged (no `purchase_cosmetic` RPC) — the
  cosmetics flag must stay dark; SLED is read-only and unaffected.
- SLED spec's "tappable reference link" is display-only in this foundation
  (see Decisions).
