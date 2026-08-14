# Phase 14 — Alpha & Beta Launch · PLAN

> Compiled by D-12 (2026-08-09) from `docs/specs/steps/phase-14-alpha-beta-launch/*`
> and `docs/specs/steps/cross-references.md`. Read-only planning aid — this phase
> is the integration gate; no I-49..I-78 agent starts feature work here directly.

## Summary

This phase is a **gate, not a feature sprint**: integrate and validate all
Alpha-scope features (ATST), prepare store listings + legal documents (PLAT),
execute Alpha testing (TEST), wire RevenueCat as Alpha infrastructure (RSDK), then
run Beta Phase 1 (BTA1) and Phase 2 (BTA2) expansions, and finally launch + metrics
(BLNC). Everything in this phase is blocked by phases 05–13.

Key points (from specs):
- Alpha scope = auth, profiles, friends, groups, events (all 3 types), static
  invite QR, dynamic attendance QR, shard distribution, ledgers, group ranks
  (GRCK), push (invite/starting/shards), social feed, photos + collage, admin CLI,
  privacy/ToS screens, report flow. **Explicitly excluded at Alpha:** mini-games,
  Party Finder, video souvenir, subscriptions/payments (all users run free-tier),
  featured events, preshard purchases, cosmetics shops.
- Alpha success criteria: zero critical data-integrity bugs (shard balance always
  correct; QR not double-scannable — `SELECT FOR UPDATE`), core loop completable
  by a non-technical tester (15-step loop in ATST spec), no crashes on iPhone 13 +
  Samsung Galaxy A54.
- Beta Phase 1 = mini-games, Party Finder, PRO subscriptions, smallest preshard
  pack, 3–5 cosmetics, group cosmetics voting, video souvenir, feed posting,
  featured events. Phase 2 = VIP tier, full cosmetics catalog, self-serve
  promotion, paid events via Promotor Portal (Culqi, 5% fee), shard expiry (if
  economy data justifies), notification preferences, analytics.
- Beta success metrics (BLNC): 500+ users / 60 days, 50+ events, ≥30% event
  re-attendance, ≥10 paid transactions, <1% crash rate, 100% shard distribution
  accuracy; PostHog funnels + retention cohorts; economy monitoring (inflation,
  exploit detection).
- RSDK: `purchases_flutter` already in `pubspec.yaml`; configure in `main.dart`;
  sandbox products (pro_monthly/annual, vip_monthly/annual, preshards_small);
  webhook pipeline tested in sandbox; hidden `/debug/revenuecat` route, NOT shipped
  to Alpha testers.
- PLAT: Privacy Policy + ToS live URLs (placeholder domains only — no invented
  URLs), App Store Connect + Play Console setup, 17+/Mature rating, privacy labels,
  data safety form, TestFlight + Firebase App Distribution, deep-link config
  (apple-app-site-association / assetlinks.json).

## Steps & dependency status (cross-references.md, verified 2026-08-09)

| Step | Direct deps | Dep status | Step status |
|------|-------------|------------|-------------|
| `ATST` | ALL Alpha-scope steps (integration gate) | massively red | ❌ Blocked by phases 05–13 gaps |
| `RSDK` | `FLUT`✅, `INFR`✅, `RCBH`❌ | 2/3 green | ❌ Blocked by `RCBH` |
| `PLAT` | `ATST`❌ | — | ❌ |
| `TEST` | `ATST`❌, `PLAT`❌ | — | ❌ |
| `BTA1` | `ATST`, `GMCR`, `GWAG`, `PFND`, `PLAN`, `PPAC`, `MPGR`, `COSM`, `GCOS`, `VIDS`, `MUSC`, `FEET`, `SOVR` (all ❌) | — | ❌ |
| `BTA2` | `BTA1`❌ | — | ❌ (paid events basic flow in-app = BTA2; full `PORT` = Phase 15) |
| `BLNC` | `BTA2`❌ | — | ❌ |

## Orchestration agents contributing (indirect — foundations only)

| Agent | Contribution |
|-------|--------------|
| I-61 | Paywall foundation (RevenueCat placeholder) — RSDK-compatible |
| I-66 | Deep-link handler (invite links, notification routing — PLAT deep-link config depends on it) |
| I-68 | Telemetry service (PostHog placeholder) — BLNC funnel/metrics pre-req |
| I-70 | Crash reporting service (Sentry placeholder) — BLNC crash-rate metric |
| I-75 | Dev seed/demo data scripts (TEST: reproducible tester data) |
| I-77/I-78 | pgTAP expansion + full-matrix sweep (ATST gate validation) |
| I-41 | `cmd/samay-api-server` Gin scaffold — BTA2/BLNC `DASH` pre-req (Phase 15) |

