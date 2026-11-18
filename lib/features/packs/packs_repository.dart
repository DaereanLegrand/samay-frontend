import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/services/prompt_pack_service.dart';
import 'package:samay/core/services/storage_service.dart';
import 'package:samay/features/minigames/local/local_prompt_pack.dart';

/// Cache-first access to the prompt-pack catalogue and pack contents.
///
/// The encrypted Hive box `prompt_pack_cache` is the single source of truth for
/// the single-device engine: once a pack has been fetched it stays playable
/// offline. The catalogue read ([list]) returns the device copy immediately and
/// only goes to the network when the cache is cold (or [refresh] is called
/// explicitly); [open] does the same per pack.
///
/// Every cache interaction is guarded — a Hive failure (unopened box after key
/// loss, corrupt JSON) degrades to "no cache" and never crashes the caller.
class PacksRepository {
  PacksRepository({required this.service, required this.cache});

  final PromptPackService service;
  final HiveService cache;

  /// The catalogue: the device copy when present (and not [forceRefresh]),
  /// otherwise a network fetch that is written back to the cache. A network
  /// failure falls back to the cache; only a cold cache + network failure
  /// rethrows.
  Future<List<PromptPackInfo>> list({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = _readCatalogue();
      if (cached != null) return cached;
    }
    return _fetchCatalogue();
  }

  /// Always goes to the network, rewrites the cache and returns the fresh
  /// catalogue. On failure it falls back to the cached copy when there is one.
  Future<List<PromptPackInfo>> refresh() => _fetchCatalogue();

  Future<List<PromptPackInfo>> _fetchCatalogue() async {
    try {
      final packs = await service.listPacks();
      await _writeCatalogue(packs);
      return packs;
    } catch (e, st) {
      final cached = _readCatalogue();
      if (cached != null) {
        AppLogger.instance.warn(
          'prompt pack refresh failed, serving cached catalogue: $e',
          '$st',
        );
        return cached;
      }
      rethrow;
    }
  }

  /// One pack's content: the cached copy when present, otherwise the RPC (then
  /// cached). A locked pack rethrows [ConflictError] so the paywall can render.
  Future<PromptPackContent> open(String packId) async {
    final cached = _readPack(packId);
    if (cached != null) return cached;

    final content = await service.fetchPack(packId);
    if (content == null) {
      throw const NotFoundError('Pack');
    }
    await _writePack(content);
    return content;
  }

  /// Every cached pack as engine-ready banks (fully offline).
  List<LocalPromptPack> cachedLocalPacks() {
    final catalogue = _readCatalogue();
    if (catalogue == null) return const [];
    final contents = <PromptPackContent>[];
    for (final info in catalogue) {
      final pack = _readPack(info.id);
      // A pack whose content was never fetched (e.g. locked at first sync)
      // has nothing to contribute to the offline engine.
      if (pack != null) contents.add(pack);
    }
    return toLocalPacks(contents);
  }

  /// The single-device engine's pack for [type]: the cached copy when there is
  /// one, otherwise ONE network round-trip (catalogue + the free pack) so a
  /// first-ever launch can still play. Offline with a warm cache never hits the
  /// network; offline with a cold cache throws and the screen says so.
  Future<LocalPromptPack> ensurePackFor(MinigameType type) async {
    final cached = await localPacksFor(type);
    if (cached.isNotEmpty) return cached.first;

    final catalogue = await list();
    // Only FREE packs are downloadable without an entitlement; a paid-only
    // catalogue means the free pack is missing server-side.
    final info = catalogue
        .where((p) => p.gameType == type.value && !p.locked)
        .firstOrNull;
    if (info == null) throw const NotFoundError('Pack');

    final content = await open(info.id);
    final packs = toLocalPacks([content]);
    if (packs.isEmpty) throw const NotFoundError('Pack');
    return packs.first;
  }

  /// The offline engine's source for [type] — cache only, never the network.
  Future<List<LocalPromptPack>> localPacksFor(MinigameType type) async {
    return [
      for (final pack in cachedLocalPacks())
        if (pack.gameType == type) pack,
    ];
  }

  List<PromptPackInfo>? _readCatalogue() {
    try {
      final rows = cache.getCachedPromptPacks();
      if (rows == null) return null;
      return [for (final row in rows) PromptPackInfo.fromJson(row)];
    } catch (e, st) {
      AppLogger.instance.warn('prompt pack cache read failed: $e', '$st');
      return null;
    }
  }

  Future<void> _writeCatalogue(List<PromptPackInfo> packs) async {
    try {
      await cache.putCachedPromptPacks([for (final p in packs) p.toJson()]);
    } catch (e, st) {
      AppLogger.instance.warn('prompt pack cache write failed: $e', '$st');
    }
  }

  PromptPackContent? _readPack(String packId) {
    try {
      final json = cache.getCachedPromptPack(packId);
      if (json == null) return null;
      return PromptPackContent.fromJson(json);
    } catch (e, st) {
      AppLogger.instance.warn(
        'prompt pack "$packId" cache read failed: $e',
        '$st',
      );
      return null;
    }
  }

  Future<void> _writePack(PromptPackContent content) async {
    try {
      await cache.putCachedPromptPack(content.packId, content.toJson());
    } catch (e, st) {
      AppLogger.instance.warn(
        'prompt pack "${content.packId}" cache write failed: $e',
        '$st',
      );
    }
  }
}
