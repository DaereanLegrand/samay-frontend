# TODO — samay-frontend

> Live cross-cutting state lives in **`<private-ops-repo>/STATUS.md`** (CURRENT STATE ·
> WIP · BACKLOG). This file is **repo-scoped only**.

## Facts
- Flutter app `samay` (`com.qallariy.samay`). Split from `Samay`.
- Makefile is Flutter-only; `guard-local` gates local-only releases.
- iOS `PrivacyInfo.xcprivacy` wired into the Runner target. CI files were
  deleted by owner decision (14-wave2-decisions §13).

## WIP — group theme completion

Owner request (this session): make the group theme consistent everywhere the
group surface reaches — group detail itself, the donate action, and the
minigame headers/screens — plus breathing room between the group description
and the action row.

Done (verified: `flutter analyze` clean, `flutter test` 30/30, `make check`,
`make test`):

- `GroupThemeSurface` / `groupThemeTheme`
  (`lib/features/groups/theme/group_theme_theme.dart`): one entry point that
  mounts the `GroupThemeScope` AND a re-mapped `ThemeData`. Root cause of the
  old black-chip defect: `Chip` wraps itself in a colourless `Material` that
  falls back to `Theme.canvasColor` (black) — no chip colour property could
  fix it; `canvasColor: transparent` does.
- `GroupDetailScreen` is now a themed surface: page, banner identity strip,
  shard/member inks, header menu, action row, events section, and the
  loading/error/invited states. `_actionRow` gained the requested top pad.
- Donate is an **overlay** on group detail (`showDonateToGroupDialog`, centered
  themed dialog over a dimmed barrier) — the `/group/:id/donate` route and
  `DonateShardsScreen` are deleted.
- Minigames: `MinigameHeaderTitle` uses the themed display voice (hub header no
  longer hardcodes white); `MinigameSessionSurface` themes the partida lobby,
  every play screen and the finished leaderboard for group sessions
  (`MinigameInks.of(context)` for local inks). Direct partidas are unchanged.
- `RankBadge` is theme-aware; `GroupEventsSection` rows/dividers use the
  palette.
- Tests: `test/group_theme_widgets_test.dart` removed (UI-level tests are not
  kept per `frontend/AGENTS.md`); `test/app_theme_test.dart` keeps
  the derivation math, the presets and the group-follows-app rule.

Open: on-device verification of the new surfaces (group detail, donate overlay
with the keyboard up, minigame hub/lobby/play) after a hot restart.

## WIP — app-wide theme (paywall-ready)

Owner request: theming for the REST of the app, paid in the future. Groups keep
their own theme EXCEPT when a group is still on the default, in which case it
follows the app-wide theme.

Done (verified: `flutter analyze` clean, `flutter test` 30/30, `make check`,
`make test`; on device the Feed + a default-theme group paint `#080F23` with
`#E1C575` ink):

- Palette/scope generalised: `GroupThemePalette`→`AppPalette` and
  `GroupThemeScope`→`AppThemeScope` now live in `lib/core/theme/`; every
  identical-reference check became `AppThemeScope.isThemed(context)` (value
  comparison), so a computed app palette counts as themed.
- `AppThemePreset` (7 presets: classic, midnight, forest, violet, ember, teal,
  rose) with `tierRequirement` as the paywall seam; `classic` IS the design
  tokens, so an unset app paints byte-identically to before.
- `appThemePresetProvider` persists the choice in the encrypted `config_cache`
  (`theme.palette`) and reconciles it when the tier changes;
  `appPaletteProvider` resolves the painted palette (gated, fail-safe).
- `SamayApp.builder` mounts `AppThemeScope` + `themedData` for every route;
  `themedData` moved to `lib/core/theme/themed_data.dart` and grew the
  app/segmented/card/switch/checkbox/tab/date/bottom-sheet roles.
- Migrated ~100 files to `context.palette.*` (shared widgets + every screen), so
  the app theme actually reaches the UI instead of only Material defaults.
