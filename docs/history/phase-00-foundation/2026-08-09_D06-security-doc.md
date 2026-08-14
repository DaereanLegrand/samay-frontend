# D-06 — Security Architecture & Threat Model (`docs/security/SECURITY.md`)

## Date: 2026-08-09

## What was built

- `docs/security/SECURITY.md` (new directory `docs/security/`) — the app's security architecture and threat model document:
  1. **Threat model** — 8 assets (identity, E2EE keys, shard balances, PII/UGC, session tokens, admin credentials, 3rd-party secrets, audit trail), 6 actors (anon → insider admin), STRIDE table mapped to concrete Samay components with status, mitigation and owning agent per row.
  2. **Security architecture** — RLS + FORCE RLS (verified status: enabled on `signup_tracker` only, 1/31 tables), SECURITY DEFINER `search_path` inventory (12 functions, 11 unhardened), JWT/PKCE/session handling, E2EE (references `docs/security/E2EE-ARCHITECTURE.md` as planned, D-07), storage buckets + signed URLs, input sanitization, rate limiting (GoTrue/Kong/app_config), secrets management, network transport.
  3. **Cryptography policy** — approved: X25519, AES-256-GCM, HKDF-SHA256, Ed25519; NOT allowed: MD5/SHA-1 integrity, ECB, RC4/DES/3DES, RSA<2048, hardcoded keys, custom crypto, nonce reuse; key lifecycle (generation → flutter_secure_storage → rotation → wipe on account delete) per Signal X3DH/Double Ratchet.
  4. **Compliance** — Peru Ley 29733 (Ley de Protección de Datos Personales), App Store 5.1.1(v)/Play data-deletion, UGC reporting; account-deletion flow mapped end-to-end to code files with line numbers.
  5. **Incident response + CVE monitoring** — NVD, OSV, pub.dev advisories, GitHub advisories, Go vuln DB; S-02 runs the initial scan; triage SLA + response runbook.
  6. **Known gaps table** — 23 gaps (G-01..G-23) each with owner agent IDs (FORCE RLS → I-31, token refresh → I-30, OTP rate limiting → I-29, permission_handler → I-28, input sanitization → I-27, .env → I-34/M-13, E2EE → I-37/I-38, Kong rate limit → M-09/S-10, storage → S-09, etc.).
  7. **Verification ledger** — every "current status" claim carries file:line evidence from the working tree.

## Decisions made and why

- **Evidence-first writing:** every status claim in the doc was verified against the actual migrations/code before writing (see verification ledger section of the doc). No claim from the old to-fix docs was carried over without re-checking (several had drifted — e.g. `handle_signup` was dropped, signup_tracker is now fixed but pgTAP still asserts the old policies).
- **Owners embedded:** each gap row names the owning agent(s) so I-31/I-30/I-32/S-* agents can pick up directly.
- **No secrets in the doc:** the leaked anon key from `.env.example` is described but never repeated.
- Daily log placed under `docs/history/phase-00-foundation/` following the D-02/D-05 convention in this campaign.

## Sources consulted (all cited inside the doc)

- OWASP MASVS: https://mas.owasp.org/MASVS/ · MASTG: https://mas.owasp.org/MASTG/
- OWASP API Security Top 10 2023: https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- Signal X3DH: https://signal.org/docs/specifications/x3dh/ · Double Ratchet: https://signal.org/docs/specifications/doubleratchet/
- Supabase RLS: https://supabase.com/docs/guides/database/postgres/row-level-security · securing data: https://supabase.com/docs/guides/database/secure-data
- PostgreSQL RLS (FORCE): https://www.postgresql.org/docs/current/ddl-rowsecurity.html · CREATE FUNCTION: https://www.postgresql.org/docs/current/sql-createfunction.html
- NIST SP 800-63B: https://pages.nist.gov/800-63-3/sp800-63b.html · SP 800-124r2: https://csrc.nist.gov/pubs/sp/800/124/r2/final
- NVD: https://nvd.nist.gov/ · OSV: https://osv.dev/ · pub.dev advisories: https://dart.dev/tools/pub/security-advisories · GitHub advisories: https://github.com/advisories · Go vuln: https://vuln.go.dev/

## Commands run (reproducibility)

```bash
git log --oneline -10 && git status
find lib test supabase cmd internal tools -type f | sort
rg -c "ENABLE ROW LEVEL SECURITY" supabase/migrations/*.sql
rg -n "FORCE ROW LEVEL SECURITY|FORCE RLS" supabase/
rg -n "SECURITY DEFINER|SET search_path" supabase/migrations/
rg -n "refreshSession|AuthFlowType|pkce|permission_handler|sentry|cached_network" lib/
rg -n "TextEditingController|TextFormField|TextField\(" lib/ --include="*.dart"
git show b02090e --stat
tools/agent_lock.sh acquire docs/security/SECURITY.md --owner D-06
tools/agent_lock.sh acquire docs/history/phase-00-foundation/2026-08-09_D06-security-doc.md --owner D-06
```

## Lock evidence

- `docs/security/SECURITY.md` — acquired `[lock] ACQUIRED 'docs/security/SECURITY.md' by D-06` (2026-08-09T05:23:25Z)
- `docs/history/phase-00-foundation/2026-08-09_D06-security-doc.md` — acquired by D-06
- Both released after write (see release commands).

## Issues found (reported, not fixed — out of scope)

1. **G-03 (new finding):** `users_update_own` RLS policy (full_schema.sql:611-612) permits clients to UPDATE *every* column of their own row, including `personal_shards`, `preshards`, `subscription_tier`, `banned_at` — mass-assignment/self-elevation vector (API3:2023). Not documented anywhere else; assigned I-32/S-03.
2. **G-16:** `supabase/docker-compose.yml:13` (5432) and `:44` (54321) still conflict with Juega's ports despite AGENTS.md map (54382/54386); `supabase/run.sh:17` echoes 54321. I-02/M-01..M-05/M-10 scope.
3. **G-17:** `supabase/tests/schema_test.sql:170-177` asserts the pre-fix wide-open signup_tracker policies (stale since 20260724000001); D-04 owns.
4. `.env.example:5` still carries a real publishable anon key (H-21); `.env` still a Flutter asset (M-31) — I-34/M-13/S-08 scope.
5. `go.mod:3` still declares `go 1.26.2` (future version) although TODO C-08 is marked done — verify with I-42/CLI owners.

## Validation

- All claims cross-checked against working tree (evidence ledger in the doc §7).
- No code changed; no tests affected. `dart analyze`/`flutter test`/`go test` untouched (docs-only agent).
