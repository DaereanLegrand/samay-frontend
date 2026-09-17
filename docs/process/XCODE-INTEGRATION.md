# Xcode Integration — opencode ↔ Xcode 27

How an opencode agent drives Xcode directly, in two tiers:

- **Tier 2 — Xcode MCP** (live IDE tools) via Xcode's own MCP server and the
  `xcrun mcpbridge` stdio bridge.
- **Tier 1 — CLI** (`xcodebuild` / `xcrun simctl`) via the bash tool.

Verified on: Xcode **27.0** (`27A266a`), iOS **27.0** SDK + runtime
(`24A434`), macOS 26.6.2. The iOS 26.5 runtime was removed.

---

## 0. Hard rule — never elevate

Agents **never** run `sudo`, `osascript … with administrator privileges`,
`do shell script`, or anything that prompts for admin rights. Every
privileged step below is listed as an **exact command for the human to run**.
Enforced in `.opencode/opencode.json` (`*sudo*`, `*do shell script*`,
`*administrator privileges*`, `*Authorization Services*` → `deny`).

---

## 1. Tier 2 — Xcode MCP

Xcode 27 ships the server; no third-party shim is needed.

| Binary | Role |
|---|---|
| `xcrun mcp-server` | Manages the service: `status`, `open`, `stop`, `enable`, `disable`, `approve`, `allow-folder`, `clear-permissions`, `reset-all`, `deny`, `show-logs` |
| `xcrun mcpbridge` | **stdio JSON-RPC bridge** that exposes Xcode's tools to any MCP client |
| `xcrun lldb-mcp` | LLDB debugger tools |
| `xcrun agent skills export` | Export Xcode's own agent skills |
| `xcrun agent plugin path` | Path to Xcode's packaged agent plugins |

### 1.1 opencode config

Registered globally in `~/.config/opencode/opencode.json`:

```jsonc
"mcp": {
  "xcode": {
    "type": "local",
    "command": ["xcrun", "mcpbridge"],
    "enabled": true,
    "timeout": 15000
  }
}
```

`MCP_XCODE_PID` / `MCP_XCODE_SESSION_ID` can target a specific Xcode instance.

### 1.2 Permission model — two gates + headless

| Control | Gates | Command |
|---|---|---|
| Agent approval | Which MCP client may connect | `sudo xcrun mcp-server approve <id> --always\|--for-24-hours` |
| Folder approval | Which directories are served | `sudo xcrun mcp-server allow-folder <path> --always\|--for-24-hours` |
| Headless mode | Service runs with no Xcode GUI | `sudo xcrun mcp-server enable` / `disable` |
| `unsafeAlwaysAllowAllAgents` | **Bypasses agent approval entirely** | `enable --unsafe-always-allow-all-agents` (do not use) |

Inspect state (no sudo): `xcrun mcp-server status --format json` → reports
`openWorkspaces`, `permission.enabled`, `unsafeAlwaysAllowAllAgents`, and
pending request ids.

Chosen policy for this machine: **headless by default**, agent **opencode**
approved, permitted folders **`~/Codes/apps/Juega`**, **`~/Codes/apps/tukuy`**
and **`~/Codes/apps/Vive`**.

### 1.3 Bring-up (human runs the sudo steps)

```bash
# 1. Headless mode (human, sudo)
sudo xcrun mcp-server enable

# 2. Permit the folders (human, sudo)
sudo xcrun mcp-server allow-folder /Users/daerean/Codes/apps/Juega --always
sudo xcrun mcp-server allow-folder /Users/daerean/Codes/apps/tukuy --always

# 3. Agent approval is NOT granted on connect. The first workspace-touching
#    call must be XcodeOpenWorkspace (or XcodeNewProject); that is what asks.
#    Then either approve the GUI prompt, or approve by the *pending agent id*:
xcrun mcp-server status --format json    # look at pendingAgentApprovals[].id
sudo xcrun mcp-server approve <pending-agent-id> --always
```

Approval semantics (verified):

- `pendingAgentApprovals[].id` is the **agent** approval id.
  `permittedFolders[].id` is a **folder** id — passing it to `approve` fails
  with `no approval request with id …`. Folders are already granted; do not
  approve them again.
- Approval happens **once per agent identity** (`opencode`, keyed by the shell
  trust hash), not per workspace.
- Approving the GUI prompt needs **no sudo**; the CLI `approve` path does.
- Until approved, every tool call returns *"This agent isn't approved to use
  Xcode's tools yet"* and tells you to call `XcodeOpenWorkspace` first.

Verify from opencode: `opencode mcp list` → `xcode … connected`, then use the
`xcode_*` tools. Verified working call: `XcodeListWorkspaces` →
`workspace-yiUCHjDZ4N`.

The bridge exposes **54 tools**, including `BuildProject`, `RunProject`,
`GetBuildLog`, `RunAllTests`, `RenderPreview`,
`XcodeRead`/`XcodeWrite`/`XcodeGlob`/`XcodeGrep`, and the
`DeviceInteraction*` simulator tools.

> Config is loaded once at startup and is **not hot-reloaded** — quit and
> restart opencode after changing `opencode.json`.

---

## 2. Tier 1 — CLI runbook (Flutter iOS)

App scheme: **Runner** · workspace: `ios/Runner.xcworkspace`. Host app bundle
id comes from `ios/Runner.xcodeproj` build settings.

```bash
# Resolve Flutter deps + pods first (raw xcodebuild does not)
flutter pub get
(cd ios && pod install)

# Build for the iOS 27 simulator
xcodebuild -workspace ios/Runner.xcworkspace \
  -scheme Runner -configuration Debug \
  -sdk iphonesimulator27.0 \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  build

# Diagnostics
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -showBuildSettings

# Run in a simulator
xcrun simctl boot "iPhone 18 Pro"
open -a Simulator
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
xcrun simctl launch --console-pty booted <bundle-id>

# Logs
xcrun simctl spawn booted log stream --predicate 'processImagePath CONTAINS "Runner"'
```

Prefer `flutter build ios --simulator` when you only need the `.app`; it
wraps the build settings and pod setup correctly.

iOS 27 devices available: iPhone 18 Pro / Pro Max, iPhone 17e, iPhone Air,
iPhone 17, plus iPads (`xcrun simctl list devices available`).

---

## 3. Guardrails

- **Never kill or restart `make dev`** and never hot-reload the human's running
  Flutter session (`.opencode/DEV-SERVER.md`).
- Do not use Xcode **run/launch** tools against a simulator the human's dev
  session already owns — coordinate first.
- Xcode's MCP tool set is large and adds context cost; if it gets noisy,
  disable globally with `"tools": { "xcode*": false }` and opt in per agent.
- No admin/privileged commands from agents — hand them to the human.
