import 'package:flutter/foundation.dart';
import 'package:samay/core/errors/app_error.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/local/local_prompt_pack.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Rank of a `subscription_tier` wire value — `free < pro < vip`.
///
/// Unknown values rank as `free`, so a malformed tier never unlocks a paid
/// pack (fail-closed).
int tierRank(String tier) {
  return switch (tier.trim().toLowerCase()) {
    'pro' => 1,
    'vip' => 2,
    _ => 0,
  };
}

/// Whether a [userTier] reaches the [requiredTier] minimum.
bool satisfiesTier(String userTier, String requiredTier) =>
    tierRank(userTier) >= tierRank(requiredTier);

Object? _pick(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value != null) return value;
  }
  return null;
}

String _asString(Object? value) => value is String ? value : '';

int _asInt(Object? value, int fallback) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

bool _asBool(Object? value) => value is bool ? value : false;

/// One catalogue row from `list_prompt_packs()`.
@immutable
class PromptPackInfo {
  const PromptPackInfo({
    required this.id,
    required this.gameType,
    required this.name,
    required this.tierRequirement,
    required this.packVersion,
    required this.promptCount,
    required this.locked,
  });

  /// Pack uuid (the `p_pack_id` of `get_prompt_pack`).
  final String id;

  /// `mini_game_type` wire string (`truth_dare`, …).
  final String gameType;

  final String name;

  /// Minimum `subscription_tier` (`free` / `pro` / `vip`).
  final String tierRequirement;

  /// Bumped when the pack contents change (cache invalidation key).
  final int packVersion;

  /// Active prompts in the pack.
  final int promptCount;

  /// Server-computed: the caller's tier does not cover [tierRequirement].
  final bool locked;

  /// Tolerant parse of one catalogue entry. Accepts the snake_case wire shape
  /// as well as camelCase (cache round-trips) and survives missing/garbage
  /// fields instead of throwing.
  factory PromptPackInfo.fromJson(Map<String, dynamic> json) {
    final tier = _asString(
      _pick(json, const ['tier_requirement', 'tierRequirement']),
    );
    return PromptPackInfo(
      id: _asString(_pick(json, const ['id'])),
      gameType: _asString(_pick(json, const ['game_type', 'gameType'])),
      name: _asString(_pick(json, const ['name'])),
      tierRequirement: tier.isEmpty ? 'free' : tier,
      packVersion: _asInt(
        _pick(json, const ['pack_version', 'packVersion']),
        1,
      ),
      promptCount: _asInt(
        _pick(json, const ['prompt_count', 'promptCount']),
        0,
      ),
      locked: _asBool(_pick(json, const ['locked'])),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'game_type': gameType,
    'name': name,
    'tier_requirement': tierRequirement,
    'pack_version': packVersion,
    'prompt_count': promptCount,
    'locked': locked,
  };

  /// A copy with a refreshed lock state (client-side tier check) — the
  /// catalogue's `locked` is authoritative, this only re-renders a cached row.
  PromptPackInfo copyWith({bool? locked}) => PromptPackInfo(
    id: id,
    gameType: gameType,
    name: name,
    tierRequirement: tierRequirement,
    packVersion: packVersion,
    promptCount: promptCount,
    locked: locked ?? this.locked,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PromptPackInfo &&
        other.id == id &&
        other.gameType == gameType &&
        other.name == name &&
        other.tierRequirement == tierRequirement &&
        other.packVersion == packVersion &&
        other.promptCount == promptCount &&
        other.locked == locked;
  }

  @override
  int get hashCode => Object.hash(
    id,
    gameType,
    name,
    tierRequirement,
    packVersion,
    promptCount,
    locked,
  );

  @override
  String toString() => 'PromptPackInfo($id, $gameType, locked: $locked)';
}

/// One prompt row of a fetched pack.
@immutable
class PromptRow {
  const PromptRow({
    required this.id,
    required this.promptType,
    required this.category,
    required this.body,
  });

  final String id;
  final String promptType;
  final String category;
  final String body;

