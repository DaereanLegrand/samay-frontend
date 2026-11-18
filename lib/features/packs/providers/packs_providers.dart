import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/services/prompt_pack_service.dart';
import 'package:samay/features/minigames/local/local_prompt_pack.dart';
import 'package:samay/features/packs/packs_repository.dart';

/// Prompt-pack RPC service, bound to the app's Supabase client.
final promptPackServiceProvider = Provider<PromptPackService>((ref) {
  return PromptPackService(client: ref.watch(supabaseClientProvider));
});

/// Cache-first pack repository (catalogue + pack contents + offline engine
/// banks). One instance per container so concurrent screens share the cache.
final packsRepositoryProvider = Provider<PacksRepository>((ref) {
  return PacksRepository(
    service: ref.watch(promptPackServiceProvider),
    cache: ref.watch(hiveServiceProvider),
  );
});

/// The pack catalogue (`list_prompt_packs`), cache-first.
///
/// `ref.invalidate(promptPacksProvider)` re-runs the read — which serves the
/// cached copy when present. Use `ref.read(packsRepositoryProvider).refresh()`
/// to force a network round-trip (the refresh writes the new catalogue back to
/// the cache before the invalidation re-reads it).
final promptPacksProvider = FutureProvider<List<PromptPackInfo>>((ref) {
  return ref.watch(packsRepositoryProvider).list();
});

/// One pack's content (`get_prompt_pack`), cache-first.
///
/// Throws `ConflictError(code: 'pack_locked')` for a locked pack — the screen
/// routes that into the paywall instead of an error view.
final promptPackProvider = FutureProvider.family<PromptPackContent, String>((
  ref,
  packId,
) {
  return ref.watch(packsRepositoryProvider).open(packId);
});

/// Engine-ready prompt banks for [type], read from the on-device cache only
/// (fully offline — the single-device match source).
final localPacksForProvider =
    FutureProvider.family<List<LocalPromptPack>, MinigameType>((ref, type) {
      return ref.watch(packsRepositoryProvider).localPacksFor(type);
    });

/// The pack a single-device match will play from: cached when possible, one
/// network fetch on a cold cache.
final localMatchPackProvider =
    FutureProvider.family<LocalPromptPack, MinigameType>((ref, type) {
      return ref.watch(packsRepositoryProvider).ensurePackFor(type);
    });
