import 'package:flutter_test/flutter_test.dart';
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/services/prompt_pack_service.dart';
import 'package:samay/core/services/storage_service.dart';
import 'package:samay/features/minigames/local/local_prompt_pack.dart';
import 'package:samay/features/packs/packs_repository.dart';

/// In-memory stand-in for the `prompt_pack_cache` Hive box. Only the four
/// cache methods the repository touches are overridden; everything else is a
/// [Fake] (throws if reached).
class _FakePackCache extends Fake implements HiveService {
  List<Map<String, dynamic>>? list;
  final Map<String, Map<String, dynamic>> packs = {};
  bool fail = false;

  void _guard() {
    if (fail) throw StateError('hive unavailable');
  }

  @override
  List<Map<String, dynamic>>? getCachedPromptPacks() {
    _guard();
    return list;
  }

  @override
  Future<void> putCachedPromptPacks(List<Map<String, dynamic>> packs) async {
    _guard();
    list = packs;
  }

  @override
  Map<String, dynamic>? getCachedPromptPack(String id) {
    _guard();
    return packs[id];
  }

  @override
  Future<void> putCachedPromptPack(String id, Map<String, dynamic> json) async {
    _guard();
    packs[id] = json;
  }
}

class _FakePromptPackService extends Fake implements PromptPackService {
  int listCalls = 0;
  int fetchCalls = 0;
  List<PromptPackInfo> packs = const [];
  Object? listError;
  Object? fetchError;
  PromptPackContent? content;

  @override
  Future<List<PromptPackInfo>> listPacks() async {
    listCalls++;
    final error = listError;
    if (error != null) throw error;
    return packs;
  }

  @override
  Future<PromptPackContent?> fetchPack(String packId) async {
    fetchCalls++;
    final error = fetchError;
    if (error != null) throw error;
    return content;
  }
}

PromptPackService _rpcService(
  Future<dynamic> Function(String fn, Map<String, dynamic>? params) rpc,
) => PromptPackService.withRpc(rpc);

PromptPackInfo _info({
  String id = 'c0000000-0000-4000-8000-000000000001',
  String gameType = 'truth_dare',
  bool locked = false,
  String tier = 'free',
}) => PromptPackInfo(
  id: id,
  gameType: gameType,
  name: 'Paquete base',
  tierRequirement: tier,
  packVersion: 1,
  promptCount: 2,
  locked: locked,
);

PromptPackContent _content({
  String id = 'c0000000-0000-4000-8000-000000000001',
  String gameType = 'truth_dare',
}) => PromptPackContent(
  packId: id,
  gameType: gameType,
  name: 'Paquete base',
  packVersion: 1,
  tierRequirement: 'free',
  prompts: const [
    PromptRow(
      id: 'p1',
      promptType: 'verdad',
      category: 'suave',
      body: '¿Cuál es tu mayor secreto?',
    ),
    PromptRow(
      id: 'p2',
      promptType: 'reto',
      category: 'medio',
      body: 'Imita a alguien del grupo.',
    ),
  ],
);

Map<String, dynamic> _contentJson({
  String id = 'c0000000-0000-4000-8000-000000000001',
  String gameType = 'truth_dare',
}) => {
  'pack': {
    'id': id,
    'game_type': gameType,
    'name': 'Paquete base',
    'pack_version': 1,
    'tier_requirement': 'free',
  },
  'prompts': [
    {
      'id': 'p1',
      'prompt_type': 'verdad',
      'category': 'suave',
      'body': '¿Cuál es tu mayor secreto?',
    },
  ],
};