The launch itself (store listings, TestFlight/Firebase, sandbox webhooks, Arequipa
tester recruitment, metrics dashboards) is operator/orchestrator work, not
I-49..I-78 code work.

## Acceptance checklist (from the step specs)

**ATST (`ATST-alpha-integration.md`):**
- [ ] Every Alpha-scope bullet in the spec is done and integration-tested (31 items listed there)
- [ ] Alpha exclusions honored (no purchase UI, no mini-games/Party Finder/video in the Alpha build)
- [ ] Zero critical data-integrity bugs (QR double-scan test, shard balance invariants)
- [ ] Core 15-step loop (create account → … → rank update) completable by non-technical tester
- [ ] No crashes on iPhone 13 + Samsung Galaxy A54 on core flows

**RSDK (`RSDK-revenuecat-sdk-wiring.md`):**
- [ ] SDK initialized in `main.dart` (API key from env, not hardcoded); NO user-facing purchase UI at Alpha
- [ ] Products configured in RevenueCat + stores (sandbox): pro_monthly/annual, vip_monthly/annual, preshards_small
- [ ] Webhook pipeline tested in sandbox → tier update in sandbox DB; idempotency verified; `getCustomerInfo()` fallback verified
- [ ] Hidden `/debug/revenuecat` dev route; excluded from Alpha distributions

**PLAT (`PLAT-app-store-play-store-prep.md`):**
- [ ] Privacy Policy + ToS URLs live (placeholders allowed per DEPLOYMENT-PLACEHOLDER.md) and linked in-app
- [ ] App Store Connect: listing "Samay — Social Events", 17+ Mature w/ content descriptors, privacy labels, TestFlight internal testers, first build uploaded
- [ ] Google Play: listing "Samay — Eventos Sociales", Mature rating, Data Safety Form, Firebase App Distribution, first APK/AAB, Android App Links configured
- [ ] Deep-link config: `apple-app-site-association` + `assetlinks.json` on the (placeholder) domain

**TEST (`TEST-alpha-testing.md`):**
- [ ] 11 test-plan sections executed (installation/auth → admin CLI), incl. the full event loop with preshard pool (500 pool, 3 friends, scan, distribution, ledger checks)
- [ ] QR edge cases (expired token, double-scan, pre-window) verified
- [ ] Target devices covered (iPhone 13/15, Galaxy A54, Pixel 6); bug tracking with priority tiers

**BTA1 (`BTA1-beta-phase-1.md`):**
- [ ] All 14 scoped items (GMCR, GWAG, PFND, PLAN+PRO, RCBH, SOVR, PPAC smallest pack, MPGR, COSM 3–5 items, GCOS voting, VIDS, MUSC, feed posting PRO, FEET)
- [ ] Release tracks live: TestFlight public link / full release; Play open testing
- [ ] Milestone: subscriptions working with real payments (sandbox → production cutover)

**BTA2 (`BTA2-beta-phase-2.md`):**
- [ ] VIP tier + annual plans; full cosmetics catalog (20+)
- [ ] Self-serve promotion (in-app form + one-click admin approval via DASH)
- [ ] Paid events (PORT + Culqi, 5% fee, ticket QR, refunds, revenue tracking)
- [ ] Shard expiry only if Phase 1 economy data justifies (phased rollout + advance notice)
- [ ] Notification preferences screen (per-category toggles → `users.notification_preferences`)
- [ ] PostHog analytics fully wired (funnels, cohorts)

**BLNC (`BLNC-beta-launch-metrics.md`):**
- [ ] PostHog key events + funnels + retention cohorts instrumented
- [ ] Economy monitoring dashboard (circulation vs earned = inflation, avg per event, per user, donations/day)
- [ ] Exploit detection (accumulation rates, bot scanning, fraud patterns)
- [ ] Moderation workflow running (daily report queue)
- [ ] Weekly metrics vs targets: 500 users/60d, 50 events, ≥30% re-attendance, ≥10 paid, <1% crashes, 100% distribution accuracy

## Phase exit gate

BTA2 green in cross-references.md; stores live (Alpha via TestFlight/Firebase,
Beta open testing); sandbox→production payments cut over; metrics dashboard
collecting; full matrix green.
