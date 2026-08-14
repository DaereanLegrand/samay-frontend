# Phase 13 — Party Finder & Video Souvenir · PLAN

> Compiled by D-12 (2026-08-09) from `docs/specs/steps/phase-13-party-finder-video/*`
> and `docs/specs/steps/cross-references.md`. Read-only planning aid for I-49..I-78.

## Summary

Build Party Finder (opt-in discovery by interest tags, sorted by mutual friends)
and the Video Souvenir (PRO/VIP on-device slideshow generation from event photos +
a bundled royalty-free music library).

Key mechanics (from specs):
- **PFND:** predefined interest tags (8 music, 7 activities, 6 vibes — listed
  verbatim in the spec); multi-select chips on profile (`tags_editor.dart`);
  opt-in toggle in privacy settings (default OFF; OFF users invisible but can
  still browse). Match list rows: avatar, display_name, @username, shared
  interests count, mutual friends count; sorted by mutual friends DESC then shared
  interests DESC. No swiping, no scoring. Match card actions: "Enviar mensaje"
  (direct chat via CHPT lookup/create — auto-intro message), "Ver perfil",
  "Bloquear" (never appears again), "Reportar usuario".
- **VIDS:** PRO/VIP only (free → upsell). Select 3–20 photos from PHUP gallery
  (drag to reorder), pick a music track, preview (first 5 s), generate via
  `ffmpeg_kit_flutter` (3 s per photo, cross-fade, audio overlay, MP4 in temp dir).
  Performance floor check before generation; failure message ("No se pudo crear el
  video. Intenta con menos fotos."). Export to gallery + share; watermark.
- **MUSC:** 8–12 CC0/royalty-free instrumental tracks, 30–90 s, stored in
  `assets/music/`, registered in `pubspec.yaml`, metadata in `tracks.json`
  (id/name/genre/duration_secs/bpm); playback preview with `audioplayers` or
  `just_audio`.
- On-device generation performance on low-end Android is an accepted risk to
  validate in Beta (spec §13).

## Steps & dependency status (cross-references.md, verified 2026-08-09)

| Step | Direct deps | Dep status | Step status |
|------|-------------|------------|-------------|
| `PFND` | `FRND`✅, `PRFL`⚠️, `CHAT`❌, `AUTH`⚠️, `DSNG`✅ | 2/5 green | ❌ No code (`/party-finder` = coming-soon; interest tags deferred from PRFL) |
| `VIDS` | `PHUP`❌, `FLUT`✅, `DSNG`✅ | 2/3 green | ❌ No code |
| `MUSC` | `VIDS`❌ | 0/1 green | ❌ No `assets/music/` |

## Orchestration agents starting here

| Agent | Scope (per ORCHESTRATION.md / FILE-OWNERSHIP.md) |
|-------|--------------------------------------------------|
| I-60 | `lib/features/party_finder/party_finder_screen.dart` (foundation) — ✅ **DONE 2026-08-09**: PFND foundation landed (see `2026-08-09_I60-party-finder.md`): migration `20260809000004` (`users.interest_tags` + `users.discovery_opt_in` + `discovery_view` security barrier, pgTAP §43), `UserService.findMatches/getDiscoveryOptIn/setDiscoveryOptIn/getMyInterestTags`, `party_finder_providers.dart` (opt-in + matches), `party_finder_screen.dart` (opt-in toggle + match cards + block), route `/party-finder` flag-gated (`partyFinder`, still dark by default). CHAT dep (`Enviar mensaje` → direct chat) NOT wired — deferred to I-56/I-38 per PLAN. |
| I-56/I-38 | Chat screen + E2EE (direct chat from PFND match cards depends on CHAT) |
| I-59 | Photo gallery (VIDS photo selection source) |
| I-49/I-50/I-51 | Feature flags / repositories / typed REST client |
| I-66 | Deep-link handler (chat/profile navigation) |
| I-74 | Shared state widgets |
| I-78 | Full-matrix sweep |

Music curation (MUSC) needs asset licensing work — no I-agent owns
`assets/music/`; flag to orchestrator (licensing/S-14 compliance review applies).

## Acceptance checklist (from the step specs)

**PFND (`PFND-party-finder.md`):**
- [x] `tags_editor.dart`: predefined tag list per spec; multi-select chips; displayed on own profile — **I-36 foundation** (`lib/features/profile/interests.dart`: catalog + `UserInterests` + `InterestTagPicker`); profile-screen persistence path still unwired (blocked on `users.interest_tags` — **column now exists, migration 20260809000004**; wiring the picker into edit-profile save = follow-up)
- [x] Opt-in toggle in privacy settings (default OFF); OFF = not discoverable — **I-60**: `users.discovery_opt_in` (default false), toggle on the party-finder screen (privacy-settings entry point = follow-up, reuse `discoveryOptInProvider`)
- [x] Match list: avatar, display_name, @username, shared interests count, mutual friends count; sorted (mutual friends DESC, then shared DESC); optional tag filter; scrollable list (no swipe) — **I-60 foundation**: avatar + @username + shared-interests count + tag chips, sorted by shared-tag count DESC (service-side); mutual-friends count + tag filter deferred (need FRND count query — see I-60 log)
- [ ] Match detail card: enlarged avatar, bio excerpt, shared tags highlighted, mutual friends avatars, "Enviar mensaje" / "Ver perfil" / "Bloquear" — tap → public profile + "Bloquear" (reuses blockUser) landed; full detail card + chat action deferred (CHAT dep ❌)
- [ ] Direct chat from match: CHPT lookup → existing or new; auto-intro "{user} te envió un mensaje desde Party Finder" — deferred (CHAT dep ❌, I-56/I-38)
- [x] Safety: block from card — **I-60** ("Bloquear" per card → friendships block → never appears again); "Reportar usuario" (reports, target_type=user) + 18+ verification remain (age gate is at signup — AUTH ✅)

**VIDS (`VIDS-video-souvenir.md`):**
- [ ] Access check (pro/vip) + upsell for free
- [ ] Photo multi-select (3–20, checkmark overlay, drag reorder) from PHUP gallery
- [ ] Music selection row (name, genre, duration, play/pause preview)
- [ ] Preview ("Previsualizar" → first 5 s) and Generate ("Creando tu video souvenir..." progress)
- [ ] Client-side ffmpeg: images + audio → MP4 (3 s/photo), temp output
- [ ] Performance floor check dialog; failure message; export to gallery + share; watermark

**MUSC (`MUSC-music-library.md`):**
- [ ] 8–12 curated royalty-free instrumental tracks (CC0 or license-safe), 30–90 s
- [ ] Bundled in `assets/music/`, registered in `pubspec.yaml`, `tracks.json` metadata
- [ ] Playback/preview UI in selector (stops on selection/navigation)

## Phase exit gate

All 3 steps green in cross-references.md; PFND privacy default verified OFF;
video generation works on target devices (iPhone 13, Galaxy A54) or fails
gracefully; music licensing documented; full matrix green.
