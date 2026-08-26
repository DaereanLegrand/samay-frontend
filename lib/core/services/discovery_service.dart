import 'package:samay/core/models/user_interests.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// User search and Party Finder (PFND) discovery logic.
///
/// Extracted from the former monolithic [UserService] as part of the
/// Batch 5b decomposition.
class DiscoveryService {
  final SupabaseClient client;

  DiscoveryService({required this.client});

  GoTrueClient get auth => client.auth;

  /// User search via the `search_users(p_query)` SECURITY DEFINER RPC
  /// (migration 130_search/01_search_rpc.sql): the server validates the
  /// trimmed query length (>= 5 chars), enforces the 60/min per-user quota
  /// (raises SR001 → RateLimitError via error_mapper) and caps results at
  /// 20 rows. Friendship enrichment (status/pending direction, block
  /// filtering + hiding) stays client-side below.
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final user = auth.currentUser;
    final res = await client.rpc(
      'search_users',
      params: {'p_query': query},
    );
    final results = (res as List)
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    if (results.isEmpty || user == null) return results;

    final ids = results.map((r) => r['id'] as String).toList();
    final asRequester = await client
        .from('friendships')
        .select('id, requester_id, addressee_id, status')
        .eq('requester_id', user.id)
        .inFilter('addressee_id', ids);
    final asAddressee = await client
        .from('friendships')
        .select('id, requester_id, addressee_id, status')
        .eq('addressee_id', user.id)
        .inFilter('requester_id', ids);
    final frRows = [...asRequester, ...asAddressee];

    final blockedByMe = <String>{};
    final blockedByThem = <String>{};
    final statusByUser = <String, String>{};
    final pendingIds = <String, String>{};
    final pendingDirections = <String, String>{};
    for (final row in frRows) {
      final otherId = row['requester_id'] == user.id
          ? row['addressee_id'] as String
          : row['requester_id'] as String;
      final status = row['status'] as String;
      statusByUser[otherId] = status;
      if (status == 'pending') {
        pendingIds[otherId] = row['id'] as String;
        pendingDirections[otherId] = row['requester_id'] == user.id
            ? 'sent'
            : 'received';
      } else if (status == 'blocked') {
        if (row['requester_id'] == user.id) {
          blockedByMe.add(otherId);
        } else {
          blockedByThem.add(otherId);
        }
      }
    }

    return results
        .where((r) => !blockedByMe.contains(r['id']))
        .map((r) {
          final uid = r['id'] as String;
          final frStatus = statusByUser[uid];
          if (frStatus != null) {
            r['friendship_status'] = frStatus;
          }
          if (frStatus == 'pending') {
            r['friendship_id'] = pendingIds[uid];
            r['friendship_direction'] = pendingDirections[uid];
          }
          if (blockedByThem.contains(uid)) {
            r['hidden'] = true;
          }
          return r;
        })
        .where((r) => r['hidden'] != true)
        .toList();
  }

  /// Party Finder matches (PFND — I-60): opted-in users from the
  /// `discovery_view` security-barrier view whose interest tags overlap mine,
  /// ranked by shared-tag count DESC (spec: mutual friends first — deferred
  /// to the FRND-owned follow-up) then username ASC.
  ///
  /// Each returned row carries `shared_tags` (sorted intersection) and
  /// `shared_count`. Blocked users never appear (drops blocks I issued; hides
  /// users who blocked me) — mirrors [searchUsers] so a block lands
  /// immediately without re-deriving policy.
  Future<List<Map<String, dynamic>>> findMatches(List<String> myTags) async {
    final user = auth.currentUser;
    if (user == null || myTags.isEmpty) return const [];

    final res = await client
        .from('discovery_view')
        .select('id, username, avatar_url, interest_tags')
        .neq('id', user.id)
        .overlaps('interest_tags', myTags)
        .limit(50);
    final results = res.map((e) => Map<String, dynamic>.from(e)).toList();
    if (results.isEmpty) return results;

    final myTagSet = myTags.toSet();
    for (final row in results) {
      final shared = UserInterests.fromDb(row['interest_tags']).tags
          .intersection(myTagSet)
          .toList()
        ..sort();
      row['shared_tags'] = shared;
      row['shared_count'] = shared.length;
    }
    results.sort((a, b) {
      final byCount =
          (b['shared_count'] as int).compareTo(a['shared_count'] as int);
      if (byCount != 0) return byCount;
      return (a['username'] as String? ?? '')
          .compareTo(b['username'] as String? ?? '');
    });

    final ids = results.map((r) => r['id'] as String).toList();
    final asRequester = await client
        .from('friendships')
        .select('requester_id, addressee_id, status')
        .eq('requester_id', user.id)
        .inFilter('addressee_id', ids);
    final asAddressee = await client
        .from('friendships')
        .select('requester_id, addressee_id, status')
        .eq('addressee_id', user.id)
        .inFilter('requester_id', ids);
    final frRows = [...asRequester, ...asAddressee];

    final blockedByMe = <String>{};
    final blockedByThem = <String>{};
    for (final row in frRows) {
      if (row['status'] != 'blocked') continue;
      if (row['requester_id'] == user.id) {
        blockedByMe.add(row['addressee_id'] as String);
      } else {
        blockedByThem.add(row['requester_id'] as String);
      }
    }

    return results
        .where((r) => !blockedByMe.contains(r['id']))
        .where((r) => !blockedByThem.contains(r['id']))
        .toList();
  }
}
