# 2026-08-09 — I-51: Typed RestClient envelope (refactorability — TST-08)

**Agent:** I-51 (typed PostgREST envelope) · **Role:** `lib/core/services/rest_client.dart`
**Campaign:** Samay 180-agent orchestration, phase 4.2 (+30 refactorability agents)

## What was built

1. **`lib/core/services/rest_client.dart` (new)** — `RestClient`, a thin typed
   envelope over `SupabaseClient`:
   - `list<T>(table, {fromJson, select, filters, order, ascending, limit})` →
     `Future<List<T>>`; builds `select(...)` → parameterized filter chain →
     `order(...)` → `limit(...)`, mapping every row through the caller-supplied
     `fromJson` factory.
   - `maybeSingle<T>(...)` → `Future<T?>` (PostgREST `maybeSingle` semantics:
     null when no row matches), `single<T>(...)` → `Future<T>` (`PGRST116`
     propagates as a `PostgrestException` on empty).
   - `insert(table, row)`, `update(table, idColumn, id, patch)`,
     `delete(table, idColumn, id)` — writes are row-scoped by an explicit id
     column + value, so no unfiltered update/delete is possible through the
     wrapper.
   - `typedef RestFilter = ({String column, String op, Object? value})` — the
     mission's `Filter` record, prefixed `Rest` to stay unambiguous (documented
     deviation). Supported ops: `eq/neq/gt/gte/lt/lte/like/ilike/in`; unknown
     ops throw `ArgumentError`.
   - `restClientProvider` (Riverpod) watching the canonical
     `supabaseClientProvider` seam — tests override either provider with a
     mock/fake client.
   - **C-04 doctrine by construction:** filters are forwarded exclusively as
     typed arguments to the chain methods (`eq/ilike/inFilter/...`) — zero
     string interpolation ever reaches a query string. The envelope is
     injection-safe even if a future caller passes attacker-controlled filter
     values (SEC-02 → locked: "parameterized everywhere via RestClient going
     forward").

2. **Proof migration #1 — `lib/core/services/config_service.dart`** →
   `fetchAppConfig` now goes through `rest.list('app_config', ...)`.
   Public API identical (`ConfigService(client: ...)`, same method shapes);
   the `client` field stays for the auth accessor / legacy call sites.
   `getSignupShardGrant` unchanged (its 256-fallback logic is intact).

3. **Proof migration #2 — `lib/core/services/notification_service.dart`** →
   `getNotifications` via `rest.list` (user_id eq filter, `created_at` desc,
   limit 50), `markNotificationRead` via `rest.update`. Public API identical;
   realtime delegation untouched. (Composed with I-53's in-flight notification
   center work — see Concurrency.)

4. **`test/services/rest_client_test.dart` (new, 15 tests)** — mocktail + the
   shared network-free `ResolvingBuilder` (I-44):
   - list builds the exact filter chain in order (eq/ilike/gt/in asserted as
     `RecordedFilter`s — the C-04 parameterized shapes), order+ascending+limit
     via a local `_OrderAwareBuilder` that records the transform stage, and
     `fromJson` mapping proven with the real freezed `NotificationItem.fromJson`
     (created_at DateTime parse + defaults).
   - maybeSingle null/row, single row + error propagation.
   - insert/update/delete table + row + id-scoped filter assertions, with
     PostgrestException propagation (`captureError` + real `error_mapper`
     mapping asserted).
   - unknown-op → ArgumentError; `restClientProvider` resolves over an
     overridden `supabaseClientProvider`.

## Migration path (documented for future agents)

Other services keep their `client.from(...)` chains for now. Per service the
migration is mechanical:
`client.from(t).select(c).eq(x, v).order(o).limit(n)` →
`rest.list<T>(t, fromJson: T.fromJson, select: c, filters: [(column: x, op: 'eq', value: v)], order: o, limit: n)`.
Writes: `.update(p)/.delete().eq(id, v)` → `rest.update/delete(t, 'id', v, p)`.
Keep the service's `client` field (auth accessor, facade, legacy call sites)
until the STOP-100 facade deletion. Multi-hop queries (`.or()`, joins, RPC,
storage, realtime) stay on `client` — the envelope covers single-table CRUD.

## MISTAKE blocks

- **MISTAKE (Dart list identity):** asserting `filters` list-equality with a
  `RecordedFilter('id', ['u1','u2'])` value fails — Dart `List ==` is identity,
  so two equal-looking list values never match, and the matcher's `equals` on
  a `List<RecordedFilter>` also uses `==` per element. **Fix:** assert scalar
  filters with `RecordedFilter` equality and the `in` filter as
  `column` + element-wise `expect(value, ['u1','u2'])` matcher.
- **MISTAKE (analyzer):** `_OrderAwareBuilder` mutable fields flagged
  `must_be_immutable` (PostgrestBuilder is `@immutable`); silenced with a
  scoped `// ignore:` + rationale comment (recording IS the purpose).
- **MISTAKE (analyzer):** missing `app_error.dart` import for `ServerError`
  in the test — caught by `dart analyze` before running.

## Concurrency notes

- **I-53-notification-center holds `lib/core/services/notification_service.dart`
  and `docs/to-fix/TODO.md`** — my two other target files. Per AGENT-RULES §1 I
  did all non-conflicting work first (RestClient + ConfigService + tests), then
  started a detached `agent_lock.sh acquire` wait. After the locks landed the
  service was re-read and the migration composed with their changes: I-53 had
  changed `subscribeToNotifications` to return `Future<RealtimeChannel>` —
  preserved as-is.
- **I-53's two `_FakeNotificationService implements NotificationService`
  classes broke under the new `rest` getter** (`test/features/notifications/
  notification_center_test.dart`, `integration_test/notifications_flow_test.dart`).
  Their locks were still held; I waited for them to be free, then added the
  one-line `@override RestClient get rest => throw UnimplementedError();` +
  import to each (coordination per AGENT-RULES §2.2 — noted here for the
  orchestrator). Unit suite `notification_center_test.dart` 29/29 green.
  The integration flow **cannot currently load** — the build fails inside
  I-53's in-flight `realtime_service.dart` refactor (`_subscribeToChannel`
  referenced at line 59 but not defined in the current tree; I-53 holds that
  lock). Pre-existing concurrent state, not a regression from this agent.
