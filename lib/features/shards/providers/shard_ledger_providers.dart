import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/models/ledger_entry.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/shards_service.dart';

/// The combined shard + preshard ledger state (SLED — I-64).
///
/// [shards] and [preshards] are the two newest-first movement lists; the
/// derived totals sum every delta per side, so the UI can show the net
/// earned-spent without a separate query.
class ShardLedgerData {
  const ShardLedgerData({required this.shards, required this.preshards});

  final List<LedgerEntry> shards;
  final List<LedgerEntry> preshards;

  /// Net of every `shard_ledger` delta (earned − spent as recorded).
  int get shardTotal => shards.fold(0, (sum, entry) => sum + entry.delta);

  /// Net of every `preshard_ledger` delta.
  int get preshardTotal => preshards.fold(0, (sum, entry) => sum + entry.delta);

  bool get isEmpty => shards.isEmpty && preshards.isEmpty;
}

class ShardLedgerNotifier extends AsyncNotifier<ShardLedgerData> {
  ShardsService get _shards => ref.read(shardsServiceProvider);

  @override
  Future<ShardLedgerData> build() async {
    final shardsFuture = _shards.getShardLedger();
    final preshardsFuture = _shards.getPreshardLedger();
    final shards = await shardsFuture;
    final preshards = await preshardsFuture;
    return ShardLedgerData(shards: shards, preshards: preshards);
  }

  /// Re-runs [build] (pull-to-refresh, finding SM-09).
  Future<void> refresh() async => ref.invalidateSelf();
}

/// Both ledger histories of the current user (`sl_read_own` / `pl_read_own`
/// RLS). The shards economy is LIVE, so this provider ships ungated.
final shardLedgerProvider =
    AsyncNotifierProvider<ShardLedgerNotifier, ShardLedgerData>(
      ShardLedgerNotifier.new,
    );
