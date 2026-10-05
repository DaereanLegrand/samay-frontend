import 'dart:typed_data';

import 'package:vector_map_tiles/vector_map_tiles.dart';

/// Vector tile provider that retries transient tile failures and cools down a
/// tile after [maxRetries] consecutive failures so a flaky network cannot spin
/// the map. Ported from the reference app (identical behaviour).
class RetryVectorTileProvider extends VectorTileProvider {
  final VectorTileProvider delegate;
  final int maxRetries;
  final Duration retryDelay;
  final Duration cooldownDuration;

  final Map<String, int> _attempts = {};
  final Map<String, DateTime> _cooldownUntil = {};

  RetryVectorTileProvider({
    required this.delegate,
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
    this.cooldownDuration = const Duration(minutes: 5),
  });

  @override
  int get maximumZoom => delegate.maximumZoom;

  @override
  int get minimumZoom => delegate.minimumZoom;

  @override
  TileProviderType get type => delegate.type;

  String _key(TileIdentity tile) => tile.key();

  @override
  Future<Uint8List> provide(TileIdentity tile) async {
    final key = _key(tile);

    final cooldownEnd = _cooldownUntil[key];
    if (cooldownEnd != null && DateTime.now().isBefore(cooldownEnd)) {
      throw ProviderException(
        message: 'Tile $key in cooldown until $cooldownEnd',
        retryable: Retryable.none,
      );
    }

    final startAttempts = _attempts[key] ?? 0;

    for (int i = 0; i < maxRetries; i++) {
      try {
        final result = await delegate.provide(tile);
        _attempts.remove(key);
        _cooldownUntil.remove(key);
        return result;
      } on ProviderException catch (e) {
        if (e.retryable == Retryable.none) rethrow;

        final attempt = startAttempts + i + 1;
        _attempts[key] = attempt;

        if (attempt >= maxRetries) {
          _cooldownUntil[key] = DateTime.now().add(cooldownDuration);
          rethrow;
        }

        await Future.delayed(retryDelay);
      }
    }

    throw ProviderException(
      message: 'Tile $key failed after $maxRetries retries',
      retryable: Retryable.none,
    );
  }
}
