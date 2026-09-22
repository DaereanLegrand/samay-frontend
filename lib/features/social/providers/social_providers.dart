import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/utils/throttled_refresh.dart';
import 'package:samay/features/social/services/social_service.dart';

/// One row of the global user ranking.
///
/// `profilePublic` rides the RPC so the CLIENT applies the censor rule:
/// the username renders only when `ranking.anonymize_names` is OFF OR the
/// profile is public; otherwise the localized `socialCensoredName`.
class UserRankingEntry {
  final String userId;
  final String username;
  final String? avatarUrl;
  final int personalShards;
  final bool profilePublic;

  const UserRankingEntry({
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.personalShards,
    required this.profilePublic,
  });

  factory UserRankingEntry.fromRow(Map<String, dynamic> row) {
    return UserRankingEntry(
      userId: row['user_id'] as String,
      username: row['username'] as String? ?? '',
      avatarUrl: row['avatar_url'] as String?,
      personalShards: (row['personal_shards'] as num?)?.toInt() ?? 0,
      profilePublic: row['profile_public'] == true,
    );
  }
}

class UserRankingNotifier extends AsyncNotifier<List<UserRankingEntry>>
    with ThrottledRefresh {
  @override
  Future<List<UserRankingEntry>> build() async {
    final service = ref.read(socialServiceProvider);
    final rows = await service.getUserRanking();
    markFetched();
    return rows.map(UserRankingEntry.fromRow).toList(growable: false);
  }

  /// Re-runs [build] (pull-to-refresh), skipped while the last fetch is
  /// younger than [refreshThrottle].
  Future<void> refresh() async {
    if (!shouldRefetch()) return;
    ref.invalidateSelf();
  }
}

/// The global user ranking (non-deleted users by personal_shards DESC).
final userRankingProvider = AsyncNotifierProvider<UserRankingNotifier,
    List<UserRankingEntry>>(UserRankingNotifier.new);

/// The caller's public-profile switch (`users.profile_public`, default
/// false). Optimistic toggle with rollback; failures surface to the settings
/// row.
class ProfilePublicNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    try {
      return await ref.read(socialServiceProvider).getProfilePublic();
    } catch (e, st) {
      AppLogger.instance.warn(
        'profile_public pref unreadable ($e); using default OFF.',
        '$st',
      );
      return false;
    }
  }

  /// Toggles the switch. Optimistic; on persistence failure the value rolls
  /// back and the error is rethrown (the settings row surfaces it).
  Future<void> setEnabled(bool value) async {
    state = AsyncData(value);
    try {
      await ref.read(socialServiceProvider).setProfilePublic(value);
    } catch (e, st) {
      AppLogger.instance.error(
        'profile_public save failed (rolling back): $e',
        '$st',
      );
      state = AsyncData(!value);
      rethrow;
    }
  }
}

/// The public-profile privacy switch (autoDispose — a fresh read whenever
/// the settings row mounts).
final profilePublicProvider = AsyncNotifierProvider<ProfilePublicNotifier,
    bool>(ProfilePublicNotifier.new);

/// Injectable seam for the Social feature services (tests override this).
final socialServiceProvider = Provider<SocialService>((ref) {
  return SocialService(client: ref.watch(supabaseClientProvider));
});
