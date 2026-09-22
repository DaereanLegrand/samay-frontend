import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/repositories/repository_providers.dart';
import 'package:samay/core/utils/throttled_refresh.dart';

class MyProfileNotifier extends AsyncNotifier<Map<String, dynamic>?>
    with ThrottledRefresh {
  @override
  Future<Map<String, dynamic>?> build() async {
    final profile = await ref.read(profileRepositoryProvider).getMyProfile();
    markFetched();
    return profile?.toJson();
  }

  /// Re-runs [build] after profile edits.  skipped while
  /// the last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// The current user's profile row (username, bio, shard balances).
final myProfileProvider = AsyncNotifierProvider<MyProfileNotifier,
    Map<String, dynamic>?>(MyProfileNotifier.new);

class ProfileGroupsNotifier extends AsyncNotifier<List<Map<String, dynamic>>>
    with ThrottledRefresh {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final groups = await ref.read(groupsRepositoryProvider).getMyGroups();
    markFetched();
    return groups.map((g) => g.toJson()).toList();
  }

  /// Re-runs [build] after group membership changes.  skipped while the
  /// last fetch is younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// Groups the current user belongs to, shown on the profile screen.
///
/// Deliberately independent of `groups_providers.myGroupsProvider`: the
/// profile feature should not import another feature's providers
/// (co-location), and this provider is wired into the profile screens.
final myGroupsProvider = AsyncNotifierProvider<ProfileGroupsNotifier,
    List<Map<String, dynamic>>>(ProfileGroupsNotifier.new);
