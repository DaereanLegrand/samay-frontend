import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'package:samay/core/services/storage_service.dart';
import 'package:samay/features/minigames/local/local_group_store.dart';

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
