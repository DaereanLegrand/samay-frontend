# 2026-09-09 — QR server-clock anchor (fix device clock skew)

**Agent:** `a-skew` · **Phase:** 16 · **Area:** events / attendance code (`lib/features/qr`, `060_events/07_code.sql`)

## Symptom

Attendee QR (`attendance_code_screen.dart`): the countdown border stayed pinned
empty and the QR froze on a fresh code until the device clock caught up to the
server-issued window boundary (tens of seconds). After that it rotated on the
device's own lattice, so the displayed code could diverge from what the server
would validate.

## Root cause — device wall clock vs server window (proven)

The screen derived both the boundary and the rotating counter from the DEVICE
epoch:

- `_tick()`/`_advanceWindow()` computed `targetCounter = (deviceNowMs ~/ 1000)
  ~/ windowSeconds` and compared `deviceNowMs` to `windowEnd * 1000`.
- `_CountdownQr._onFrame()` computed `elapsed = deviceNow - (boundaryMs -
  windowMs)`.

`get_my_code` issues window bounds (`windowStart`/`windowEnd`) on the SERVER
clock. On the Android emulator/Waydroid guest, the device clock drifted ~53–58 s
from the server:

```
[DIAG] apply ws=10 windowStart=1789008990s windowEnd=1789009000s boundaryDeltaMs=63338
```

Device UTC at that instant was `2026-09-10T02:55:36.662Z`; the server window was
`[2026-09-10T02:56:30Z, 02:56:40Z]` → the server clock was ~53–58 s AHEAD.
With `boundaryDeltaMs = 63338`, the border stayed clamped at 0 and the QR frozen
for ~63 s, then the device started rotating on `floor(deviceNow/windowSeconds)`
— a *different* lattice than the server's. `ws=10`, ticks fired exactly every 1 s,
`derive` took 14 ms → clock skew was the only cause.

## Fix

No fallbacks: everything that picks a window or drives the border now reads a
server-clock offset derived from `serverNowMs`.

### Backend — `get_my_code` returns `serverNowMs`

`060_events/07_code.sql` (and the byte-identical `supabase-testing` mirror):
added `'serverNowMs', (extract(epoch FROM now()) * 1000)::bigint` to the success
`jsonb_build_object`. `now()` is transaction-stable, so `serverNowMs` is
consistent with `counter`/`windowStart`. Gates, signature and ACLs unchanged.
`CREATE OR REPLACE` applied to the running 54382 DB (grants preserved: anon
`f`, authenticated `t`).

### Client — carry server time + offset

- `logic/code.dart`: `CodeSession.serverNowMs` (required, parsed in `fromJson`);
  `CodeFetch.serverOffsetMs` (non-ok constructors set 0);
  `CodeFetch.ok(session, serverOffsetMs)`; `fromRpc(json, serverOffsetMs)`.
- `providers/code_providers.dart`: `myCodeProvider` is now
  `AsyncNotifierProvider.autoDispose.family` with
  `AutoDisposeFamilyAsyncNotifier<CodeFetch, String>`. `build` measures the
  device clock around the RPC (`t0` before, `t1` after) and computes
  `offsetMs = session.serverNowMs - ((t0 + t1) ~/ 2)`. The midpoint only
  cancels network latency.
- `screens/attendance_code_screen.dart`: removed the `initState` post-frame
  `ref.invalidate` hack (autoDispose re-anchors on entry). The screen stores
  `_serverOffsetMs` and reads
  `_serverNowMs() = DateTime.now().millisecondsSinceEpoch + _serverOffsetMs`.
  `_tick()` recomputes `counter = (_serverNowMs() ~/ 1000) ~/ windowSeconds`
  every second (no `ref.read` dependency, no boundary tracking) so late/missed
  ticks self-correct. `_advanceTo` uses a sequence token (`++_advanceSeq`) to
  drop stale derives. `_onSessionChange` reconciles on `windowEnd`/
  `windowSeconds` change (not only code-string change). The border ring
  (`_CountdownQr`) receives `windowStartMs`, `windowSeconds`, `offsetMs` and
  computes `serverNow = deviceNow + offsetMs` per frame — border and rotation
  share one clock.

## Tests / commands

Focused only (per the 2026-08-27 directive — no full `make check`/`make test`).

- RED: added two assertions to `test/opt-027-events-code.sh` TEST A/B
  (`serverNowMs` is a number; `windowStart*1000 <= serverNowMs < windowEnd*1000`).
  `bash test/opt-027-events-code.sh` → `PASS=28 FAIL=2`.
- Applied the function to the running stack:
  `PGPASSWORD=postgres psql -h localhost -p 54382 -U postgres -d postgres
  -v ON_ERROR_STOP=1 -f <extracted create-or-replace>`.
