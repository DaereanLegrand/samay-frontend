#!/usr/bin/env bash
# =============================================================================
# pre-commit.sh — the Samay fast pre-commit gate (TOOL-04, agent M-26).
#
# Runs the FAST static gates only. The full validation matrix is CI's job
# (`make check` + `make test` — see docs/process/DEVELOPMENT-WORKFLOW.md
# §3.6); a pre-commit hook must finish in seconds, not minutes, or developers
# will bypass it. Tradeoff, documented:
#
#   FULL GATE (CI / make test)          FAST GATE (this script, pre-commit)
#   go test ./...                       (skipped — Go changes are rare and CI covers)
#   go vet / golangci-lint              (skipped)
#   supabase db test (pgTAP)            (skipped — needs the stack up)
#   bash test/run_all_backend.sh        (skipped — needs the stack up)
#
# What IS enforced here (fail-fast, exit 1 on first failure):
#   1. dart analyze          — must be 0 issues (the campaign baseline; any
#                              new issue blocks the commit)
#   2. make secrets-check    — no committed secrets (tools/check_secrets.sh)
#   3. tools/check_ports.sh --strict — no port-map violations (AGENTS.md)
#   4. bash test/opt-008-makefile-static.sh — Makefile surface resolves
#
# NOTE (directive 2026-08-31): there are NO Flutter/Dart tests in this repo —
# the test/ Dart tree and integration_test/ were deleted. Testing is reserved
# for the backend (Go + pgTAP + curl opt-tests).
#
# Lock protocol: this script deliberately does NOT take file locks. The
# semaphore (tools/agent_lock.sh) arbitrates EDITORS; a read-only gate that
# only runs checks cannot clobber another agent's work, and locking staged
# files would make every commit O(locks) slower. If a parallel agent is
# mid-edit when you commit, the analyze/test gates catch the half-written
# state — the check, not the lock, is the gate.
#
# Usage: bash tools/pre-commit.sh     (or via tools/hooks/pre-commit)
# Exit 0 = all gates pass, 1 = a gate failed (message printed).
# =============================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

step() { printf '\n\033[1m━━━ %s\033[0m\n' "$1"; }
fail() { printf '  ❌ %s\n' "$1" >&2; }

step "1/4  dart analyze (must be 0 issues)"
# --fatal-infos --fatal-warnings: bare `dart analyze` exits 0 on info/warning
# issues, so without these flags a lint violation would pass the gate.
if ! dart analyze --fatal-infos --fatal-warnings; then
  fail "dart analyze found issues — fix them before committing (M-26 gate)."
  exit 1
fi
printf '  ✅ dart analyze clean\n'

step "2/4  secrets-check (committed-secret scan)"
if ! make secrets-check; then
  fail "secrets-check FAILED — a secret pattern was found in tracked files."
  exit 1
fi
printf '  ✅ secrets-check passed\n'

step "3/4  port-map gate (tools/check_ports.sh --strict)"
if ! tools/check_ports.sh --strict >/dev/null; then
  fail "port-map violations — see tools/check_ports.sh --strict output."
  exit 1
fi
printf '  ✅ port map consistent\n'

step "4/4  Makefile surface (test/opt-008-makefile-static.sh)"
if ! bash test/opt-008-makefile-static.sh >/dev/null; then
  fail "makefile-static gate failed — see bash test/opt-008-makefile-static.sh"
  exit 1
fi
printf '  ✅ makefile surface OK\n'

printf '\n✅  All pre-commit gates passed (fast gate: %ss).\n' "$SECONDS"
exit 0
