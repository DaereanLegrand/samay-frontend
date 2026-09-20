import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/router/main_shell.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The Games tab (2026-09-20): the plugged minigames in one column list.
///
/// Deliberately minimal — a hairline row per game (icon + name), the whole
/// row tappable, no imagery and no buttons. Tapping opens the game's page
/// ("Nueva partida" + ongoing partidas). A row carries the red invite badge
/// while an invited partida of that game awaits an answer.
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
          SliverList.separated(
            itemCount: MinigameType.values.length,
            separatorBuilder: (_, _) =>
                const Divider(height: 1, color: AppColors.hairline),
            itemBuilder: (context, index) {
              final type = MinigameType.values[index];
              return _GameRow(
                type: type,
                pending: pendingByType[type.value] ?? 0,
              );
            },
          ),
          SliverToBoxAdapter(
            child: SizedBox(height: MainShell.navBarInset(context)),
          ),
        ],
      ),
    );
  }
}

/// One game row: icon + Title Case name, whole row tappable.
class _GameRow extends StatelessWidget {
  final MinigameType type;
  final int pending;

  const _GameRow({required this.type, required this.pending});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return InkWell(
      onTap: () => context.push(RoutePaths.minigame(type.value)),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.lg,
        ),
        child: Row(
          children: [
            Icon(minigameIcon(type), color: AppColors.white, size: 24),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                minigameGameName(l10n, type.value),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (pending > 0) VCountBadge(count: pending),
          ],
        ),
      ),
    );
  }
}
