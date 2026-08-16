# 2026-08-16 — group message latency: roster TTL, parallel distribution, publish-once (ISSUE: latency in message arrival)

Agent: `orchestrator-issue4` · Phase 07 (chat) · Working tree only.

## Symptom (user report)

"There is latency in the arrival of messages [in groups] — anything to securely
improve it?" (E2EE must be untouched: no plaintext, no key material changes,
no weakening of the envelope/chain protocol.)

## What was built (RED → GREEN)

Every group send used to pay **three** network round trips before the message
row even landed: (1) the `chats` metadata SELECT (cached — fine), (2) the
`chat_participants` roster SELECT — on EVERY send, and (3) a full
`publishAll()` (identity + SPK + 100 OPKs) — on EVERY send, because the old
guard keyed on the 1:1 session map, which group chats never populate. Plus the
per-member distribution loop ran strictly SERIALLY, so N missing members meant
N sequential encrypt+INSERT round trips before the message row.

### Fixes (all E2EE-neutral — ciphertext wire, chain protocol, keys untouched)

1. **Roster TTL** — `_rosterCache` now stores `_RosterSnapshot(roster,
   fetchedAt)`; `_sendGroupMessage` re-fetches at most every
   `groupRosterTtl` (30 s, injectable for tests). Steady-state sends: one less
   round trip. A membership change is noticed at the next TTL boundary (or via
   the shell's realtime members listener); an added member who misses a
   message self-heals through the 2026-08-17 key-request protocol (Issue 1),
   so the TTL is safe.
2. **Parallel distribution** — `_distributeBundleToMissing`: the bundle is
   built ONCE (racing concurrent builds on the real cipher would mint
   competing chain roots — receivers would desync), then each member's
   (pairwise encrypt → INSERT) runs in PARALLEL (per-member sessions are
   distinct objects — crypto is independent); the registry `markSenderKeyDistributed`
   calls stay SERIAL (the registry JSON is a read-modify-write document —
   parallel marks would lose updates). The message row still lands after
   `Future.wait` — every distribution row precedes the message, preserving
   the bundle-before-message realtime order.
3. **Publish-once** — `_publishedForUser` (uid-scoped, so an account switch
   re-publishes the new identity) replaces the broken 1:1-namespace guard:
   the bundle is published once per (process, uid), not per message.

## Tests (RED → GREEN)

`test/services/chat_service_test.dart` +3:
1. **roster TTL**: two consecutive sends → exactly ONE `chat_participants`
   SELECT (pre-fix: two); `membersMissingSenderKey` still fed the roster on
   both sends.
2. **parallel distribution**: gated session store proves the two pairwise
   encrypts OVERLAP (maxActive > 1 — pre-fix serial stays 1); the message row
   is still the last insert; both distribution rows land; both registry marks
   called (serial).
3. **publish-once**: two sends → exactly ONE `e2ee_identity_keys` upsert
   (pre-fix: two).
Also relaxed the pre-existing 'distributes FIRST' test to order-agnostic
distribution rows (parallel completion order is not member order) and gave the
roster-SHRINK test `rosterTtl: Duration.zero` (the shrink must be detected on
the very next send).

Validation: `flutter test` **2438/2438** (2414 + 7 I1 + 2 I2 + 12 I3 + 3 I4),
`dart analyze` 0, `go test` green, `make check` PASS, pgTAP 494/494,
`run_all_backend.sh` 11/11 (all unchanged by the client-only latency work).

## Decisions made and why

- **TTL over always-fresh roster**: one round trip per send is the dominant
  steady-state cost; change detection can tolerate one TTL window because the
  key-request protocol (Issue 1) heals the miss. Rekey-on-roster-change still
  happens at every TTL boundary.
- **Bundle-once + parallel encrypt**: the real cipher's `_ensureOwnRecord` is
  not concurrency-safe — a single build up front is both correct and cheaper.
- **Serial marks**: registry integrity > mark speed (marks are local writes;
  they were never the bottleneck).

## MISTAKE (caught during GREEN)

The first publish-once implementation used a bare `bool _publishedThisProcess`
— an ACCOUNT SWITCH in the same process (keys wiped, new identity) would have
kept the flag true and never published the new identity's bundle, deadlocking
the first distribution round. Reworked to `_publishedForUser` (uid-scoped):
same-account re-sends skip (Signal model — keys survive sign-out), a different
uid re-publishes.

## Verifier fix round (2026-08-17 — independent review, 2 findings, 1 fixed)

| Finding | Disposition |
|---|---|
| `fetchedAt` was refreshed on cache REUSE — a group sending faster than the TTL would never re-fetch, so the wipe-on-change rekey could never fire for busy groups (documented "next TTL boundary" guarantee unmet) | **FIXED**: the snapshot is only stored when a fetch actually happened — the TTL window now measures from the last FETCH, so busy groups re-fetch every boundary |
| publish-once changes the 1:1 OPK top-up cadence (a process with >100 new 1:1 peers exhausts the server OPK pool) | **Accepted, no fix**: X3DH falls back to SPK-only when no OPK is available (`session.dart`), and the auth heal re-publishes on login — documented here |

## Commands run

```bash
# RED (compile-time missing behavior)
flutter test test/services/chat_service_test.dart --plain-name "reuse the cached roster"   # groupRosterTtl undefined
flutter test test/services/chat_service_test.dart --plain-name "encrypts in PARALLEL"      # same

# GREEN
dart analyze lib/core/services/chat_service.dart test/services/chat_service_test.dart   # 0 issues
flutter test test/services/chat_service_test.dart                                        # 46/46
flutter test                                                                            # 2438/2438
dart analyze                                                                            # 0 issues
make check                                                                              # PASS
bash test/run_all_backend.sh                                                             # 11/11
```

Locks: `lib/core/services/chat_service.dart` + `test/services/chat_service_test.dart`
(owner `orchestrator-issue4`) — held for the verifier pass.

Follow-up: independent verifier review in progress.
