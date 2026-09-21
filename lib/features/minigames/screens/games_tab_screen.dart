import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/router/main_shell.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The Games tab (2026-09-20): the plugged minigames as a two-column grid of
/// square tiles, each half the content width. Deliberately minimal — a
/// Material icon + Title Case name, the whole tile tappable, no imagery and
/// no buttons. Tapping opens the game's page ("Nueva partida" + ongoing
/// partidas). A tile carries the red invite badge while an invited partida of
/// that game awaits an answer.
class GamesTabScreen extends ConsumerWidget {
  const GamesTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pendingByType = ref.watch(pendingMinigameInvitesByTypeProvider);
    return Scaffold(
      backgroundColor: AppColors.discoBlack,
      body: CustomScrollView(
        slivers: [
          // The page Header — the one verbatim/lowercase surface (title
          // exception); every label below it is Title Case.
          VHeaderSliver(title: l10n.minigamesTitle),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.lg,
              AppSpacing.screenHorizontal,
              0,
            ),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: AppSpacing.sm,
                mainAxisSpacing: AppSpacing.sm,
                childAspectRatio: 1,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final type = MinigameType.values[index];
                return _GameTile(
                  type: type,
                  pending: pendingByType[type.value] ?? 0,
                );
              }, childCount: MinigameType.values.length),
            ),
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MainShell.navBarInset(context)),
          ),
        ],
      ),
    );
  }
}

/// One game tile: a square `surfaceAlt` block, icon + Title Case name, whole
/// tile tappable.
class _GameTile extends StatelessWidget {
  final MinigameType type;
  final int pending;

  const _GameTile({required this.type, required this.pending});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => context.push(RoutePaths.minigame(type.value)),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          border: Border.all(color: AppColors.hairline),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    minigameIcon(type),
                    color: AppColors.white,
                    size: AppIconSizes.xxl,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      minigameGameName(l10n, type.value),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
            ),
            if (pending > 0)
              Positioned(
                top: AppSpacing.sm,
                right: AppSpacing.sm,
                child: VCountBadge(count: pending),
              ),
          ],
        ),
      ),
    );
  }
}
