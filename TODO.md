# TODO — samay-frontend

## Facts
- Flutter app `samay` (`com.qallariy.samay`). Split from `Samay`.
- Makefile is Flutter-only; `guard-local` gates local-only releases.
- CI: `.gitea/workflows/ci.yml`. iOS `PrivacyInfo.xcprivacy` wired into the Runner target.

## TODO
- [ ] **NEXT — Staging/prod full builds.** Produce fully signed iOS + Android
      builds with **all keys wired**, run on a **Tart VM**, with signing material
      from the **vault**. `ENV=staging|prod` is wired (`build PROD=true ENV=…
      TARGET=ios|android MODE=adhoc|store`; `ENV=staging tools/release-signing-not-in-repo.sh …`).
      Remaining: provision staging (vault/Firebase), bake `tailscale` into the
      Tart base. See `<private-ops-repo>/STAGING.md`, `<private-ops-repo>/LOCAL-BUILDS.md`,
      `<private-ops-repo>/PROD-READINESS.md`, `<private-ops-repo>/KEY-ACQUISITION.md`.
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
- [ ] Add `fastlane/metadata/` store copy + screenshots.
- [ ] Comment prune (lib/, docs/).
- [x] TODO(fastlane): iOS build uses the real iOS client id when the vault
      profile carries `google-oauth-ios-client-id` (add that entry to the prod
      `qallariy/samay/public/**` to close the prod case; staging already has it).
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
