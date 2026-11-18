import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/prompt_pack_service.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/packs/providers/packs_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_card.dart';
import 'package:samay/shared/widgets/v_chip.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/v_spinner.dart';

/// The prompt-pack catalogue: every free/paid pack with its game, prompt count
/// and a lock chip when the caller's subscription tier does not cover it.
///
/// A free pack opens a read-only preview of its prompts (fetched through the
/// cache-first repository, so it also warms the offline bank). A locked pack
/// routes to the existing paywall — purchasing stays in
/// `features/packs` (the paywall).
class PromptPacksScreen extends ConsumerWidget {
  const PromptPacksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final packsAsync = ref.watch(promptPacksProvider);
    return Scaffold(
      body: VHeaderBar(
        title: l10n.promptPacksTitle,
        child: packsAsync.when(
          loading: () => const VLoadingView(),
          error: (e, _) => ErrorView(
            message: e.toAppError().message,
            onRetry: () => ref.invalidate(promptPacksProvider),
          ),
          data: (packs) {
            if (packs.isEmpty) {
              return Center(
                child: Text(
                  l10n.promptPacksEmpty,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.only(bottom: AppSpacing.xl),
              itemCount: packs.length,
              separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, i) => _PackRow(pack: packs[i]),
            );
          },
        ),
      ),
    );
  }
}

class _PackRow extends StatelessWidget {
  const _PackRow({required this.pack});

  final PromptPackInfo pack;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tierLabel = pack.tierRequirement.toUpperCase();
    return VCard(
      padding: EdgeInsets.zero,
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.xs,
          ),
          title: Text(pack.name),
          subtitle: Text(
            '${minigameGameName(l10n, pack.gameType)} · '
            '${l10n.promptPacksCount(pack.promptCount)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: pack.locked
              ? IgnorePointer(
                  child: VChip(
                    label: l10n.cosmeticsRequiresTier(tierLabel),
                    compact: true,
                  ),
                )
              : const Icon(Icons.chevron_right),
          onTap: () {
            if (pack.locked) {
              context.push(RoutePaths.subscriptions);
            } else {
              _openPack(context, pack);
            }
          },
        ),
      ),
    );
  }

  void _openPack(BuildContext context, PromptPackInfo pack) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _PackPreviewSheet(pack: pack),
    );
  }
}

/// A read-only preview of a pack's prompts (the same content the single-device
/// engine draws from). Owns its own loading/error/locked states.
class _PackPreviewSheet extends ConsumerWidget {
  const _PackPreviewSheet({required this.pack});

  final PromptPackInfo pack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final contentAsync = ref.watch(promptPackProvider(pack.id));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        child: contentAsync.when(
          loading: () =>
              const SizedBox(height: 160, child: Center(child: VSpinner())),
          error: (e, _) => SizedBox(
            height: 200,
            child: ErrorView(
              message: e.toAppError().message,
              onRetry: () => ref.invalidate(promptPackProvider(pack.id)),
            ),
          ),
          data: (content) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pack.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${minigameGameName(l10n, pack.gameType)} · '
                '${l10n.promptPacksCount(content.prompts.length)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: content.prompts.length,
                  itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: Text(
                      content.prompts[i].body,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
