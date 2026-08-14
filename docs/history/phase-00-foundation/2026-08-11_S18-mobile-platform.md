# 2026-08-11 — S-18: Mobile platform hardening audit (report)

**Agent:** S-18 (Phase 4.5 — Security) · **Mode:** report-only
**Scope:** Android manifest/gradle, iOS Info.plist/signing, device
hardening, backups.

## Verified posture

| Check | Verdict | Evidence |
|---|---|---|
| Android backups | ✅ | `allowBackup="false"` (M-27) — no adb-backup exfiltration of Keystore-wrapped E2EE material |
| Android permissions (minimal) | ✅ | INTERNET + CAMERA + READ_MEDIA_IMAGES only (no location/storage/contacts); runtime-requested via permission_handler (I-28) |
| Android SDK levels | ✅ | minSdk 24 (Flutter default, covers Android 7+), compile/target = Flutter defaults — no legacy-API surface |
| Cleartext traffic | ✅ | no `usesCleartextTraffic`; dev HTTP is localhost-only (iOS ATS untouched → HTTPS enforced) |
| iOS ATS / encryption export | ✅ | no `NSAllowsArbitraryLoads`/`NSAppTransportSecurity` overrides; no `ITSAppUsesNonExemptEncryption` key — defaults apply (note: the export-compliance question must be answered at TestFlight submission — E2EE chat may trigger the "exempt" category; filing is a release-checklist item) |
| Manifest secrets | ✅ | zero keys/`google-services` in the manifest |
| Debuggable / exported | ✅ | launcher activity exported only; no `android:debuggable` in release (M-27) |

## Findings

1. **No runtime integrity checks** — no rooted/jailbreak detection, no
   `FLAG_SECURE`/iOS snapshot protection (S-01 S1.5-1). Acceptable at MVP
   (the E2EE keys live in Keychain/Keystore, which resist common extraction);
   add OS-integrity checks before the E2EE chat ships to a wide audience.
2. **No certificate pinning** (S-01 S4.2-1, S-05) — revisit when the
   production domain lands (pin the Kong cert via network-security-config /
   a pinned trust bundle).
3. iOS signing: Apple Development identity selected for sim/device builds
   (per the Xcode logs); TestFlight/App Store signing + `ITSAppUsesNonExempt
   Encryption` filing are M-17/release-checklist items.

## Verifier cross-check

Manifest/Info.plist/gradle greps · M-27 platform contract commit history ·
U-29 smoke device runs (physical iPhone + simulator).

*Samay mobile platform audit — S-18 · 2026-08-11*
