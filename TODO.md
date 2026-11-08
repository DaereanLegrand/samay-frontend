# TODO — samay-frontend

> Live cross-cutting state lives in **`<private-ops-repo>/STATUS.md`** (CURRENT STATE ·
> WIP · BACKLOG). This file is **repo-scoped only**.

## Facts
- Flutter app `samay` (`com.qallariy.samay`). Split from `Samay`.
- Makefile is Flutter-only; `guard-local` gates local-only releases.
- iOS `PrivacyInfo.xcprivacy` wired into the Runner target. CI files were
  deleted by owner decision (14-wave2-decisions §13).

## WIP — group theme dark rendition (next session: `CONTINUE TODO.md`)

Owner request: *"Make all colors darker like a 75% darker, and the 'white' would
become its color opposite."* Confirmed interpretation: **75% darkening**
(each channel x0.25) of background + accent, and the white ink becomes the
**complement** of the background, then clamped to WCAG AA.

Done and verified on device:
- `GroupThemePalette` gained `darkenAmount = 0.75`, `darken()`, `complement()`
  and `_ensureContrast()`. `derive()` now returns the darkened page
  (`#1E3A8A` -> `#080F23`) with complementary ink (`#E1C575`, 11.28:1), and the
  accent pair is the complement of the *darkened* accent (`#C0CCFA` on `#3F3305`,
  7.86:1).
- Theme editor preview + swatches now show the **painted** result (darkened),
  not the raw server hexes.
- `VDisplayText`, `VEmptyView`, member usernames and the minigames headings now
  use the themed foreground (were cool white); chat date chip and bubble
  timestamps were lifted to >= 5:1 (`mutedForeground` target raised to 5.0).
- Still green: `flutter analyze` clean, 36 tests, `make check`, `make test`.

**OPEN DEFECT (must fix first next session):** unselected `FilterChip`s still
paint **pure `#000000`** instead of transparent on the themed page — the editor's
"Solo el host" / "Bloqueado" and minigames' "Directa" (87-92% of each chip is
0,0,0; 1.10:1 vs the page, i.e. an edgeless black box). Setting both
`ChipThemeData.color` and `chip.color` via `WidgetStateProperty` (transparent
when unselected) did **not** take effect on device, so the black is coming from
somewhere else — next candidates, in order:
1. `Material`/`Chip` `surfaceTintColor`/`elevation` interaction on the
   `FilterChip` still resolving the M3 `surfaceContainerLow` default
   (check `FilterChip.surfaceTintColor` + a `Material` ancestor's
   `color`/`surfaceTintColor`);
2. `FilterChip`'s `selectedColor`/`backgroundColor` vs a `ChipTheme` inherited
   from `NavigationBar`/`SegmentedButton` overrides in `app_theme.dart`;
3. the wrapping `Material`/`Ink` under `ListTile`/`Wrap` painting its own
   surface.
Repro: `make dev TARGET=simulator ENV=testing-local`, sign in as a Pro host,
group -> Tema del grupo / Nueva partida; sample chip interiors with
`NSBitmapImageRep` (expect page `#080F23`, currently `#000000`).

Also unverified after the last build: the editor's first palette swatch is
`#000000` — that is the legitimate `#000000` palette entry (darkened black),
**not** a bug.

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
      `docs/GROUP-THEME-COLORS.md`; 21 new tests in
      `test/group_theme_palette_test.dart` + `test/group_theme_widgets_test.dart`.
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
