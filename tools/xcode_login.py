#!/usr/bin/env python3
"""Samay — MCP-driven simulator login helper.

Focuses the login screen's EMAIL field and injects the account address through
Xcode's ``DeviceInteraction`` MCP tools. This exists because the macOS host ->
iOS Simulator keyboard path never delivers ``@`` to the device area (typing
works fine in a normal Mac text box), so an email cannot be typed by hand.
Only the email is injected: the password (``tester123``) contains no ``@`` and
is typed manually, then Sign in is tapped manually.

Interaction-only: it never builds / installs / launches the app, and it never
touches a running ``make dev`` session beyond activating the app for the
capture. It refuses to act unless the login screen is on screen.

Usage (usually via ``make login TARGET=simulator [DEVICE="iPhone 11"]``):

    python3 tools/xcode_login.py --target simulator
    python3 tools/xcode_login.py --target simulator --device "iPhone 11"
    python3 tools/xcode_login.py --target simulator --dry-run

Env overrides:
    LOGIN_EMAIL       override the address injected (else device-mapped)
    LOGIN_BUNDLE_ID   app bundle id to activate (default com.qallariy.samay)
    LOGIN_POINT       "x,y" manual email-field point (skips hierarchy parsing)
    LOGIN_WORKSPACE   workspace path used for the Xcode approval call
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import threading
import time
import uuid

DEFAULT_BUNDLE_ID = "com.qallariy.samay"
EMAIL_IPHONE_11 = "tester4@tester.com"
EMAIL_DEFAULT = "tester3@tester.com"
WORKSPACE_REL = os.path.join("ios", "Runner.xcworkspace")

AGENT_NAME = "samay-login"


def _approval_help() -> str:
    agent_id = _agent_request_id(AGENT_NAME)
    id_line = (
        f"     sudo xcrun mcp-server approve {agent_id} --always"
        if agent_id
        else "     sudo xcrun mcp-server approve <id> --always   # id: see status"
    )
    return f"""\
❌  This script's MCP client ({AGENT_NAME}) isn't approved by Xcode yet.

Xcode approval is per agent identity and must be granted once. Headless Xcode
does not show a GUI prompt, so approve it from the CLI (needs sudo):

  {id_line}

  (Check the request yourself: xcrun mcp-server status --format json →
   permission.pendingAgentApprovals / deniedAgentApprovals.)

Then re-run `make login ...`. To reset and be prompted again instead:
  sudo xcrun mcp-server clear-permissions   # also clears opencode/folders
