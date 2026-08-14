# Phase 12 — Monetization & Subscriptions · PLAN

> Compiled by D-12 (2026-08-09) from `docs/specs/steps/phase-12-monetization-subscriptions/*`
> and `docs/specs/steps/cross-references.md`. Read-only planning aid for I-49..I-78.

## Summary

Build monetization on RevenueCat (abstracts StoreKit 2 / Play Billing): the
subscription paywall (transparent tier table — App Store compliance), preshard
pack purchases, the RevenueCat webhook handler Edge Function (idempotent, with
client-side fallback polling), the admin subscription-override system (reconciler
Edge Function), and the monthly preshard grants.

Key mechanics (from specs):
- Pricing from `app_config` (seeded): `subs.pro_monthly_price_pen` 1999,
  `subs.vip_monthly_price_pen` 4999, annual = 10× monthly (2 months free). Display
  prices come from RevenueCat products (`Purchases.getProducts`) — never hardcode.
- All tiers visible to all users; contextual upsells are UI-copy only; PRO screen
  shows VIP upsell card.
- `revenuecat-webhook` Edge Function: INITIAL_PURCHASE/RENEWAL/PRODUCT_CHANGE →
  set tier + expires; CANCELLATION → record intent only; EXPIRATION → free tier +
  override check. Idempotency via `processed_webhooks` (table exists).
- Override precedence: **RevenueCat always wins**; `subscription_overrides` rows
  stay active once RevenueCat expires; `override-reconciler` runs every 15 min
  (cron + triggered after webhook). CLI `samay subs override/revoke` already
  implemented (SUBS ✅) and warns on RevenueCat conflicts.
- Preshards CAN ONLY go to event pools (firewall enforced in app logic).
- Monthly grants: free 10 / pro 1,000 / vip 10,000 (`economy.preshards_*_monthly`),
  granted on renewal; annual users get monthly × 12; free tier also granted.
- Beta scope (BTA1): PRO only, smallest preshard pack, 3–5 cosmetics.

## Steps & dependency status (cross-references.md, verified 2026-08-09)

| Step | Direct deps | Dep status | Step status |
|------|-------------|------------|-------------|
| `PLAN` | `AUTH`⚠️, `SBAS`✅, `DSNG`✅, `RCBH`❌ | 3/4 green | 🔄 Foundation (I-61, 2026-08-09): paywall screen + RevenueCat stub service behind the flag; full PLAN still needs RSDK purchase flows + contextual upsells |
| `RCBH` | `DATA`✅, `INFR`✅ | 2/2 green | ❌ No code (no Edge Functions) |
| `SOVR` | `DATA`✅, `RCBH`❌, `SUBS`✅ | 2/3 green | ❌ No code (CLI side done; reconciler absent) |
| `PPAC` | `PLAN`❌, `AUTH`⚠️, `RCBH`❌ | 1/3 green | ❌ No code |
| `MPGR` | `DATA`✅, `RCBH`❌, `CRON`✅ | 2/3 green | ❌ No code |

## Orchestration agents starting here

| Agent | Scope (per **docs/process/DEVELOPMENT-WORKFLOW.md** / FILE-OWNERSHIP.md) |
|-------|--------------------------------------------------|
| I-61 | ✅ DONE 2026-08-09 — `lib/features/subscriptions/paywall_screen.dart` (RevenueCat placeholder foundation: tier table from `app_config` prices, current-tier badge, stub-mode disabled buttons, `/subscriptions` route behind the flag) + `lib/core/services/revenuecat_service.dart` (stub/configured seam) + `purchases_flutter ^10.8.0` re-added; evidence: `2026-08-09_I61-paywall.md` |
| I-49/I-50/I-51 | Feature flags (paywall behind flag — Alpha ships without purchase UI per RSDK), repositories, typed REST client |
| I-71 | Config refresh + Hive cache wiring (tier limits read from `app_config`) |
| I-77 | pgTAP expansion (subscription_overrides, processed_webhooks invariants) |
| I-78 | Full-matrix sweep |

No dedicated I-agent for the RevenueCat Edge Functions (`revenuecat-webhook`,
`override-reconciler`, `monthly-preshard-grant`) in the 4.2 list — flag to the
orchestrator (these are RCBH/SOVR/MPGR core). RSDK (Phase 14) owns the SDK wiring
for Alpha; I-61 provides the foundation screen.