  /// Tolerant parse: rows without an id (or that are not maps at all) are
  /// dropped by [PromptPackContent.fromJson]; the fields themselves never
  /// throw.
  factory PromptRow.fromJson(Map<String, dynamic> json) => PromptRow(
    id: _asString(_pick(json, const ['id'])),
    promptType: _asString(
      _pick(json, const ['prompt_type', 'promptType', 'type']),
    ),
    category: _asString(_pick(json, const ['category'])),
    body: _asString(_pick(json, const ['body'])),
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt_type': promptType,
    'category': category,
    'body': body,
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PromptRow &&
        other.id == id &&
        other.promptType == promptType &&
        other.category == category &&
        other.body == body;
  }

  @override
  int get hashCode => Object.hash(id, promptType, category, body);

  @override
  String toString() => 'PromptRow($id, $promptType)';
}

/// A fetched pack: its metadata plus every active prompt.
@immutable
class PromptPackContent {
  const PromptPackContent({
    required this.packId,
    required this.gameType,
    required this.name,
    required this.packVersion,
    required this.tierRequirement,
    required this.prompts,
  });

  final String packId;
  final String gameType;
  final String name;
  final int packVersion;
  final String tierRequirement;
  final List<PromptRow> prompts;

  /// Tolerant parse of the `get_prompt_pack` payload (also used to read the
  /// on-device cache; the `status` key is ignored here). A missing `pack`
  /// object yields empty metadata; malformed prompt rows — and rows without an
  /// id — are skipped.
  factory PromptPackContent.fromJson(Map<String, dynamic> json) {
    final packValue = json['pack'];
    final pack = packValue is Map
        ? Map<String, dynamic>.from(packValue)
        : const <String, dynamic>{};
    final rows = json['prompts'];
    final prompts = <PromptRow>[];
    if (rows is List) {
      for (final row in rows) {
        if (row is! Map) continue;
        final parsed = PromptRow.fromJson(Map<String, dynamic>.from(row));
        if (parsed.id.isEmpty) continue;
        prompts.add(parsed);
      }
    }
    final tier = _asString(
      _pick(pack, const ['tier_requirement', 'tierRequirement']),
    );
    return PromptPackContent(
      packId: _asString(_pick(pack, const ['id'])),
      gameType: _asString(_pick(pack, const ['game_type', 'gameType'])),
      name: _asString(_pick(pack, const ['name'])),
      packVersion: _asInt(
        _pick(pack, const ['pack_version', 'packVersion']),
        1,
      ),
      tierRequirement: tier.isEmpty ? 'free' : tier,
      prompts: prompts,
    );
  }

