# ox-alpha-build — Makefile: guest gateway URLs + init targets; Mailpit→base merge

Date: 2026-08-22

## What

1. **TARGET=android gateway fix (Linux):** `FLUTTER_DEFINES` now appends
   `--dart-define=SUPABASE_URL=http://10.0.2.2:54386` for `TARGET=android` on
   Linux hosts (`ANDROID_GATEWAY_HOST` var; macOS keeps 127.0.0.1). Reason: the
   AVD's wlan-hairpin path to the host LAN IP intermittently drops SYNs
   (errno-110 timeouts against a fully healthy stack — 237 ms pings vs 1–7 ms
   via 10.0.2.2). dart-define beats `--dart-define-from-file=.env`.
   The TESTING lane now emits the same variable, so duplicate flags are always
   identical, never conflicting.
2. **Waydroid preflight** (`waydroid-preflight` define): direct (non-Darwin)
   waydroid lanes in dev/install/clear-storage fail fast with actionable
   messages when the CLI is missing / container not RUNNING / no session IP.
   uninstall keeps its soft-skip semantics.
3. **`make supabase-init`** — start prod stack non-destructively + apply all
   migrations + seed (fresh-volume bootstrap after a manual wipe).
4. **`make supabase-testing-init`** — same for the testing stack. Mailpit
   included.
5. **Mailpit merged into the testing BASE compose** (user directive: cohesion):
   service + auth `depends_on: mailpit: service_started` now live in
   `supabase-testing/docker-compose.yml`; overlay `docker-compose.mailpit.yml`
   DELETED; init target back to plain `docker compose up`. Rationale:
   overlay-only services are invisible to plain `down -v` → the container
   survived teardown and pinned the project network ("resource still in use").
   opt-007 §9 parity allowlist updated accordingly.

## Collateral repairs (gate-green restoration)

- Stack `.env`s had been overwritten by copies of root `.env` (user action):
  lost port-map keys + EMPTY `SUPABASE_SERVICE_ROLE_KEY`. Restored from the
  opt-test baked defaults (§8.4.3 alignment) + approved port map +
  `AUTH_RATE_LIMIT_EMAIL_SENT=2`, and added `JWT_SECRET=` (compose default) to
  both — which also fixed the `TESTING=true needs JWT_SECRET` parse error as a
  side effect.
- `supabase-testing/{migrate,reset}.sh`: added `-v ON_ERROR_STOP=1` to match
  prod scripts (opt-007 §9.4 semantic-drift failures); seed-dev lines left
  matching prod exactly (no flag) per byte-parity.
- opt-007 gate retargeted: MAILPIT var → base file, parse combos without the
  deleted overlay, §10.4 asserts base wiring + "mailpit NOT in prod base",
  §9.6 allowlist gains runtime `volumes/storage` entries, header comments +
  SELFHOSTING.md §1/§2.6/usage block updated with dated note.
- opt-008: ios/macos `Package.resolved missing` failures are PRE-EXISTING
  platform-contract gaps — out of scope this session (explicit user call).

## MISTAKE (searchable)

- **Edit-tool substring match:** replacing oldString `  rest:` matched inside
  storage's `      rest:` depends_on entry, corrupting the YAML (orphaned
  keys, parse failure). Fix: anchor edits with a UNIQUE multi-line context
  (`rest:` + its following `container_name:` line), never a bare shallow-key
  line that can substring-match a deeper-indented block.
- **agent_lock self-deadlock:** re-acquiring a lock I still held (earlier task,
  never released) made `acquire` poll until timeout. Release locks at task end,
  every time.

## Commands (reproducibility)

```
make -n supabase-testing-init OVERRIDES="-f docker-compose.yml"
make define-env TARGET=android            # → ...SUPABASE_URL=http://10.0.2.2:54386
bash test/opt-007-compose-static.sh       # ✅ All compose static checks passed.
bash test/opt-005-seed-dev-static.sh      # ✅
bash test/opt-008-makefile-static.sh      # only 2 pre-existing Package.resolved ❌
tools/check_ports.sh --strict             # STRICT PASS
```