- **I-50/I-52/I-54/I-55 in flight** (repositories, realtime provider test,
  event screens + their l10n keys): `dart analyze` full-repo currently shows
  their transient errors (AppLocalizations keys pending, `base` function
  pending, etc.). All of my files analyze clean in isolation.

## Validation (final)

```bash
dart analyze lib/core/services/rest_client.dart lib/core/services/config_service.dart \
  lib/core/services/notification_service.dart test/services/ \
  test/features/notifications/notification_center_test.dart integration_test/notifications_flow_test.dart
# No issues found

flutter test test/services/rest_client_test.dart test/services/notification_service_test.dart test/services/config_service_test.dart
# 29 pass (15 envelope + 6 notification + 7 config; migrated-service tests unchanged & green)
flutter test test/services/                                    # 202 pass
flutter test test/features/notifications/notification_center_test.dart   # 29 pass
```

Full `flutter test` cannot reach 0 failures while concurrent agents are
mid-flight (I-52 realtime provider, I-53 realtime_service refactor, I-54/I-55
event screens + l10n keys, I-56 chat screen): the failing set is entirely
files owned by those agents (event_detail 7, realtime_provider 5, chat_screen
5, app_router 1, plus meta/perf/flag guards tripped by their in-flight code).
None of the failures reference I-51 files — reported, not mine to fix.

## Commands run

```bash
export AGENT_NAME="I-51-rest-client"
tools/agent_lock.sh list                                   # conflict check (I-53 on notification_service + TODO.md)
tools/agent_lock.sh acquire lib/core/services/rest_client.dart --owner "$AGENT_NAME"     # + config_service, 3 test files
nohup tools/agent_lock.sh acquire lib/core/services/notification_service.dart --owner "$AGENT_NAME" &
flutter test test/services/rest_client_test.dart test/services/config_service_test.dart
```