- Settings → Apariencia → "Color de la app" opens `AppThemeScreen` with 7
  preview cards; locked presets show "Requiere Pro"/"Requiere VIP".
- Groups: `isDefaultGroupTheme` + `groupSurfacePalette` implement the owner
  rule; `GroupThemeSurface`/`MinigameSessionSurface` inherit the app theme for
  default groups and override for custom ones.
- l10n es/en for the new copy.

Verified on device (Pro account, iPhone 18 Pro): Feed paints Bosque `#05150B`;
the group "Cowboy Bebopers" (no `group_themes` row) inherits the same green;
"Noche de Cracks" (custom `#1E3A8A`) keeps its navy override; the unselected
minigame "Directa" chip matches its page colour (never `#000000`); the picker
locks Turquesa/Rosa as "Requiere VIP".

Open: the paywall is client-side only (tier comes from `users.subscription_tier`);
when the store ships, gate the picker + enforce server-side. No backend change
yet.

## TODO
- [x] **Wave 1B consolidated** (tag `wave1b-base`): l10n key union + regenerate,
      identity/moderation/event-link screens; analyze/tests green.
- [x] **Wave 2 E4 client:** server-tier paywall (IAP only in dev), collage
      top-N, `entitlementTier` removed, in-app password reset screen/route,
      code-only match join UI, shadow-block profile + generic blocked-chat
      error. `flutter analyze` clean, `flutter test` 7/7.
- [x] Group theme colour scheme: derived `GroupThemePalette` (surface/
      surfaceAlt/muted/hairline/border solved to WCAG AA from the server's four
      colours) + `GroupThemeScope`; applied to chat bubbles/date band/composer,
      member rows, minigame cards/chips/buttons and the theme editor. Contract:
      `docs/GROUP-THEME-COLORS.md`; derivation + themed-`ThemeData` tests in
      `test/app_theme_test.dart`.
- [x] Group theme client (E4 remainder): `GroupTheme` model + repository/
      service/provider, theme editor (preview, control mode for the host,
      tier palette, localized errors) reachable from the group menu; the
      server-derived background is applied to group chat, the member list and
      group minigames. Contract fixture validated in `test/contracts_test.dart`;
      `flutter analyze` clean, `flutter test` 7/7.
- [x] E5 verifier: `make check` and `make test` green (the static gate now
      probes `guard-env` with an explicit empty ENV, so an inherited ENV from
      `make test` cannot mask the unset case).
- [x] Chat moderation UI + legal links (store compliance):
      - Long-press a chat message → **Reportar mensaje** (reason dialog →
        `report_message` RPC carrying the DECRYPTED text of that one message)
        and **Bloquear usuario** (peer messages; the block is now enforced
        server-side for direct chats).
      - Legal documents wired to `https://samay.qallariy.lat/privacy.html` /
        `/terms.html` (`lib/core/config/legal_links.dart`): open-in-browser
        action on the signup consent rows and the Settings → Privacidad screen;
        `url_launcher` dependency; l10n es/en (`chatReportMessage`,
        `chatBlockUser`, `legalOpenOnline`).
- [x] **Staging Open Testing (host Mac build).** Signed iOS + Android →
      **TestFlight external** + **Play `beta`** with vault keys; IAP dark (no
      `RC=true`). Staging backend up; store consoles done (age rating 18+
      override, App Privacy, DSA trader, availability Peru, export compliance).
      **Android**: `TRACK=beta` **approved — Play Open Testing live**.
      **iOS**: build `1.0.0 (4)` **approved — TestFlight external + public URL
      live** (`External Test Group`; internal group **`Internal Test Group`**).
      One build per version can be in review at a time. Subsequent builds:
      `TESTFLIGHT_EXTERNAL_GROUPS="External Test Group" make deploy TARGET=ios ENV=staging TRACK=external`.
      Remaining store items: Play developer name (H10) and Play App Signing
      SHA-1 copy (H8). See `<private-ops-repo>/STATUS.md` (WIP) and
      `<private-ops-repo>/STAGING.md`.
