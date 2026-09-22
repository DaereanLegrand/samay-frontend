/// Pure shard-economy math.
///
/// Mirrors the `distribute_shards` SQL RPC
/// (`supabase/migrations/060_events/03_economy.sql`): floor
/// division of the pool, optional per-user cap, never negative.
///
/// NOTE — Dart-vs-SQL drift: the SQL derives the base
/// per-user amount from *total invitees* and re-clamps from *confirmed
/// attendees* (two denominators); this Dart mirror collapses both to a single
/// `attendees` argument, so the SQL's `per_user * attendees > pool` recompute
/// guard is unreachable here (cap only ever shrinks `per_user`). Any client
/// preview of distribution must not assume it matches the RPC for
/// events where invitees ≠ attendees.
int distribute(int pool, int attendees, {int? capPerUser}) {
  if (pool <= 0 || attendees <= 0) return 0;
  var perUser = pool ~/ attendees;
  if (capPerUser != null && perUser > capPerUser) perUser = capPerUser;
  return perUser < 0 ? 0 : perUser;
}

/// Aggregates contribution rows by `user_id` — summing `shards_contributed`
/// per user — and returns the contributors sorted descending by contribution.
///
/// Extracted from `GroupContributionsNotifier.build` in
/// `groups_providers.dart`, shared by the group detail flow.
/// Input rows are copied (`Map.from`), never mutated.
List<Map<String, dynamic>> aggregateContributions(
  Iterable<Map<String, dynamic>> rows,
) {
  final Map<String, Map<String, dynamic>> aggregated = {};
  for (final row in rows) {
    final uid = row['user_id'] as String;
    final amount = row['shards_contributed'] as int;
    if (aggregated.containsKey(uid)) {
      aggregated[uid]!['shards_contributed'] =
          (aggregated[uid]!['shards_contributed'] as int) + amount;
    } else {
      aggregated[uid] = Map<String, dynamic>.from(row);
    }
  }
  return aggregated.values.toList()
    ..sort((a, b) =>
        (b['shards_contributed'] as int).compareTo(a['shards_contributed'] as int));
}
