import 'package:supabase_flutter/supabase_flutter.dart';

/// User search logic.
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
}