"""

# Login-screen text-field indicators, matched case-insensitively anywhere in a
# node's label/value/identifier.
_EMAIL_HINTS = ("email", "correo", "e-mail")


# ─────────────────────────────────────────────────────────────────────────────
# device selection
# ─────────────────────────────────────────────────────────────────────────────
def _run(cmd: list[str], **kw) -> str:
    proc = subprocess.run(cmd, capture_output=True, text=True, **kw)
    return proc.stdout.strip()


def list_booted() -> list[tuple[str, str]]:
    """Booted simulators as (name, udid) — newest runtime first is irrelevant."""
    out = _run(["xcrun", "simctl", "list", "devices", "booted", "-j"])
    try:
        data = json.loads(out or "{}")
    except json.JSONDecodeError:
        return []
    devices: list[tuple[str, str]] = []
    for runtime_devices in data.get("devices", {}).values():
        for d in runtime_devices:
            name = d.get("name", "")
            udid = d.get("udid", "")
            if name and udid:
                devices.append((name, udid))
    return devices


def resolve_device(requested: str, booted: list[tuple[str, str]]) -> tuple[str, str]:
    """Return (name, udid) for the chosen booted simulator."""
    if not booted:
        sys.exit("❌  No booted simulator. Boot one (run the app) and retry.")

    if requested:
        matches = [
            (n, u)
            for (n, u) in booted
            if requested.lower() in n.lower() or requested.lower() == u.lower()
        ]
        if not matches:
            sys.exit(
                f"❌  Device '{requested}' is not a booted simulator. "
                f"Booted: {', '.join(n for n, _ in booted)}"
            )
        return matches[0]

    if len(booted) == 1:
        return booted[0]

    names = [n for n, _ in booted]
    try:
        picked = subprocess.run(
            ["gum", "choose", "--header", "Pick a simulator:"],
            input="\n".join(names),
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
    except (FileNotFoundError, subprocess.CalledProcessError):
        sys.exit(
            "❌  Multiple booted simulators — pass DEVICE=\"<name>\". "
            f"Booted: {', '.join(names)}"
        )
    for n, u in booted:
        if n == picked:
            return n, u
    sys.exit(f"❌  Selection '{picked}' did not match a booted simulator.")


def email_for(device_name: str) -> str:
    return EMAIL_IPHONE_11 if "iPhone 11" in device_name else EMAIL_DEFAULT


# ─────────────────────────────────────────────────────────────────────────────
# MCP client (stdio JSON-RPC to `xcrun mcpbridge`)
# ─────────────────────────────────────────────────────────────────────────────
class MCP:
    def __init__(self) -> None:
        try:
            self.proc = subprocess.Popen(
                ["xcrun", "mcpbridge"],
                stdin=subprocess.PIPE,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                text=True,
                bufsize=1,
            )
        except FileNotFoundError:
            sys.exit("❌  xcrun not found — Xcode command line tools are required.")
        self._responses: dict[int, dict] = {}
        self._lock = threading.Lock()
        self._next_id = 0
        threading.Thread(target=self._reader, daemon=True).start()
        self._initialize()

    def _reader(self) -> None:
        for line in self.proc.stdout:  # type: ignore[union-attr]
            line = line.strip()
            if not line:
                continue
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(message, dict) and "id" in message:
                with self._lock:
                    self._responses[message["id"]] = message

    def _send(self, obj: dict) -> None:
        self.proc.stdin.write(json.dumps(obj) + "\n")  # type: ignore[union-attr]
        self.proc.stdin.flush()  # type: ignore[union-attr]

    def _rpc(self, method: str, params: dict, timeout: float) -> dict:
        self._next_id += 1
        request_id = self._next_id
        self._send(
            {"jsonrpc": "2.0", "id": request_id, "method": method, "params": params}
        )
        deadline = time.time() + timeout
        while time.time() < deadline:
            time.sleep(0.05)
            with self._lock:
                if request_id in self._responses:
                    return self._responses.pop(request_id)
        raise RuntimeError(f"MCP timeout after {timeout:.0f}s on {method}")

    def _initialize(self) -> None:
        self._rpc(
            "initialize",
            {
                "protocolVersion": "2024-11-05",
                "capabilities": {},
                "clientInfo": {"name": "samay-login", "version": "1.0"},
            },
            timeout=20,
        )
        self._send({"jsonrpc": "2.0", "method": "notifications/initialized"})

    def call_tool(self, name: str, arguments: dict, timeout: float = 120) -> dict:
        response = self._rpc(
            "tools/call", {"name": name, "arguments": arguments}, timeout
        )
        if "error" in response:
            raise RuntimeError(f"{name}: {response['error']}")
        return response.get("result", {})

    def close(self) -> None:
        try:
            self.proc.terminate()  # type: ignore[union-attr]
        except Exception:
            pass


def tool_text(result: dict) -> str:
    parts: list[str] = []
    for item in result.get("content", []) or []:
        if isinstance(item, dict) and item.get("type") == "text":
            parts.append(str(item.get("text", "")))
        elif isinstance(item, str):
            parts.append(item)
    return "\n".join(parts)


def parse_tool(result: dict) -> object | None:
    """Parse a tool result's text; raise on an MCP error envelope."""
    text = tool_text(result)
    try:
        parsed = json.loads(text)
    except json.JSONDecodeError:
        return None
    if isinstance(parsed, dict) and parsed.get("type") == "error":
        raise RuntimeError(str(parsed.get("data") or parsed))
    return parsed


# ─────────────────────────────────────────────────────────────────────────────
# hierarchy parsing
# ─────────────────────────────────────────────────────────────────────────────
def _walk_strings(node: object) -> list[str]:
    out: list[str] = []
    if isinstance(node, str):
        out.append(node)
    elif isinstance(node, dict):
        for v in node.values():
            out.extend(_walk_strings(v))
    elif isinstance(node, list):
        for v in node:
            out.extend(_walk_strings(v))
    return out


_POINT_RE = re.compile(
    r"hitPoint:\s*\{\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*\}"
)
_LABEL_RE = re.compile(r"label:\s*'([^']*)'")


