# 2026-08-11 — V-02: To-fix ledger status re-verification (report)

**Agent:** V-02 (Phase 4.6 — Doc verifiers) · **Mode:** verify + status fixes
**Scope:** `docs/to-fix/TODO.md` + all 17 `docs/to-fix/categories/*.md`
statuses vs the current working tree.

## Result

All **48** findings still marked `❌ verified still open 2026-08-09 — planned
→ <agent>` were individually re-verified against the code and re-stated:

| Outcome | Count | Notes |
|---|---|---|
| flipped ✅ DONE | 33 | deliverable verified present in the tree (I-04/05/07/09/10/13/14/15/19/20/25/26/29-half, M-13/17-22/25/26, I-70, ports) |
| flipped 🔄 partially/evaluated/deferred | 12 | honest partials (schema monolith, ConsumerStatefulWidget, inbucket dev sink, SEC-12 guard, select() micro-opt, riverpod3, Go dedup mirrored) |
| re-verified ❌ still open | 2 | Go ops dedup (explicitly out of I-40 scope — S-17) + mirrored in 16-CODE-QUALITY |
| already resolved in the ledger | — | pre-existing ✅/🔄 rows left untouched |

## Verification method

Every claim checked against the live tree with grep/stat evidence at
2026-08-11 (e.g. `ListView(children:` = 0, `pathParameters[...]!` = 0,
`HiveAesCipher` present, `AsyncNotifierProvider` at auth_provider.dart:362,
facade deleted, `.opencode/` + `.github/` + `fastlane/` exist,
`check_ports.sh --strict` STRICT PASS, `setState` in profile_screen = 0,
`package:shared_preferences` never imported, age-gate date localized,
app.dart locales wired).

## Residual (deliberately open, re-verified)

- Go `LogAction` dedup (12-GO-BACKEND / 16-CODE-QUALITY) — decorator pass
  deferred.
- OTP/search enumeration residual (SEC-05) — bounded, documented (S-10).
- `[inbucket]` in the CLI-managed config.toml — dev-only sink.

## Cross-check

`docs/history/phase-00-foundation/2026-08-11_ORCH-prep-*.md` +
S-03..S-19 evidence base used for the flips · no code changed by this pass.

*V-02 ledger verification — 2026-08-11*