  Map<String, dynamic> toJson() => {
    'pack': {
      'id': packId,
      'game_type': gameType,
      'name': name,
      'pack_version': packVersion,
      'tier_requirement': tierRequirement,
    },
    'prompts': [for (final prompt in prompts) prompt.toJson()],
  };

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! PromptPackContent ||
        other.packId != packId ||
        other.gameType != gameType ||
        other.name != name ||
        other.packVersion != packVersion ||
        other.tierRequirement != tierRequirement ||
        other.prompts.length != prompts.length) {
      return false;
    }
    for (var i = 0; i < prompts.length; i++) {
      if (other.prompts[i] != prompts[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    packId,
    gameType,
    name,
    packVersion,
    tierRequirement,
    prompts.length,
  );

  @override
  String toString() =>
      'PromptPackContent($packId, $gameType, ${prompts.length} prompts)';
}

/// Maps wire `game_type` strings to the playable [MinigameType].
///
/// This mirrors `minigameTypeFromString` in `minigame_meta.dart` locally on
/// purpose: that helper lives in a Flutter/l10n layer, and this core service
/// must stay widget-free. Unknown game types (the DB enum runs ahead of the
/// four playable games) map to null and are SKIPPED, never thrown.
MinigameType? _minigameTypeFor(String wire) {
  return switch (wire) {
    'truth_dare' => MinigameType.truthDare,
    'drunk_bottle' => MinigameType.drunkBottle,
    'two_lies_one_truth' => MinigameType.twoLiesOneTruth,
    'charades' => MinigameType.charades,
    _ => null,
  };
}

/// Builds the single-device engine's prompt banks from fetched packs.
///
/// A pack whose `game_type` has no playable [MinigameType] is skipped.
List<LocalPromptPack> toLocalPacks(Iterable<PromptPackContent> contents) {
  final packs = <LocalPromptPack>[];
  for (final content in contents) {
    final gameType = _minigameTypeFor(content.gameType);
    if (gameType == null) continue;
    packs.add(
      LocalPromptPack(
        id: content.packId,
        gameType: gameType,
        name: content.name,
        version: content.packVersion,
        prompts: [
          for (final row in content.prompts)
            LocalPrompt(
              id: row.id,
              promptType: row.promptType,
              category: row.category,
              body: row.body,
            ),
        ],
      ),
    );
  }
  return packs;
}

/// The RPC seam: `(functionName, params) -> raw jsonb`. The production
/// constructor binds it to [SupabaseClient.rpc]; [PromptPackService.withRpc]
/// lets tests inject a fake without a network client.
typedef PromptPackRpc =
    Future<dynamic> Function(String function, Map<String, dynamic>? params);

/// Prompt-pack catalogue/content reads over the slim backend RPCs
/// (`list_prompt_packs()` / `get_prompt_pack(uuid)`).
///
/// Direct `minigame_prompts` reads are revoked for clients — these RPCs are the
/// only way to enumerate the bank, and `get_prompt_pack` enforces the tier gate
/// server-side.
class PromptPackService {
  PromptPackService({required SupabaseClient client})
    : _rpc = ((function, params) => client.rpc(function, params: params)),
      _auth = client.auth;

  /// Test seam: an explicit RPC function, no client / auth guard.
  PromptPackService.withRpc(PromptPackRpc rpc) : _rpc = rpc, _auth = null;

  final PromptPackRpc _rpc;
  final GoTrueClient? _auth;

  void _requireUser() {
    final auth = _auth;
    if (auth != null && auth.currentUser == null) {
      throw const UnauthorizedError();
    }
  }

  /// The active pack catalogue with the server-computed `locked` flag.
  Future<List<PromptPackInfo>> listPacks() async {
    _requireUser();
    final res = await _rpc('list_prompt_packs', null);

    if (res is List) {
      return _parseCatalogue(res);
    }
    if (res is Map) {
      final map = Map<String, dynamic>.from(res);
      final status = map['status'];
      if (status == 'not_authenticated') throw const UnauthorizedError();
      final packs = map['packs'];
      if (packs is List) return _parseCatalogue(packs);
      if (status == 'ok' && packs == null) return const [];
      throw const ServerError('Unexpected list_prompt_packs response');
    }
    throw const ServerError('Unexpected list_prompt_packs response');
  }

  List<PromptPackInfo> _parseCatalogue(List<dynamic> rows) {
    return [
      for (final row in rows)
        if (row is Map) PromptPackInfo.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  /// One pack + its prompts.
  ///
  /// Throws [ConflictError] (`code: 'pack_locked'`) when the caller's tier does
  /// not cover the pack, [NotFoundError] when the pack does not exist, and
  /// [UnauthorizedError] when the session is gone.
  Future<PromptPackContent?> fetchPack(String packId) async {
    _requireUser();
    final res = await _rpc('get_prompt_pack', {'p_pack_id': packId});
    if (res is! Map) {
      throw const ServerError('Unexpected get_prompt_pack response');
    }
    final map = Map<String, dynamic>.from(res);
    return switch (map['status']) {
      'ok' => PromptPackContent.fromJson(map),
      'locked' => throw ConflictError('pack_locked', code: 'pack_locked'),
      'not_found' => throw const NotFoundError('Pack'),
      'not_authenticated' => throw const UnauthorizedError(),
      'not_onboarded' => throw PermissionError(),
      _ => throw const ServerError('Unexpected get_prompt_pack response'),
    };
  }
}
