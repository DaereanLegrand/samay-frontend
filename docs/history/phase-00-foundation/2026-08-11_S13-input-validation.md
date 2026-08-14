# 2026-08-11 — S-13: Input validation + fuzz audit (report)

**Agent:** S-13 (Phase 4.5 — Security) · **Mode:** report-only
**Scope:** `InputSanitizer` (I-27) coverage, form validators, OTP/password
rules, server-side constraints.

## Verified posture

| Check | Verdict | Evidence |
|---|---|---|
| Shared sanitizer at every write boundary | ✅ | 67 call sites / 12 files: username (NFKC, 20 cap), bio (160), group name/desc (50/250), search queries, donate amounts (digits, 9), chat messages (500) — `lib/core/utils/input_sanitizer.dart` |
| Sanitizer semantics | ✅ | trim → strip Unicode `\p{Cc}\p{Cf}` (control + zero-width/bidi) → optional NFKC (unorm_dart) → grapheme-cluster cap (emoji-safe); 29 unit tests green |
| OTP / password / form rules | ✅ | `otp_format` (6-digit, digits-only), `password_policy` (≥8 + digit — S-05 raised), `form_validators` — 68 combined tests green |
| Edge-case tests (I-46) | ✅ | `test/utils/` suite: sanitizer, OTP, shard math, pagination, image processor, debouncer |

## Findings

1. **No server-side length constraints on user-writable text columns**
   (username, bio, group name/description, messages): the schema's CHECKs
   cover economy invariants only (`check_casual_no_preshards`). The
   sanitizer is client-only — a crafted PostgREST caller can write
   arbitrarily long values. **Fix (recommended, I-31 track / S-03
   follow-up):** DB CHECK constraints on `char_length()` for the bounded
   columns, matching the client caps.
2. **No automated fuzz harness** — the sanitizer/OTP/password suites are
   hand-written edge cases. A lightweight property/fuzz pass (e.g.
   random-input idempotence for the sanitizer) is a nice-to-have; the
   invariant "valid input unchanged, invalid input neutralized" is already
   pinned by the 29 tests.

## Verifier cross-check

68 combined tests green · sanitizer grep sweep (all write sites) ·
DB CHECK inventory (`information_schema`).

*Samay input-validation audit — S-13 · 2026-08-11*