- [x] iOS build passes the **real iOS client id** (`google-oauth-ios-client-id`)
      to `GIDClientID` + `GOOGLE_OAUTH_IOS_CLIENT_ID` (falls back to the Web id
      only for legacy profiles lacking it).
- [~] RevenueCat IAP: `main.dart` configures + `logIn`/`logOut` on auth;
      per-platform public keys (`…_APPLE`/`…_GOOGLE`) + Test Store key, opt-in
      `RC=true` (app-build profile); stub mode without them; `subscriptions` flag
      auto-on with a key. Remaining (owner): RC projects + store credentials +
      products + webhook + vault keys; Test Store/sandbox validation (release
      sandbox needs the store commercial setup). See
      `<private-ops-repo>/REVENUECAT-TODO.md` / `REVENUECAT.md`.
- [x] Event capacity UI reads `subscriptionTier` (entitlement_tier dropped in
      migration `225_subscription_refactor`).
- [x] Prune cross-brand refs; `welcomeVive`→`welcomeSamay` (see <private-ops-repo>/REPO-AUDIT.md).
- [x] Per-env Android flavors (`dev`/`staging`/`prod`) + Firebase client config:
      testing committed/open, staging/prod vault-gated. Gum chooser in `make init`
      (testing/local/own). `<private-ops-repo>`.
- [ ] Prune stale the reference app references (lib/ services + docs).
- [ ] Rename stale l10n key `welcomeSamay`.
- [ ] Trim README backend/infra sections (belong to samay-backend / <private-ops-repo>).
- [x] Add `fastlane/metadata/` store copy + screenshots — iOS/Android copy
      (`en-US`, `es-419`), Play `icon.png` (512), `featureGraphic.png`
      (1024×500), `phoneScreenshots/`, and `fastlane/screenshots/es-419/`
      (iPhone 6.9" login/signup/forgot + iPad 13" login).
- [ ] Comment prune (lib/, docs/).
- [x] TODO(fastlane): iOS build uses the real iOS client id when the vault
      profile carries `google-oauth-ios-client-id` (add that entry to the prod
      `qallariy/samay/public/**` to close the prod case; staging already has it).
- [ ] TODO(vault): android keystore + Play service account + FCM; Apple ASC keys.
      Acquisition order:
      `<private-ops-repo>/KEY-ACQUISITION.md`.
- [x] TODO(frontend): testing OAuth — **Google Sign In/Sign Up wired and verified**
      end-to-end (native id-token; `GOOGLE_OAUTH_CLIENT_ID` +
      `GOOGLE_OAUTH_IOS_CLIENT_ID` via `.env`; iOS `GIDClientID` + reversed URL
      scheme committed in `Info.plist`). New OAuth users enter the onboarding
      funnel (age gate → privacy terms → profile setup, **OTP skipped**). See
      `docs/history/phase-16/2026-10-09_oauth-signup-onboarding.md`.
- [x] TODO(frontend): testing **Apple Sign In / Sign Up** — enabled. GoTrue's
      Apple provider is live on the testing stack secretlessly: the native
      `signInWithIdToken` grant validates the token audience against the
      client-id list (App ID/bundle id) and never constructs the Apple provider,
      so no Services ID / ES256 JWT / vault entries are needed (those are only
      for the web flow). The app flow (`signInWithApple`, iOS/macOS button,
      `com.apple.developer.applesignin` entitlement) was already wired and reuses
      the OAuth onboarding funnel. See
      `docs/history/phase-16/2026-10-09_apple-signin-testing.md`.
- [x] TODO(frontend): testing Google backend secret — **none required**. GoTrue's
      `id_token` grant validates the id-token audience against the client-id list
      and never uses the client secret (`token_oidc.go`), so testing stays
      public-config-only. Remaining testing backend secrets (`qallariy/samay/testing/**`)
      are for the hosted stack, not the app.