def _load_hierarchy(capture_data: object) -> str | None:
    """Read the captured hierarchy text from the result's `hierarchyPath`."""
    if not isinstance(capture_data, dict):
        return None
    candidate = capture_data.get("hierarchyPath")
    if not candidate:
        data = capture_data.get("data")
        if isinstance(data, dict):
            candidate = data.get("hierarchyPath")
    if isinstance(candidate, str) and os.path.isfile(candidate):
        with open(candidate, encoding="utf-8") as handle:
            return handle.read()
    return None


def _text_fields(hierarchy: str) -> list[tuple[tuple[float, float], str]]:
    """[(hitPoint, label)] for every TextField line in the hierarchy text."""
    fields: list[tuple[tuple[float, float], str]] = []
    for line in hierarchy.splitlines():
        if "TextField" not in line:
            continue
        point = _POINT_RE.search(line)
        if not point:
            continue
        label = _LABEL_RE.search(line)
        fields.append(
            (
                (float(point.group(1)), float(point.group(2))),
                label.group(1) if label else "",
            )
        )
    return fields


def find_email_field(hierarchy: str) -> tuple[tuple[float, float], str] | None:
    """The email TextField (matched by label), guarded to the login screen.

    Returns None when the screen has no text fields, or has fields but does not
    look like the login screen (no sign-in / password affordance)."""
    fields = _text_fields(hierarchy)
    if not fields:
        return None
    for point, label in fields:
        if any(hint in label.lower() for hint in _EMAIL_HINTS):
            return point, label
    low = hierarchy.lower()
    if (
        "iniciar sesión" in low
        or "sign in" in low
        or "contraseña" in low
        or "password" in low
    ):
        return fields[0]
    return None



def encode_email(email: str) -> str:
    """Escape non-simple characters as \\u{XXXX} (notably '@' = \\u{0040})."""
    out = []
    for ch in email:
        if ch.isalnum() or ch in "._-":
            out.append(ch)
        else:
            out.append(f"\\u{{{ord(ch):04X}}}")
    return "".join(out)


def workspace_path() -> str:
    override = os.environ.get("LOGIN_WORKSPACE")
    if override:
        return os.path.realpath(override)
    here = os.path.dirname(os.path.abspath(__file__))
    return os.path.realpath(os.path.join(here, "..", WORKSPACE_REL))


def _looks_unapproved(text: str) -> bool:
    low = (text or "").lower()
    return (
        "isn't approved" in low
        or "is not approved" in low
        or "not approved to use" in low
    )


def _agent_request_id(name: str) -> str | None:
    """The pending/denied approval id for this MCP agent name, if present."""
    try:
        out = _run(["xcrun", "mcp-server", "status", "--format", "json"])
        data = json.loads(out or "{}")
    except Exception:  # noqa: BLE001
        return None
    permission = data.get("permission", {}) or {}
    for key in ("pendingAgentApprovals", "deniedAgentApprovals"):
        for entry in permission.get(key, []) or []:
            agent = (entry.get("subject", {}) or {}).get("agent", {}) or {}
            inner = agent.get("_0", {}) if isinstance(agent, dict) else {}
            if inner.get("name") == name:
                return entry.get("id")
    return None


def ensure_approved(mcp: "MCP", workspace: str) -> None:
    """Trigger Xcode's per-agent approval prompt (the official no-sudo path).

    The first workspace-touching call is what asks the user to approve this
    agent for the folder; re-opening the already-open workspace is idempotent.
    """
    if not os.path.exists(workspace):
        print(f"⚠️  Workspace not found at {workspace}; skipping the approval call.")
        return
    print("▸  Requesting Xcode access (click Allow if Xcode prompts)…")
    try:
        result = mcp.call_tool("XcodeOpenWorkspace", {"path": workspace}, timeout=300)
    except Exception as exc:  # noqa: BLE001
        if _looks_unapproved(str(exc)):
            sys.exit(_approval_help())
        print(f"⚠️  XcodeOpenWorkspace failed ({exc}); continuing.")
        return
    if result.get("isError") or _looks_unapproved(tool_text(result)):
        sys.exit(_approval_help())


