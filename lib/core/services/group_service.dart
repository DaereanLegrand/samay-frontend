import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Group lifecycle: creation, membership, invites, roles and management.
class GroupService {
  final SupabaseClient client;

  GroupService({required this.client});

  GoTrueClient get auth => client.auth;

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();

    final name = InputSanitizer.sanitize(
      data['name'] as String? ?? '',
      maxLength: InputSanitizer.groupNameMaxLength,
    );
    final description = InputSanitizer.sanitizeOptional(
      data['description'] as String?,
      maxLength: InputSanitizer.groupDescriptionMaxLength,
    );

    final groupId = const Uuid().v4();

    await client.from('groups').insert({
      'id': groupId,
      'name': name,
      'description': description,
      'cover_url': data['cover_url'],
      'created_by_user_id': user.id,
      'rank_bracket': 'b0_20',
    });

    await client.from('group_members').insert({
      'group_id': groupId,
      'user_id': user.id,
      'role': 'host',
    });

    await client.from('chats').insert({
      'type': 'group',
      'reference_id': groupId,
    });

    return {
      'id': groupId,
      'name': name,
      'description': description,
    };
  }

  Future<void> joinGroup(String groupId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    await client.from('group_members').insert({
      'group_id': groupId,
      'user_id': user.id,
      'role': 'member',
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    await client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', user.id);
    final remaining = await client
        .from('group_members')
        .select('id')
        .eq('group_id', groupId)
        .limit(1);
    if (remaining.isEmpty) {
      await client.from('groups').delete().eq('id', groupId);
      await client.from('chats').delete().eq('reference_id', groupId).eq('type', 'group');
    }
  }

  Future<Map<String, dynamic>?> getGroup(String groupId) async {
    final res = await client.from('groups').select().eq('id', groupId).maybeSingle();
    if (res == null) return null;
    return Map<String, dynamic>.from(res);
  }

  /// Groups for [groupIds] in ONE read — the batch form of [getGroup]. Ids
  /// with no visible row are absent from the result.
  Future<List<Map<String, dynamic>>> getGroups(List<String> groupIds) async {
    if (groupIds.isEmpty) return const [];
    final res = await client.from('groups').select().inFilter('id', groupIds);
    return [for (final g in res) Map<String, dynamic>.from(g)];
  }

  /// The chat id of [groupId]'s group chat — the `chats` row with
  /// `type = 'group'` and `reference_id = [groupId]` — or null when the chat
  /// row does not exist. Active members can read the group chat row
  /// (`chats_read_participant`, migration 20260817000002 — the group branch
  /// gates on `group_members.status = 'active'`), so the lookup is
  /// participant-gated server-side. Consumed by the UI agent to open a
  /// group's E2EE chat (`ChatService` takes the chat id).
  Future<String?> getGroupChatId(String groupId) async {
    final res = await client
        .from('chats')
        .select('id')
        .eq('type', 'group')
        .eq('reference_id', groupId)
        .maybeSingle();
    return res == null ? null : res['id'] as String?;
  }

  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final res = await client
        .from('group_members')
        // `group_id` is required by the freezed GroupMember model
        // (its absence TypeError'd group-detail into "Error del servidor").
        // Q8: direct SELECT on user_search_view is revoked; resolve the
        // co-member profiles through get_public_profiles (private non-friends
        // keep username but get a null avatar/bio).
        .select('id, group_id, user_id, role, joined_at, status')
        .eq('group_id', groupId)
        .eq('status', 'active');
    final rows = res.map((e) => Map<String, dynamic>.from(e)).toList();
    final ids = [
      for (final row in rows)
        if (row['user_id'] is String) row['user_id'] as String,
    ];
    final byId = await _profilesByIds(ids);
    for (final row in rows) {
      final id = row['user_id'];
      row['users'] = byId[id];
    }
    return rows;
  }

  Future<Map<String, Map<String, dynamic>>> _profilesByIds(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return const {};
    final res = await client.rpc('get_public_profiles', params: {'p_ids': ids});
    return {
      for (final r in (res as List))
        (r as Map)['id'] as String: Map<String, dynamic>.from(r),
    };
  }

  Future<List<Map<String, dynamic>>> getGroupInvites() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client
        .from('group_members')
        .select('id, group_id, role, joined_at, groups!inner(name)')
        .eq('user_id', user.id)
        .eq('status', 'invited');
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> acceptGroupInvite(String membershipId) async {
    await client.from('group_members').update({'status': 'active'}).eq('id', membershipId);
  }

  Future<void> declineGroupInvite(String membershipId) async {
    await client.from('group_members').delete().eq('id', membershipId);
  }

  Future<void> updateGroup(String groupId, Map<String, dynamic> patch) async {
    await client.from('groups').update(patch).eq('id', groupId);
  }

  Future<void> kickMember(String groupId, String userId) async {
    await client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  /// Transfers host leadership to [newHostId].
  ///
  /// Routed through the `transfer_host` SECURITY DEFINER RPC —
  /// a single transaction (demote self to staff + promote the new
  /// host), so a partially-applied transfer can never leave a group with
  /// two hosts or none, and the role-hierarchy RLS (only a host may
  /// create a host) cannot be interleaved by a concurrent request.
  Future<void> transferHost(String groupId, String newHostId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    await client.rpc('transfer_host', params: {
      'p_group_id': groupId,
      'p_new_host_id': newHostId,
    });
  }

  Future<void> setMemberRole(String groupId, String userId, String role) async {
    await client
        .from('group_members')
        .update({'role': role})
        .eq('group_id', groupId)
        .eq('user_id', userId);
  }

  Future<int> getUserGroupCount() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client
        .from('group_members')
        .select('id')
        .eq('user_id', user.id)
        .eq('role', 'host');
    return res.length;
  }

  Future<List<Map<String, dynamic>>> getMyGroups() async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    // `status` rides along so invited memberships keep their pending
    // marker in the groups list (the detail screen also gates on it).
    final memberships = await client
        .from('group_members')
        .select('group_id, role, status')
        .eq('user_id', user.id);
    if (memberships.isEmpty) return [];
    final groupIds = memberships.map((m) => m['group_id'] as String).toList();
    final groups = await client
        .from('groups')
        .select()
        .inFilter('id', groupIds);
    // Active member counts in one batched read (`groups` has no count column;
    // the `group_members_read_same` RLS policy exposes a member's co-members).
    final members = await client
        .from('group_members')
        .select('group_id')
        .inFilter('group_id', groupIds)
        .eq('status', 'active');
    final memberCounts = <String, int>{};
    for (final row in members) {
      final gid = row['group_id'] as String;
      memberCounts[gid] = (memberCounts[gid] ?? 0) + 1;
    }
    for (final g in groups) {
      final m = memberships.firstWhere((m) => m['group_id'] == g['id']);
      g['my_role'] = m['role'];
      g['my_status'] = m['status'];
      g['member_count'] = memberCounts[g['id'] as String] ?? 0;
    }
    return groups.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// The current user's own membership row for [groupId], or null when there
  /// is none. The detail screen gates the invited state on `status`.
  Future<Map<String, dynamic>?> getMyMembership(String groupId) async {
    final user = auth.currentUser;
    if (user == null) throw const UnauthorizedError();
    final res = await client
        .from('group_members')
        .select('id, group_id, role, status')
        .eq('group_id', groupId)
        .eq('user_id', user.id)
        .maybeSingle();
    return res == null ? null : Map<String, dynamic>.from(res);
  }

  /// Invites [userIds] to [groupId] as pending `invited` members.
  Future<void> inviteMembers(String groupId, List<String> userIds) async {
    for (final userId in userIds) {
      await client.from('group_members').insert({
        'group_id': groupId,
        'user_id': userId,
        'role': 'member',
        'status': 'invited',
      });
    }
  }
}
