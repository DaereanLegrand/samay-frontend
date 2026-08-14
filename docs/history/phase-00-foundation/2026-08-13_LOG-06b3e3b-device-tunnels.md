# Device-Tunnel Make Wave: Waydroid/Android/iOS + TARGET=all (2026-08-13, `06b3e3b..7372bd9`)

**Agent:** R2-log-backfill (docs-remediation sweep) · **Branch:** `fixes` · **HEAD:** `7372bd9`

## What was built

11-commit wave (oldest → newest: `06b3e3b`, `aa39354`, `1c2df95`, `1985119`,
`20e02a5`, `4459ba6`, `d0840db`, `ec6af18`, `81f2f3b`, `5a96b3e`, `a75dccf`,
`7372bd9`) making the Makefile device targets behave exactly as `../Juega`:

1. **macOS device tunnels (06b3e3b):** `TARGET=waydroid|android` route through
   SSH adb tunnels (`tunnel-android` / new `tunnel-waydroid`, <build-host> host);
   non-Darwin keeps the direct waydroid status/adb path. New `clear-storage`
   target (`pm clear com.qallariy.samay`) and TARGET-aware branches for
   `test-integration` (default stays the hermetic `runner.sh`).
2. **LAN-first adb (aa39354):** tunnels prefer the LAN <build-host> when reachable.
3. **Per-target tunnel ports (1c2df95):** waydroid + android coexist on
   distinct local ports (Juega/Vive pattern).
4. **Funnel-completion gate (1985119):** incomplete accounts go to the age
   gate (auth fix riding the wave).
5. **Uninstall lifecycle (20e02a5/4459ba6/d0840db):** `uninstall` target —
   `TARGET=all` or per-device; requires a TARGET (fast-fail usage message);
   tunnels no longer kill the parent make.
6. **Sweep builds (ec6af18):** `build TARGET=all` + `install TARGET=all` sweep
   every platform/device.
7. **iOS on-device (81f2f3b, 5a96b3e):** `dev TARGET=ios-adhoc` launches the app
   on the iPhone; `dev TARGET=ios` = `flutter run` on the physical iPhone.
8. **tmux/mDNS guard (a75dccf, 7372bd9):** `dev TARGET=ios` prints the Local
   Network hint when `flutter run` fails and **warns when run inside tmux**
   (mDNS TCC block).

Makefile +87 across the wave's first commit; `test/opt-008-makefile-static.sh`
extended with the new targets + dry-run asserts.

## Decisions

- macOS routes device work through SSH adb tunnels to the <build-host> (parity with
  Juega) instead of local adb; non-Darwin keeps the direct path.
- `uninstall` without a TARGET fails fast rather than guessing.
- tmux is flagged, not blocked — the warning is the guard.

## Commands run

```bash
git log --oneline 06b3e3b..7372bd9   # 11 commits
make help                             # new cheatsheet surface
bash test/opt-008-makefile-static.sh
```

## Follow-ups

- Verify tunnel coexistence on a second <build-host> (port conflicts).
- `1985119` funnel gate needs end-to-end coverage on device.
