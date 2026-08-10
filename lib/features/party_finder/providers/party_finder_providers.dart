import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';

/// Owns the current user's Party Finder opt-in (`users.discovery_opt_in`,
/// PFND spec: default OFF, opt-in required to be discoverable).
///
/// Reads and persists directly on the own `users` row — the I-60 migration
/// decision keeps `discovery_opt_in` (and `interest_tags`) OUT of I-32's
/// `assert_safe_user_update` protected set and OUT of the column-level
/// REVOKE UPDATE list, so the privacy toggle self-serves through
/// `users_update_own` (id = auth.uid()) without an RPC.
class DiscoveryOptInNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    return ref.read(userServiceProvider).getDiscoveryOptIn();
  }

  /// Persists the toggle and flips the provider state on success; failures
  /// surface as [AsyncError] (established provider convention — the screen's
  /// error states read `valueOrNull`, so a failed write must not leave a
  /// stale value behind).
  Future<void> setOptIn(bool value) async {
    try {
      await ref.read(userServiceProvider).setDiscoveryOptIn(value);
      state = AsyncData(value);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  /// Re-reads the persisted value (pull-to-refresh).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// The current user's Party Finder opt-in (false = not discoverable, can
/// still browse).
final discoveryOptInProvider =
    AsyncNotifierProvider<DiscoveryOptInNotifier, bool>(
  DiscoveryOptInNotifier.new,
);

class PartyMatchesNotifier extends AsyncNotifier<List<Map<String, dynamic>>> {
  @override
  Future<List<Map<String, dynamic>>> build() async {
    final service = ref.read(userServiceProvider);
    final myTags = await service.getMyInterestTags();
    return service.findMatches(myTags);
  }

  /// Re-runs [build] after the opt-in, tags or blocks change (finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Party Finder matches: opted-in users with overlapping interest tags
/// (via the `discovery_view` security-barrier view), each row carrying
/// `shared_tags` + `shared_count`, sorted by shared-tag count descending
/// (PFND spec; ties broken alphabetically by username in the service).
///
/// Empty when the current user has no interest tags yet — matches require
/// the caller's own tags to compute overlap.
final partyMatchesProvider =
    AsyncNotifierProvider<PartyMatchesNotifier, List<Map<String, dynamic>>>(
  PartyMatchesNotifier.new,
);