- GREEN: `bash test/opt-027-events-code.sh` → **PASS=30 FAIL=0**.
- `flutter analyze lib` → **No issues found!** (2.7 s).
- README baseline row updated (opt-027 note, PASS 28→30).
- pgTAP §21d does NOT assert the `get_my_code` payload (only presence/ACL/FORCE
  RLS), so pgTAP and `plan(N)` were left untouched.

## MISTAKE — earlier 30 s / stale-seed misdiagnosis

A previous session attributed the frozen QR to a "stale in-memory session"
seeded with `windowSeconds=30` (instead of the current 10) and added a
post-frame `ref.invalidate` on entry to force a re-fetch. That was wrong:

- The device log shows `ws=10` (the session WAS current) — the freeze was
  `boundaryDeltaMs=63338` of pure clock skew, not a stale window length.
- The `ref.invalidate` hack papered over the symptom at best; it never fixed
  the device-epoch counter derivation underneath.

**Lesson:** when a time-windowed UI freezes or diverges, compare the DEVICE
clock to the SERVER clock before blaming the fetched config. A rotation that
uses `floor(deviceNow/window)` against server bounds is broken by design under
skew; anchor to `serverNowMs` and derive from server time only.

---

## Addendum — audit hardening H1/H2 (2026-09-09, same session)

The auditor found no defects but flagged two robustness items. No fallbacks
added; the `serverNowMs` contract is unchanged.

### H1 — deterministic SQL interval (rounding-flake fix)

`get_my_code` previously called `now()` twice: once for `v_counter`/`v_start`
(`floor(extract(epoch FROM now()) / v_window)`) and again for the returned
`serverNowMs` (`(extract(epoch FROM now()) * 1000)::bigint`). Two microsecond-
apart calls could straddle a window boundary — the second could round across it
and return a `serverNowMs` outside its own `[windowStart, windowEnd)`.

Fix (both byte-identical mirrors): capture ONE timestamp and derive everything
from it.

```sql
v_now_ms bigint := (extract(epoch FROM now()) * 1000)::bigint;
...
v_counter := (v_now_ms / 1000) / v_window;
v_start := v_counter * v_window;
...
'serverNowMs', v_now_ms
```

`windowStart*1000 <= serverNowMs < windowEnd*1000` now holds strictly by
construction. Applied with `CREATE OR REPLACE` to the running 54382 DB; ACLs
preserved (anon `f`, authenticated `t`).

### H2 — monotonic window progression (NTP-jump immunity)

The remaining risk: the offset was sampled once, then the screen kept reading
the live device wall clock (`_serverNowMs() = DateTime.now() + offset`). An
Android NTP correction mid-session shifts the device clock by the jump, which
shifts the derived counter (and the border) with it.

Fix: advance from a MONOTONIC clock after the initial server-anchored phase.
Wall clock is used only at apply to establish the phase.

- `_applySession(session, offsetMs)` computes
  `phaseMs = serverNowMs - counter * windowMs` (0..windowMs) and restarts a
  `Stopwatch` (`..reset(); ..start()`). `offsetMs` is still computed by the
  provider and carried on `CodeFetch.serverOffsetMs`; the monotonic phase does
  not depend on it.
- `_elapsedInWindowMs = phaseMs + _watch.elapsedMilliseconds`;
  `counter = session.counter + _elapsedInWindowMs ~/ windowMs`. `_tick()`
  recomputes every second from this model (no wall clock), so it still
  self-corrects late/missed ticks.
- Border ring: `_ActiveCode`/`_CountdownQr` now receive `phaseMs`,
  `windowSeconds` and the SAME `Stopwatch`; `_onFrame` computes
  `progress = ((phaseMs + watch.elapsedMilliseconds) % windowMs) / windowMs`,
  eased as before. Border and rotation share one monotonic source — no
  device-vs-server epoch mixup.
- `_onSessionChange` re-anchors when `windowEnd`, `windowSeconds` **or**
  `serverNowMs` differ, so a re-fetch re-syncs even within the same window.
- `_advanceTo` keeps the sequence-token guard but now queues the newest
  requested counter (`_pendingCounter`) instead of dropping a tick while a
  derive is in flight; after the await it processes the pending counter if it
  differs.
- Removed the now-unused `_serverNowMs()` wall-clock helper and
  `_serverOffsetMs` field. `_activationMinutes` / not-in-window logic
  untouched. No debug logging, no `print`.

### Hardening validation

- `bash test/opt-027-events-code.sh` ×2 → **PASS=30 FAIL=0** both runs
  (deterministic interval; no boundary flake).
- `dart analyze lib/features/qr` → **No issues found!**;
  `flutter analyze lib` → **No issues found!** (1.6 s).
- `make build TARGET=android` → APK built; installed to the emulator
  (`localhost:5565`, tunnel to `<build-host>`) and launched:
  `mCurrentFocus=com.qallariy.samay/.MainActivity`, pid 7828 — ready for
  tap-verification.

