import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/services/supabase_service.dart';

class MyProfileNotifier extends AsyncNotifier<Map<String, dynamic>?> {
  @override
  Future<Map<String, dynamic>?> build() async {
    final user = SupabaseService.instance.auth.currentUser;
    if (user == null) return null;
    final res = await SupabaseService.instance.client
        .from('users')
        .select('username, bio, personal_shards, preshards')
        .eq('id', user.id)
        .maybeSingle();
    return res != null ? Map<String, dynamic>.from(res) : null;
  }

  /// Re-runs [build] after profile edits (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// The current user's profile row (username, bio, shard balances).
final myProfileProvider = AsyncNotifierProvider<MyProfileNotifier,
    Map<String, dynamic>?>(MyProfileNotifier.new);

class ProfileGroupsNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    return SupabaseService.instance.getMyGroups();
  }

  /// Re-runs [build] after group membership changes.
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Groups the current user belongs to, shown on the profile screen.
///
/// Deliberately independent of `groups_providers.myGroupsProvider`: the
/// profile feature should not import another feature's providers (SM-08
/// co-location), and I-13 wires this provider into the profile screens.
final myGroupsProvider = AsyncNotifierProvider<ProfileGroupsNotifier,
    List<Map<String, dynamic>>>(ProfileGroupsNotifier.new);
