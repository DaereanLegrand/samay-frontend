# TODO — samay-frontend

## Facts
- Flutter app `samay` (`com.qallariy.samay`). Split from `Samay`.
- Makefile is Flutter-only; `guard-local` gates local-only releases.
- CI: `.gitea/workflows/ci.yml`. iOS `PrivacyInfo.xcprivacy` wired into the Runner target.

## TODO
- [ ] **NEXT — Prod full builds.** Produce fully signed iOS + Android **prod**
      builds with **all keys wired**, run on a **Tart VM**, with the signing
      material materialized from the **vault** (Apple ASC certs/profiles +
      `match` repo password; Android keystore + Play service account + FCM).
      Extends the local-only `guard-local` release flow to a clean macOS VM.
      See `<private-ops-repo>/LOCAL-BUILDS.md`, `<private-ops-repo>/PROD-READINESS.md`,
      `<private-ops-repo>/KEY-ACQUISITION.md`.
- [x] Prune cross-brand refs; `welcomeVive`→`welcomeSamay` (see <private-ops-repo>/REPO-AUDIT.md).
- [x] Per-env Android flavors (`dev`/`staging`/`prod`) + Firebase client config:
      testing committed/open, staging/prod vault-gated. Gum chooser in `make init`
      (testing/local/own). `<private-ops-repo>`.
- [ ] Prune stale the reference app references (lib/ services + docs).
- [ ] Rename stale l10n key `welcomeSamay`.
- [ ] Trim README backend/infra sections (belong to samay-backend / <private-ops-repo>).
- [ ] Add `fastlane/metadata/` store copy + screenshots.
- [ ] Comment prune (lib/, docs/).
- [ ] TODO(fastlane): prod iOS build passes the Web client id as the iOS client
      id (Makefile `TARGET=ios PROD=true`) — pass the real iOS client id.
- [ ] TODO(vault): android keystore + Play service account + FCM; Apple ASC keys
      + Gitea `match` repo password. Acquisition order:
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
