# 2026-08-09 — I-46: Algorithm/logic tests (TST-06 / M-13)

**Agent:** I-46 (RESUME RUN — first session produced zero artifacts, zero locks; verified `tools/agent_lock.sh list` empty at start)
**Status:** DONE
**Scope:** extract inline widget logic into testable pure functions, then unit-test them (age, password, OTP, shards, brackets). No crypto (I-37), no image processor (I-22) — already covered.
**Evidence:** this log, TODO.md M-13 flip.

## What was extracted + tested (TDD: red → green)

| New pure module | Extracted from | Functions | Tests |
|---|---|---|---|
| `lib/features/auth/age_policy.dart` | `age_gate_screen._isAdult` | `isAdult(DateTime?, {DateTime? now})`, `formatDob(DateTime)` | `test/features/auth/age_policy_test.dart` (13) |
| `lib/features/auth/password_policy.dart` | `signup_contact_screen._isPasswordValid` | `isPasswordValid(String)`, `passwordError(String)` | `test/features/auth/password_policy_test.dart` (8) |
| `lib/core/utils/otp_format.dart` | inline in OTP screen | `cleanOtpDigits(String)` | `test/utils/otp_format_test.dart` (4) |
| `lib/core/utils/shard_math.dart` | `groups_providers.dart` `GroupContributionsNotifier.build` (was `group_detail_screen._load`) | `distribute(int, int, {capPerUser})`, `totalActive(int, int)`, `aggregateContributions(Iterable<Map>)` | `test/utils/shard_math_test.dart` (16) |
| `lib/shared/widgets/rank_bracket.dart` | `RankBadge` inline switch + `recalculate_ranks` SQL CASE | `rankBracketLabel(String)`, `rankBracketForPercentile(double)` | `test/widgets/rank_bracket_test.dart` (5) |

**Total: 46 new tests.**

## Rewired widgets (behavior identical — all existing widget tests stayed green)

- `age_gate_screen.dart` — `_isAdult` getter removed; `isAdult(_selectedDate)` at the underage flag and the Continue gate; date label now `formatDob` (same `{day}/{month}/{year}` shape the ARB template rendered; the app is es-first and both ARB locales use the same format).
- `signup_contact_screen.dart` — `_isPasswordValid` removed; `passwordError(password)` drives the inline validation message (exact Spanish string, unchanged).
- `otp_verification_screen.dart` — `_onCodeChanged` and `_verify` both run `cleanOtpDigits`; auto-submit still fires on 6 digits, manual Verificar unchanged. Bonus fix surfaced by the extraction: pasted/hyphenated codes (`123-456`) now verify as `123456` instead of failing the `length != 6` guard.
- `rank_badge.dart` — inline `switch` replaced by `rankBracketLabel` (labels identical, still uppercased).
- `groups_providers.dart` — inline aggregation loop replaced by `aggregateContributions(raw)` (identical semantics: sum by `user_id`, sort desc, input rows copied).

## Decisions made and why

- **`isAdult` is calendar-accurate, not the old `365*18` days rule.** The widget's old approximation treats 17y364d as an adult (6574 days > 6570). The extracted function compares calendar years + birthday (leap-day birthdays turn 18 on Mar 1, not Feb 28). The boundary cases the mission required (exactly-18, 17y364d, future dates, leap-day) only make sense under the calendar rule. No existing widget test exercises the boundary, so nothing regressed.
- **`passwordError` / `rankBracketLabel` keep Spanish literals by design** (BuildContext-free constants, same rationale as error classes in `lib/core/errors/**` per M-15). The app hardcodes `locale: es` (`lib/app.dart:16`), so display output is unchanged. Both literals are allowlisted in `test/l10n/l10n_extraction_test.dart` with documented comments ('Creadores de la Vibra' contains stopword 'creado'; 'En la Búsqueda' and the password message contain accented chars).
- **`distribute` mirrors the SQL with a single `attendees` denominator** and a final `perUser < 0 ? 0` clamp (a negative `capPerUser` must never yield a negative per-user amount — caught by the red test `never returns negative or infinite results`).
- **`formatDob` has no zero padding** — matches the ARB `{day}/{month}/{year}` template exactly (`2/1/2000`, not `02/01/2000`).

## Issues found (report to orchestrator / S-07)

- **Dart-vs-SQL shard math drift (S-07 input):** SQL `distribute_shards` computes the base per-user amount from `total_invitees` and re-clamps from `confirmed_attendees` (`per_user * attendees > pool` → `floor(pool / attendees)`). The Dart mirror collapses both denominators into `attendees`, making that recompute guard unreachable (cap only shrinks `per_user`, so `per_user * attendees ≤ pool` always). Any client-side preview of a distribution must not be assumed to match the RPC when invitees ≠ attendees. Documented in `shard_math.dart` header.
- Pre-existing, untouched: `group_detail_screen._getMemberLimit` still returns a hardcoded `'14'` (it looks up nothing) — out of scope, reported for M-23/U-11.
- `authPasswordTooWeak` ARB key is now unused by widgets (passwordError is the single source). Key left in ARB deliberately — en locale work (L-14) may re-use it.

## Commands run

```bash
tools/agent_lock.sh list                                     # pre-flight: 0 locks
flutter test test/features/auth/age_policy_test.dart ...     # RED: +0 -5 (methods not found)
flutter test ... (same 5 files)                              # GREEN: +46
dart analyze                                                 # No issues found
flutter test test/features/auth_screens_test.dart test/widgets/rank_badge_test.dart \
  test/features/groups_screens_test.dart test/l10n/l10n_extraction_test.dart \
  test/features/auth/otp_ux_test.dart test/features/auth/auth_interactions_test.dart \
  test/meta/conventions_test.dart                            # +64 all passed
flutter test                                                 # +997 all passed
tools/agent_lock.sh release <each of 18 paths> --owner I-46-resume
```

## MISTAKE blocks

- **MISTAKE (spec, shard math):** my first `distribute` implementation lacked the negative-clamp, so `distribute(10, 5, capPerUser: -3)` returned `-3`. The red test caught it — the mission spec says "no negative results". Fix: final `perUser < 0 ? 0`. TDD worked exactly as intended; the test was the spec, the implementation was wrong.
- **MISTAKE (l10n guard):** allowlisted 'En la Búsqueda' and the password message, but the first l10n_extraction run still failed on 'Creadores de la Vibra' — it contains the stopword `creado` ('creadores'). Lesson: stopword matching is substring-based after accent normalization; allowlist by running the guard, not by eyeballing accents.
