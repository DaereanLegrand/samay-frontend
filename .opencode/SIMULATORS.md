# Simulators & devices — never spawn, always ask

Absolute rule for this repo: **NEVER SPAWN SIMULATORS. ASK PERMISSION BEFORE
USING THE CURRENT ONES.**

Agents must not create, boot, erase, delete, clone, or otherwise mutate iOS
simulators. They may only use a simulator the **human has explicitly approved
for the session**, and only after asking.

## What "spawn" means (all forbidden by default)

Any operation that creates or brings up a device runtime, e.g.:

- `xcrun simctl create <name> <device-type> <runtime>`
- `xcrun simctl boot …` / `bootstatus …`
- `xcrun simctl clone …` / `simctl upgrade …`
- `open -a Simulator` (launches the Simulator UI)
- the Xcode MCP `DeviceInteractionStartSession` tool (it boots a device)
- creating device definitions via Xcode, templates, or `xcrun simctl` in any form

These are **never** run, not even to "temporarily" test a build. If a task seems
to need a device that does not exist, **stop and ask**.

## What "the current ones" means (ask before use, every time)

Even a device that already exists may be in use — e.g. the developer's running
`flutter run`, the active Xcode run destination, or a booted device they are
using. So:

1. **List first** (read-only): `xcrun simctl list devices` and
   `xcrun simctl list devices booted`.
2. **Present the list and ask** which specific device(s) the session may use.
   Do not assume; do not pick one yourself.
3. Use **only** the approved UDID(s). Do not boot a shutdown device, and do not
   shut down a booted one, without asking.
4. When done, ask before leaving any device in a changed state.

Named-by-the-human devices must never be touched otherwise — for Samay's Mac
that has meant **leave `iPhone 11` and `iPhone 17 Pro` alone**.

## Allowed without asking (read-only)

- `xcrun simctl list …` (devices / devicetypes / runtimes)
- `xcrun simctl io <approved-udid> screenshot …`
- `xcrun simctl get_app_container <approved-udid> …`
- `xcrun simctl spawn <approved-udid> log show …`

## Allowed only on an approved, already-booted device — and clean up after

- `xcrun simctl install` / `launch` / `terminate` / `uninstall`
- uninstall the test build when finished (leave the device as found)

Never `simctl erase` or `simctl delete` an approved device.

## Why this matters

- **It is not yours.** A booted sim is often the human's live app/Xcode
  destination; booting one, or a second one, disrupts their session.
- **Host residue.** Builds, keychains, `DerivedData`, and app containers pile up
  and are easy to forget.
- **Irreversible.** `simctl delete`/`erase` wipe state that cannot be recovered.
- **Noise.** Extra devices change `xcrun simctl list` output, screenshots, and
  CI assumptions.

## Enforcement

- Rule-driven here (the Xcode MCP `DeviceInteraction*` tools cannot be gated by
  shell permissions — treat them as covered by this rule).
- Shell-level grants in `.opencode/opencode.json`: `simctl create|boot|
  bootstatus|shutdown|erase|delete|clone|upgrade` are **denied**.
- Standing project rule — read before any device work, alongside
  `DEV-SERVER.md` and `.opencode/README.md`.
