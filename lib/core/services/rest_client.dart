import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A single PostgREST filter: [column] compared with [op] against [value].
///
/// Supported [op]s mirror the parameterized chain methods of
/// [PostgrestFilterBuilder]: `eq`, `neq`, `gt`, `gte`, `lt`, `lte`, `like`,
/// `ilike` and `in`. Values are always forwarded as typed method arguments —
/// never string-interpolated into a query string — so
/// the wrapper is injection-safe by construction.
typedef RestFilter = ({String column, String op, Object? value});

/// Thin typed envelope over [SupabaseClient].
///
/// Every read returns typed models through a caller-supplied `fromJson`
/// factory — freezed models expose a static `fromJson(Map<String, dynamic>)`
/// that plugs in directly:
///
/// ```dart
/// final items = await rest.list<NotificationItem>(
///   'notifications',
///   fromJson: NotificationItem.fromJson,
///   filters: [(column: 'user_id', op: 'eq', value: userId)],
/// );
/// ```
///
/// Writes are table-scoped (`update`/`delete` take the id column + value so
/// every mutation is row-filtered). Constructor-injected [SupabaseClient]
/// keeps the wrapper unit-testable against fakes; see [restClientProvider]
/// for the Riverpod wiring.
///
/// ## Migration path (services → RestClient)
///
/// Services migrate one at a time by replacing their
/// `client.from(...).select(...).eq(...)` chains with `rest.list/maybeSingle/
/// single/insert/update/delete` calls; the `client` field stays on the service
/// (auth accessor + compatibility call sites) until the facade deletion.
/// Proof-of-migration services: [ConfigService] and [NotificationService].
class RestClient {
  RestClient({required SupabaseClient client}) : _client = client;

  final SupabaseClient _client;

  /// Selects [select] (default `*`) rows of [table] filtered by [filters],
  /// ordered by [order] (default ascending; set [ascending] to `false` for
  /// newest-first) and capped at [limit], mapping every row through
  /// [fromJson].
  Future<List<T>> list<T>(
    String table, {
    required T Function(Map<String, dynamic>) fromJson,
    String? select,
    List<RestFilter> filters = const [],
    String? order,
    bool ascending = true,
    int? limit,
  }) async {
    var builder = _client.from(table).select(select ?? '*');
    for (final filter in filters) {
      builder = _apply(builder, filter);
    }
    PostgrestTransformBuilder<PostgrestList> transform = builder;
    if (order != null) {
      transform = transform.order(order, ascending: ascending);
    }
    if (limit != null) {
      transform = transform.limit(limit);
    }
    final rows = await transform;
    return [
      for (final row in rows) fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// Selects at most one row of [table] filtered by [filters]; returns null
  /// when no row matches (PostgREST `maybeSingle` semantics).
  Future<T?> maybeSingle<T>(
    String table, {
    required T Function(Map<String, dynamic>) fromJson,
    String? select,
    List<RestFilter> filters = const [],
  }) async {
    final row = await _build(table, select, filters).maybeSingle();
    if (row == null) return null;
    return fromJson(Map<String, dynamic>.from(row));
  }

  /// Selects exactly one row of [table] filtered by [filters], throwing when
  /// zero or multiple rows match (PostgREST `single` semantics — zero rows
  /// surface as a `PGRST116` [PostgrestException]).
  Future<T> single<T>(
    String table, {
    required T Function(Map<String, dynamic>) fromJson,
    String? select,
    List<RestFilter> filters = const [],
  }) async {
    final row = await _build(table, select, filters).single();
    return fromJson(Map<String, dynamic>.from(row));
  }

  /// Inserts [row] into [table].
  Future<void> insert(String table, Map<String, dynamic> row) async {
    await _client.from(table).insert(row);
  }

  /// Applies [patch] to the rows of [table] where [idColumn] equals [id].
  Future<void> update(
    String table,
    String idColumn,
    Object id,
    Map<String, dynamic> patch,
  ) async {
    await _client.from(table).update(patch).eq(idColumn, id);
  }

  /// Deletes the rows of [table] where [idColumn] equals [id].
  Future<void> delete(String table, String idColumn, Object id) async {
    await _client.from(table).delete().eq(idColumn, id);
  }

  PostgrestFilterBuilder<PostgrestList> _build(
    String table,
    String? select,
    List<RestFilter> filters,
  ) {
    var builder = _client.from(table).select(select ?? '*');
    for (final filter in filters) {
      builder = _apply(builder, filter);
    }
    return builder;
  }

  PostgrestFilterBuilder<PostgrestList> _apply(
    PostgrestFilterBuilder<PostgrestList> builder,
    RestFilter filter,
  ) {
    final value = filter.value;
    return switch (filter.op) {
      'eq' => builder.eq(filter.column, value!),
      'neq' => builder.neq(filter.column, value!),
      'gt' => builder.gt(filter.column, value!),
      'gte' => builder.gte(filter.column, value!),
      'lt' => builder.lt(filter.column, value!),
      'lte' => builder.lte(filter.column, value!),
      'like' => builder.like(filter.column, value as String),
      'ilike' => builder.ilike(filter.column, value as String),
      'in' => builder.inFilter(filter.column, value as List),
      _ => throw ArgumentError.value(
          filter.op,
          'op',
          'Unsupported RestClient filter operator',
        ),
    };
  }
}

/// Riverpod wiring: one [RestClient] per container over the canonical
/// [supabaseClientProvider] seam — tests override either provider with a
/// fake/mock client.
final restClientProvider = Provider<RestClient>((ref) {
  return RestClient(client: ref.watch(supabaseClientProvider));
});