**I-61 follow-ups (documented in the I-61 daily log):**
- RCBH (`revenuecat-webhook` Edge Function) + the client-side `getCustomerInfo()`
  fallback sync are **server-side/future** — until they land,
  `users.subscription_tier` is never populated into the auth state, so the
  paywall's current-tier badge reads `user['subscription_tier']` (absent →
  'free'); `UserService.getUserProfile` also does not select
  `subscription_tier` (pre-existing gap → I-71/RCBH).
- RSDK (Phase 14) wires `Purchases.configure` in `main.dart` + the store
  products; the I-61 service is seam-ready (`RevenueCatDriver`).
- Keystore-type credentials for the stores are out of scope (placeholders).

## Acceptance checklist (from the step specs)

**PLAN (`PLAN-subscription-plans-paywall.md`):**
- [x] Subscription screen: full Free/PRO/VIP comparison (events/day, max groups, members, monthly preshards, feed posting, video souvenir, group cosmetics, rank tier) with "Actual" badge — **I-61 foundation (2026-08-09):** `paywall_screen.dart` renders the 8-row table + monthly/annual rows from `app_config` `subs.*_price_pen` (PEN-formatted, never hardcoded); current-tier badge; flag-gated at `/subscriptions`; purchase buttons disabled + "Próximamente" tooltip in RevenueCat stub mode (service seam `revenuecat_service.dart` + `purchases_flutter ^10.8.0` re-added)
- [ ] Annual option showing monthly equivalent ("{annual/12}/mes ahorrando 17%") — ✅ rendered (I-61); RSDK product prices will replace `app_config` prices at Alpha
- [ ] RevenueCat init in `main.dart`; products fetched; purchase/restore flows; prices from RevenueCat not hardcoded — 🔄 stub seam shipped (I-61); real init/products → RSDK (Phase 14); purchase/restore wired to the seam and disabled in stub mode
- [ ] Contextual upsells: event limit, post limit, video souvenir, member limit (each w/ "Ver planes"); dismissible; full pricing always visible — future (ECRT/EDET surfaces)
- [ ] PRO → VIP upsell card on PRO management screen — future (PRO management screen)

**RCBH (`RCBH-revenuecat-webhook-handler.md`):**
- [ ] `revenuecat-webhook` Edge Function w/ shared-secret auth; event handling per switch (incl. CANCELLATION = no tier change, EXPIRATION = free + override check)
- [ ] Idempotency via `processed_webhooks`; error handling (audit log, HTTP 200 on non-retryable, failed-event retry queue)
- [ ] Client fallback: `Purchases.getCustomerInfo()` sync on open/foreground (SBAS)

**SOVR (`SOVR-subscription-override-system.md`):**
- [ ] `override-reconciler` every 15 min: find active overrides, RevenueCat-active → override inactive (skip), no active sub → apply tier/expiry; expired overrides → free + audit log
- [ ] CLI integration verified (override/revoke + RevenueCat conflict warning)
- [ ] Display: "Acceso {tier} por cortesía de Samay hasta {expires_at}" on subscription screen

**PPAC (`PPAC-preshard-packs-purchase.md`):**
- [ ] Preshard store screen: pack cards (amount, price, Comprar), context text ("Los preshards se usan para crear eventos con recompensas..."), monthly-sub comparison
- [ ] Purchase flow: `Purchases.purchasePackage` → webhook/client verification → `users.preshards += amount` + `preshard_ledger` (purchased, reference = transaction id) → success animation; error handling
- [ ] Restrictions enforced: preshards never usable for cosmetics/donations/wagers

**MPGR (`MPGR-monthly-preshard-grants.md`):**
- [ ] Grant on RENEWAL: read tier → map amount from config → credit + `preshard_ledger` (subscription_grant) + notify
- [ ] Annual handling: monthly rate × 12, granted at renewal
- [ ] Free tier monthly grant (10) on billing-cycle date
- [ ] Edge cases: mid-cycle upgrade = full amount on tier change; downgrade → next grant at new amount; cancel → grants stop at EXPIRATION

## Phase exit gate

All 5 steps green in cross-references.md; sandbox purchase round-trip verified
(webhook → tier update → ledger); override reconciler behavior tested; no
preshard→personal_shard conversion paths; full matrix green.