# ─────────────────────────────────────────────────────────────────────────────
# main
# ─────────────────────────────────────────────────────────────────────────────
def main() -> int:
    parser = argparse.ArgumentParser(description="MCP simulator login helper")
    parser.add_argument("--target", default="simulator")
    parser.add_argument("--device", default="")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    if args.target != "simulator":
        sys.exit("❌  make login only supports TARGET=simulator.")

    booted = list_booted()
    name, udid = resolve_device(args.device, booted)
    email = os.environ.get("LOGIN_EMAIL") or email_for(name)
    bundle_id = os.environ.get("LOGIN_BUNDLE_ID", DEFAULT_BUNDLE_ID)
    manual_point = os.environ.get("LOGIN_POINT", "")

    print(f"▸  Simulator: {name} ({udid})")
    print(f"▸  Account:   {email}")

    mcp = MCP()
    session_key = None
    try:
        ensure_approved(mcp, workspace_path())
        session_id = f"Samay Login {name} {uuid.uuid4().hex[:8]}"
        start = None
        for attempt in range(2):
            try:
                start = mcp.call_tool(
                    "DeviceInteractionStartSession",
                    {"deviceIdentifier": udid, "sessionIdentifier": session_id},
                )
                start_data = parse_tool(start)
                break
            except RuntimeError as exc:
                stuck = re.search(r"with key '([^']+)'", str(exc))
                if attempt == 0 and stuck:
                    print(f"⚠️  Releasing a stuck session ({stuck.group(1)})…")
                    try:
                        mcp.call_tool(
                            "DeviceInteractionEndSession",
                            {"interactionSessionKey": stuck.group(1)},
                        )
                    except Exception:  # noqa: BLE001
                        pass
                    session_id = f"Samay Login {name} {uuid.uuid4().hex[:8]}"
                    continue
                raise
        if start is None:
            raise RuntimeError("could not start a device session")
        session_key = (
            start_data.get("interactionSessionKey")
            if isinstance(start_data, dict)
            else None
        )
        if not session_key:
            session_key = next(
                (
                    s
                    for s in _walk_strings(start_data)
                    if len(s) == 36 and s.count("-") == 4
                ),
                None,
            )
        if not session_key:
            raise RuntimeError(f"no interactionSessionKey in: {tool_text(start)[:600]}")

        capture = mcp.call_tool(
            "DeviceInteractionSynthesize",
            {"interactSessionKey": session_key, "activationBundleId": bundle_id},
        )
        capture_data = parse_tool(capture)

        if manual_point:
            x_str, _, y_str = manual_point.partition(",")
            point = (float(x_str), float(y_str))
            label = "manual LOGIN_POINT"
        else:
            hierarchy = _load_hierarchy(capture_data)
            if hierarchy is None:
                raise RuntimeError(
                    "could not locate the UI hierarchy in the capture result. "
                    f"Raw result:\n{tool_text(capture)[:2000]}"
                )
            found = find_email_field(hierarchy)
            if not found:
                print("⏭  Not on the login screen (no email field found) — no action.")
                return 1
            point, label = found

        command = (
            f"t {round(point[0])} {round(point[1])} "
            f"sender keyboard kbd {encode_email(email)}"
        )
        print(f"▸  Email field: {label} @ ({round(point[0])}, {round(point[1])})")
        print(f"▸  Command: {command}")

        if args.dry_run:
            print("✓  Dry run — nothing injected. Now type the password and Sign in.")
            return 0

        mcp.call_tool(
            "DeviceInteractionSynthesize",
            {
                "interactSessionKey": session_key,
                "activationBundleId": bundle_id,
                "interactionCommand": command,
            },
        )
        # Confirmation capture (best-effort).
        try:
            mcp.call_tool(
                "DeviceInteractionSynthesize",
                {"interactSessionKey": session_key, "activationBundleId": bundle_id},
            )
        except Exception:
            pass

        print("✓  Email injected. Type the password (tester123) and tap Sign in.")
        return 0
    except Exception as exc:  # noqa: BLE001 - surface a clean message
        if _looks_unapproved(str(exc)):
            print(_approval_help())
        else:
            print(f"❌  {exc}")
        return 1
    finally:
        if session_key:
            try:
                mcp.call_tool(
                    "DeviceInteractionEndSession",
                    {"interactionSessionKey": session_key},
                )
            except Exception:
                pass
        mcp.close()


if __name__ == "__main__":
    raise SystemExit(main())
