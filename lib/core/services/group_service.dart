import 'package:samay/core/utils/input_sanitizer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Group lifecycle: creation, membership, invites, roles and management.
///
/// Part of the ARC-05/CQ-01 decomposition of the former monolithic
/// `SupabaseService` (I-11).
class GroupService {
  final SupabaseClient client;

  GroupService({required this.client});

  GoTrueClient get auth => client.auth;

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');

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
      'role': 'promotor',
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
    if (user == null) throw Exception('No authenticated user');
    await client.from('group_members').insert({
      'group_id': groupId,
      'user_id': user.id,
      'role': 'member',
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
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

  Future<List<Map<String, dynamic>>> getGroupMembers(String groupId) async {
    final res = await client
        .from('group_members')
        .select('id, user_id, role, joined_at, status, users!inner(username)')
        .eq('group_id', groupId)
        .eq('status', 'active');
    return res.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getGroupInvites() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
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

  Future<void> transferPromotor(String groupId, String newPromotorId) async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    await client
        .from('group_members')
        .update({'role': 'co_promotor'})
        .eq('group_id', groupId)
        .eq('user_id', user.id)
        .eq('role', 'promotor');
    await client
        .from('group_members')
        .update({'role': 'promotor'})
        .eq('group_id', groupId)
        .eq('user_id', newPromotorId);
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
    if (user == null) throw Exception('No authenticated user');
    final res = await client
        .from('group_members')
        .select('id')
        .eq('user_id', user.id)
        .eq('role', 'promotor');
    return res.length;
  }

  Future<List<Map<String, dynamic>>> getMyGroups() async {
    final user = auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final memberships = await client
        .from('group_members')
        .select('group_id, role')
        .eq('user_id', user.id);
    if (memberships.isEmpty) return [];
    final groupIds = memberships.map((m) => m['group_id'] as String).toList();
    final groups = await client
        .from('groups')
        .select()
        .inFilter('id', groupIds);
    for (final g in groups) {
      final m = memberships.firstWhere((m) => m['group_id'] == g['id']);
      g['my_role'] = m['role'];
    }
    return groups.map((e) => Map<String, dynamic>.from(e)).toList();
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
