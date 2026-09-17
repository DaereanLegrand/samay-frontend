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

## Never trigger a reload yourself — always ask the human

The running dev session (`make dev` / `flutter run`) is the human's. Do **not**
try to hot reload or hot restart it by ANY means — including:

- writing keys to its terminal (`printf 'r' > /dev/ttysNNN`, `write`,
  `kitten @ ...`, AppleScript / System Events keystrokes);
- attaching a second client (`flutter attach`, `flutter run` on the same
  device, DevTools reload);
- installing or launching a build over the running one.

When a reload is needed to see a UI change, **ask the human to press `r`
(hot reload) or `R` (hot restart) in the dev terminal**, then continue.
Enforced at the config level in `.opencode/opencode.json`: TTY-writing and
`flutter attach` patterns are denied.
