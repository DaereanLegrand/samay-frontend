import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:samay/core/services/storage_service.dart';
import 'package:samay/features/minigames/local/local_group_store.dart';
import 'package:samay/features/minigames/local/local_match_store.dart';

/// The saved pass-the-phone groups, newest-read from the encrypted Hive box the
/// match history already uses.
///
/// Opening the box is lazy and tolerant: a brand-new install (or a simulator
/// build whose keychain has no entitlement) simply has no saved groups instead
/// of failing the lobby.
final localGroupStoreProvider = Provider<LocalGroupStore>((ref) {
  return HiveLocalGroupStore(
    openBox: () async => Hive.box<String>(HiveService.minigameSummaryBoxName),
  );
});

/// The saved groups as a list, best-effort.
class SavedLocalGroupsNotifier extends AsyncNotifier<List<LocalGroup>> {
  LocalGroupStore get _store => ref.read(localGroupStoreProvider);

  @override
  Future<List<LocalGroup>> build() async {
    try {
      return await _store.all();
    } catch (_) {
      return const [];
    }
  }

  /// Saves [group] (same id replaces) and reloads.
  Future<void> save(LocalGroup group) async {
    await _store.save(group);
    state = AsyncData(await _store.all());
  }

  Future<void> delete(String id) async {
    await _store.delete(id);
    state = AsyncData(await _store.all());
  }
}

final savedLocalGroupsProvider =
    AsyncNotifierProvider<SavedLocalGroupsNotifier, List<LocalGroup>>(
      SavedLocalGroupsNotifier.new,
    );

/// The people this device has already played with, most-played first.
///
/// Derived from the same on-device match history the leaderboard reads, so the
/// lobby can offer a seat with one tap instead of retyping a name. Best-effort:
/// a cold/unreadable box simply yields no names.
final playedWithNamesProvider = FutureProvider<List<String>>((ref) async {
  try {
    final store = HiveLocalMatchStore(
      openBox: () async =>
          Hive.box<String>(HiveService.minigameSummaryBoxName),
    );
    final summaries = await store.recent();
    final counts = <String, int>{};
    for (final summary in summaries) {
      for (final name in summary.playerNames) {
        final clean = name.trim();
        if (clean.isNotEmpty) counts[clean] = (counts[clean] ?? 0) + 1;
      }
    }
    final names = counts.keys.toList()
      ..sort((a, b) {
        final byCount = counts[b]!.compareTo(counts[a]!);
        return byCount != 0 ? byCount : a.toLowerCase().compareTo(b.toLowerCase());
      });
    return names;
  } catch (_) {
    return const <String>[];
  }
});
