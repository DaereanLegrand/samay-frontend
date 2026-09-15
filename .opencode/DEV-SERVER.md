# Dev server — never kill `make dev`

The developer runs `make dev` (and similar long-lived dev servers) in this
repo. It must stay alive for the whole session.

- **Never kill, stop, or restart** `make dev` or any running dev server.
- Do **not** run `kill`, `killall`, `pkill`, `kill -9`, `fuser -k`, or any
  equivalent — including killing by PID or `pkill -f`.
- Do not start a second `make dev` to "take over" a port; if a run looks stuck,
  ask the human to restart it.
- Enforced at the config level in `.opencode/opencode.json`:
  `pkill*` and `kill*` are denied.
