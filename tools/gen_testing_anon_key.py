#!/usr/bin/env python3
"""Mint a temporary HS256 anon JWT for Samay's LOCAL testing stack.

Mirrors the committed anon key payload {"role":"anon","iss":"supabase",
"iat":..,"exp":..} (verified against supabase/.env 2026-08-11) but with a
fresh iat/exp (24h window) signed with the LOCAL stack's JWT_SECRET.

Secret resolution order:
  1. JWT_SECRET env var (the Makefile TESTING=true path passes it here)
  2. supabase/.env in the repo root (standalone runs)

Prints ONLY the JWT on stdout — no logs. Exit 1 with a message on stderr
if the secret cannot be resolved.
"""
from __future__ import annotations

import base64
import hashlib
import hmac
import json
import os
import sys
import time
from pathlib import Path


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _secret_from_env_file(repo_root: Path) -> str:
    env_file = repo_root / "supabase" / ".env"
    if not env_file.is_file():
        return ""
    for line in env_file.read_text().splitlines():
        if line.startswith("JWT_SECRET="):
            return line.split("=", 1)[1].strip()
    return ""


def main() -> int:
    secret = os.environ.get("JWT_SECRET", "")
    if not secret:
        secret = _secret_from_env_file(Path(__file__).resolve().parent.parent)
    if not secret:
        print(
            "gen_testing_anon_key: no JWT_SECRET found (env var or "
            "supabase/.env) — start with the local stack's secret.",
            file=sys.stderr,
        )
        return 1

    header = {"alg": "HS256", "typ": "JWT"}
    now = int(time.time())
    payload = {"role": "anon", "iss": "supabase", "iat": now, "exp": now + 24 * 3600}

    signing_input = ".".join(
        [_b64url(json.dumps(header, separators=(",", ":")).encode()), _b64url(json.dumps(payload, separators=(",", ":")).encode())]
    )
    signature = hmac.new(
        secret.encode(), signing_input.encode(), hashlib.sha256
    ).digest()
    print(f"{signing_input}.{_b64url(signature)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