void main() {
  group('PromptPackInfo.fromJson', () {
    test('parses the wire shape (snake_case)', () {
      final info = PromptPackInfo.fromJson({
        'id': 'abc',
        'game_type': 'charades',
        'name': 'Paquete extra',
        'tier_requirement': 'pro',
        'pack_version': 3,
        'prompt_count': 42,
        'locked': true,
      });
      expect(info.id, 'abc');
      expect(info.gameType, 'charades');
      expect(info.name, 'Paquete extra');
      expect(info.tierRequirement, 'pro');
      expect(info.packVersion, 3);
      expect(info.promptCount, 42);
      expect(info.locked, isTrue);
    });

    test('is tolerant of missing/garbage fields', () {
      final info = PromptPackInfo.fromJson(const {});
      expect(info.id, isEmpty);
      expect(info.gameType, isEmpty);
      expect(info.name, isEmpty);
      expect(info.tierRequirement, 'free');
      expect(info.packVersion, 1);
      expect(info.promptCount, 0);
      expect(info.locked, isFalse);

      final weird = PromptPackInfo.fromJson(const {
        'pack_version': 'x',
        'prompt_count': null,
        'locked': 'yes',
      });
      expect(weird.packVersion, 1);
      expect(weird.promptCount, 0);
      expect(weird.locked, isFalse);
    });

    test('accepts camelCase keys too', () {
      final info = PromptPackInfo.fromJson(const {
        'id': 'abc',
        'gameType': 'drunk_bottle',
        'tierRequirement': 'vip',
        'packVersion': 2,
        'promptCount': 7,
      });
      expect(info.gameType, 'drunk_bottle');
      expect(info.tierRequirement, 'vip');
      expect(info.packVersion, 2);
      expect(info.promptCount, 7);
    });
  });

  group('PromptPackContent.fromJson', () {
    test('parses pack + prompts', () {
      final content = PromptPackContent.fromJson({
        'status': 'ok',
        'pack': {
          'id': 'pack-1',
          'game_type': 'truth_dare',
          'name': 'Base',
          'pack_version': 2,
          'tier_requirement': 'pro',
        },
        'prompts': [
          {
            'id': 'p1',
            'prompt_type': 'verdad',
            'category': 'suave',
            'body': 'Verdad 1',
          },
        ],
      });
      expect(content.packId, 'pack-1');
      expect(content.gameType, 'truth_dare');
      expect(content.name, 'Base');
      expect(content.packVersion, 2);
      expect(content.tierRequirement, 'pro');
      expect(content.prompts, hasLength(1));
      expect(content.prompts.first.body, 'Verdad 1');
    });

    test('tolerates a missing pack and skips malformed prompt rows', () {
      final content = PromptPackContent.fromJson(const {
        'prompts': [
          'not-a-map',
          {'body': 'sin id'},
          {'id': 'p2', 'body': 'ok'},
        ],
      });
      expect(content.packId, isEmpty);
      expect(content.gameType, isEmpty);
      expect(content.tierRequirement, 'free');
      expect(content.prompts, hasLength(1));
      expect(content.prompts.single.id, 'p2');
      expect(content.prompts.single.promptType, isEmpty);
    });

    test('round-trips through toJson', () {
      final original = _content();
      final restored = PromptPackContent.fromJson(original.toJson());
      expect(restored, original);
    });
  });

  group('toLocalPacks', () {
    test('maps wire game types and skips unknown ones', () {
      final packs = toLocalPacks([
        _content(),
        _content(
          id: 'd0000000-0000-4000-8000-000000000099',
          gameType: 'poke_chain',
        ),
      ]);
      expect(packs, hasLength(1));
      final pack = packs.single;
      expect(pack.id, 'c0000000-0000-4000-8000-000000000001');
      expect(pack.gameType, MinigameType.truthDare);
      expect(pack.name, 'Paquete base');
      expect(pack.version, 1);
      expect(pack.prompts, hasLength(2));
      expect(
        pack.prompts.first,
        const LocalPrompt(
          id: 'p1',
          promptType: 'verdad',
          category: 'suave',
          body: '¿Cuál es tu mayor secreto?',
        ),
      );
    });
  });

  group('tierRank / satisfiesTier', () {
    test('rank matrix', () {
      expect(tierRank('free'), 0);
      expect(tierRank('pro'), 1);
      expect(tierRank('vip'), 2);
      expect(tierRank('unknown'), 0);
      expect(tierRank(' PRO '), 1);
    });

    test('satisfies matrix', () {
      expect(satisfiesTier('free', 'free'), isTrue);
      expect(satisfiesTier('free', 'pro'), isFalse);
      expect(satisfiesTier('free', 'vip'), isFalse);
      expect(satisfiesTier('pro', 'free'), isTrue);
      expect(satisfiesTier('pro', 'pro'), isTrue);
      expect(satisfiesTier('pro', 'vip'), isFalse);
      expect(satisfiesTier('vip', 'free'), isTrue);
      expect(satisfiesTier('vip', 'pro'), isTrue);
      expect(satisfiesTier('vip', 'vip'), isTrue);
      expect(satisfiesTier('unknown', 'free'), isTrue);
      expect(satisfiesTier('unknown', 'pro'), isFalse);
    });
  });

  group('PromptPackService.listPacks', () {
    test('parses a bare array (migration shape)', () async {
      final service = _rpcService((fn, params) async {
        expect(fn, 'list_prompt_packs');
        return [
          {
            'id': 'abc',
            'game_type': 'truth_dare',
            'name': 'Base',
            'tier_requirement': 'free',
            'pack_version': 1,
            'prompt_count': 2,
            'locked': false,
          },
        ];
      });
      final packs = await service.listPacks();
      expect(packs, hasLength(1));
      expect(packs.single.id, 'abc');
    });

    test('parses the status-wrapped shape', () async {
      final service = _rpcService((fn, params) async {
        return {
          'status': 'ok',
          'packs': [
            {'id': 'abc', 'game_type': 'charades', 'locked': true},
          ],
        };
      });
      final packs = await service.listPacks();
      expect(packs.single.gameType, 'charades');
      expect(packs.single.locked, isTrue);
    });

    test('maps not_authenticated to UnauthorizedError', () async {
      final service = _rpcService(
        (fn, params) async => {'status': 'not_authenticated'},
      );
      await expectLater(service.listPacks(), throwsA(isA<UnauthorizedError>()));
    });

    test('maps an unexpected status to ServerError', () async {
      final service = _rpcService((fn, params) async => {'status': 'oops'});
      await expectLater(service.listPacks(), throwsA(isA<ServerError>()));
    });
  });

  group('PromptPackService.fetchPack', () {
    test('returns content on ok', () async {
      final service = _rpcService((fn, params) async {
        expect(fn, 'get_prompt_pack');
        expect(params, {'p_pack_id': 'pack-1'});
        return {
          'status': 'ok',
          'pack': {
            'id': 'pack-1',
            'game_type': 'truth_dare',
            'name': 'Base',
            'pack_version': 1,
            'tier_requirement': 'free',
          },
          'prompts': [
            {
              'id': 'p1',
              'prompt_type': 'verdad',
              'category': 'suave',
              'body': 'Verdad',
            },
          ],
        };
      });
      final content = await service.fetchPack('pack-1');
      expect(content, isNotNull);
      expect(content!.packId, 'pack-1');
      expect(content.prompts.single.body, 'Verdad');
    });

    test('locked -> ConflictError(pack_locked)', () async {
      final service = _rpcService((fn, params) async => {'status': 'locked'});
      await expectLater(
        service.fetchPack('pack-1'),
        throwsA(
          isA<ConflictError>().having((e) => e.code, 'code', 'pack_locked'),
        ),
      );
    });

    test('not_found -> NotFoundError', () async {
      final service = _rpcService(
        (fn, params) async => {'status': 'not_found'},
      );
      await expectLater(
        service.fetchPack('pack-1'),
        throwsA(isA<NotFoundError>()),
      );
    });

    test('not_authenticated -> UnauthorizedError', () async {
      final service = _rpcService(
        (fn, params) async => {'status': 'not_authenticated'},
      );
      await expectLater(
        service.fetchPack('pack-1'),
        throwsA(isA<UnauthorizedError>()),
      );
    });
  });

  group('PacksRepository', () {
    test('list() returns cache without calling the service', () async {
      final cache = _FakePackCache()..list = [_info().toJson()];
      final service = _FakePromptPackService();
      final repo = PacksRepository(service: service, cache: cache);

      final packs = await repo.list();
      expect(packs.single.id, _info().id);
      expect(service.listCalls, 0);
    });

    test('list() on a cold cache fetches and writes', () async {
      final cache = _FakePackCache();
      final service = _FakePromptPackService()..packs = [_info()];
      final repo = PacksRepository(service: service, cache: cache);

      final packs = await repo.list();
      expect(packs.single.id, _info().id);
      expect(service.listCalls, 1);
      expect(cache.list, hasLength(1));
    });

    test('refresh() always hits the network and rewrites the cache', () async {
      final cache = _FakePackCache()..list = [_info(id: 'stale').toJson()];
      final service = _FakePromptPackService()..packs = [_info()];
      final repo = PacksRepository(service: service, cache: cache);

      final packs = await repo.refresh();
      expect(packs.single.id, _info().id);
      expect(service.listCalls, 1);
      expect(cache.list!.single['id'], _info().id);
    });

    test('refresh() falls back to cache when the network fails', () async {
      final cache = _FakePackCache()..list = [_info().toJson()];
      final service = _FakePromptPackService()
        ..listError = const ServerError('down');
      final repo = PacksRepository(service: service, cache: cache);

      final packs = await repo.refresh();
      expect(packs.single.id, _info().id);
    });

    test('open() returns a cached pack without fetching', () async {
      final cache = _FakePackCache()..packs[_info().id] = _contentJson();
      final service = _FakePromptPackService();
      final repo = PacksRepository(service: service, cache: cache);

      final content = await repo.open(_info().id);
      expect(content.gameType, 'truth_dare');
      expect(service.fetchCalls, 0);
    });

    test('open() fetches and caches on a miss', () async {
      final cache = _FakePackCache();
      final service = _FakePromptPackService()..content = _content();
      final repo = PacksRepository(service: service, cache: cache);

      final content = await repo.open(_info().id);
      expect(content.packId, _info().id);
      expect(service.fetchCalls, 1);
      expect(cache.packs[_info().id], isNotNull);
    });

    test('open() rethrows the typed lock error', () async {
      final cache = _FakePackCache();
      final service = _FakePromptPackService()
        ..fetchError = ConflictError('pack_locked', code: 'pack_locked');
      final repo = PacksRepository(service: service, cache: cache);

      await expectLater(
        repo.open('locked-pack'),
        throwsA(
          isA<ConflictError>().having((e) => e.code, 'code', 'pack_locked'),
        ),
      );
    });

    test('localPacksFor works fully offline from the cache', () async {
      final cache = _FakePackCache()
        ..list = [_info().toJson()]
        ..packs[_info().id] = _contentJson();
      final service = _FakePromptPackService();
      final repo = PacksRepository(service: service, cache: cache);

      final packs = await repo.localPacksFor(MinigameType.truthDare);
      expect(packs, hasLength(1));
      expect(packs.single.gameType, MinigameType.truthDare);
      expect(packs.single.prompts, hasLength(1));
      expect(packs.single.prompts.single.promptType, 'verdad');
      expect(service.fetchCalls, 0);
      expect(service.listCalls, 0);
    });

    test('localPacksFor returns [] for a type with no cached pack', () async {
      final cache = _FakePackCache()
        ..list = [_info().toJson()]
        ..packs[_info().id] = _contentJson();
      final service = _FakePromptPackService();
      final repo = PacksRepository(service: service, cache: cache);

      final packs = await repo.localPacksFor(MinigameType.charades);
      expect(packs, isEmpty);
    });

    test('a failing cache degrades to no-cache, never a crash', () async {
      final cache = _FakePackCache()..fail = true;
      final service = _FakePromptPackService()..packs = [_info()];
      final repo = PacksRepository(service: service, cache: cache);

      final packs = await repo.list();
      expect(packs.single.id, _info().id);
      expect(service.listCalls, 1);
      expect(repo.cachedLocalPacks(), isEmpty);
    });

    test('a failing cache on open() still fetches', () async {
      final cache = _FakePackCache()..fail = true;
      final service = _FakePromptPackService()..content = _content();
      final repo = PacksRepository(service: service, cache: cache);

      final content = await repo.open(_info().id);
      expect(content.packId, _info().id);
      expect(service.fetchCalls, 1);
    });

    test('cachedLocalPacks maps every cached pack', () async {
      final cache = _FakePackCache()
        ..list = [
          _info().toJson(),
          _info(
            id: 'c0000000-0000-4000-8000-000000000004',
            gameType: 'charades',
          ).toJson(),
        ]
        ..packs[_info().id] = _contentJson()
        ..packs['c0000000-0000-4000-8000-000000000004'] = _contentJson(
          id: 'c0000000-0000-4000-8000-000000000004',
          gameType: 'charades',
        );
      final service = _FakePromptPackService();
      final repo = PacksRepository(service: service, cache: cache);

      final packs = repo.cachedLocalPacks();
      expect(packs, hasLength(2));
      expect(
        packs.map((p) => p.gameType),
        containsAll([MinigameType.truthDare, MinigameType.charades]),
      );
    });
  });

  group('PacksRepository ensurePackFor (single-device source)', () {
    test('a warm cache never touches the network', () async {
      final cache = _FakePackCache()
        ..list = [
          _info().toJson(),
        ]
        ..packs[_info().id] = _contentJson();
      final service = _FakePromptPackService();
      final repo = PacksRepository(service: service, cache: cache);

      final pack = await repo.ensurePackFor(MinigameType.truthDare);

      expect(pack.gameType, MinigameType.truthDare);
      expect(pack.prompts, isNotEmpty);
      expect(service.listCalls, 0);
      expect(service.fetchCalls, 0);
    });

    test('a cold cache makes exactly one catalogue + one pack fetch', () async {
      final cache = _FakePackCache();
      final service = _FakePromptPackService()
        ..packs = [_info()]
        ..content = _content();
      final repo = PacksRepository(service: service, cache: cache);

      final pack = await repo.ensurePackFor(MinigameType.truthDare);

      expect(pack.id, _info().id);
      expect(service.listCalls, 1);
      expect(service.fetchCalls, 1);
      // The fetch is written back, so a second call is served from the cache.
      await repo.ensurePackFor(MinigameType.truthDare);
      expect(service.listCalls, 1);
      expect(service.fetchCalls, 1);
    });

    test('only a FREE (unlocked) pack is fetched', () async {
      final cache = _FakePackCache();
      final service = _FakePromptPackService()
        ..packs = [_info(id: 'd0000000-0000-4000-8000-000000000001', locked: true)]
        ..content = _content();
      final repo = PacksRepository(service: service, cache: cache);

      await expectLater(
        repo.ensurePackFor(MinigameType.truthDare),
        throwsA(isA<NotFoundError>()),
      );
      expect(service.fetchCalls, 0);
    });

    test('a network failure on a cold cache surfaces to the caller', () async {
      final cache = _FakePackCache();
      final service = _FakePromptPackService()
        ..listError = const ServerError('offline');
      final repo = PacksRepository(service: service, cache: cache);

      await expectLater(
        repo.ensurePackFor(MinigameType.truthDare),
        throwsA(isA<ServerError>()),
      );
    });
  });
}
