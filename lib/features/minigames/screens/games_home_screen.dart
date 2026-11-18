import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/page_insets.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/features/notifications/providers/notifications_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The slim app's only root: the games list.
///
/// A plain vertical list, not a carousel: every game is visible at once, one tap
/// opens it, and there is nothing to learn. The header menu is the single entry
/// point to the non-game surfaces (social, packs, notifications, profile,
/// settings, optional sign-in).
class GamesHomeScreen extends ConsumerWidget {
  const GamesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pendingByType = ref.watch(pendingMinigameInvitesByTypeProvider);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: VHeaderBar(
        titleWidget: MinigameHeaderTitle(
          word: l10n.minigamesTitle,
          secondary: l10n.minigamesTagline,
        ),
        showBack: false,
        actions: const [_GamesMenuButton()],
        child: ListView.separated(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.lg,
            AppSpacing.screenHorizontal,
            pageBottomInset(context),
          ),
          itemCount: MinigameType.values.length,
          separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
          itemBuilder: (context, i) {
            final type = MinigameType.values[i];
            return _GameRow(
              type: type,
              pending: pendingByType[type.value] ?? 0,
              onTap: () => context.push(RoutePaths.minigame(type.value)),
            );
          },
        ),
      ),
    );
  }
}

/// One game: a big tap target with its icon, name, tagline and invite badge.
class _GameRow extends StatelessWidget {
  const _GameRow({
    required this.type,
    required this.pending,
    required this.onTap,
  });

  final MinigameType type;
  final int pending;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      button: true,
      label: minigameGameName(l10n, type.value),
      child: Material(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(2),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(2),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.lg,
            ),
            child: Row(
              children: [
                Icon(
                  minigameIcon(type),
                  size: 30,
                  color: context.palette.foreground,
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        minigameGameName(l10n, type.value).toLowerCase(),
                        style: AppTypography.titleLarge.copyWith(
                          color: context.palette.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        type.tagline(l10n),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall.copyWith(
                          color: context.palette.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                if (pending > 0) ...[
                  VCountBadge(count: pending),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Icon(
                  Icons.chevron_right,
                  color: context.palette.mutedForeground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The single entry point to every kept non-game surface.
class _GamesMenuButton extends ConsumerWidget {
  const _GamesMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(pendingCountsProvider);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: const Icon(Icons.menu),
          tooltip: MaterialLocalizations.of(context).showMenuTooltip,
          onPressed: () => _showMenu(context),
        ),
        if (pending > 0)
          Positioned(
            right: 4,
            top: 4,
            child: IgnorePointer(child: VCountBadge(count: pending)),
          ),
      ],
    );
  }

  Future<void> _showMenu(BuildContext context) async {
    final route = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => const _GamesMenuSheet(),
    );
    if (route == null || !context.mounted) return;
    context.push(route);
  }
}

class _GamesMenuSheet extends ConsumerWidget {
  const _GamesMenuSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final isGuest = ref.watch(authStateProvider).valueOrNull?.isGuest ?? false;
    final pending = ref.watch(pendingCountsProvider);
    final unread = ref.watch(unreadCountProvider);

    Widget row({
      required IconData icon,
      required String label,
      required String route,
      int badge = 0,
    }) {
      return ListTile(
        leading: Icon(icon, color: context.palette.foreground),
        title: Text(label),
        trailing: badge > 0 ? VCountBadge(count: badge) : null,
        onTap: () => Navigator.of(context).pop(route),
      );
    }

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          row(
            icon: Icons.group_outlined,
            label: l10n.menuSocial,
            route: RoutePaths.social,
            badge: pending,
          ),
          row(
            icon: Icons.style_outlined,
            label: l10n.menuPacks,
            route: RoutePaths.promptPacks,
          ),
          row(
            icon: Icons.notifications_outlined,
            label: l10n.menuNotifications,
            route: RoutePaths.notifications,
            badge: unread,
          ),
          row(
            icon: Icons.person_outline,
            label: l10n.menuProfile,
            route: RoutePaths.profile,
          ),
          row(
            icon: Icons.settings_outlined,
            label: l10n.menuSettings,
            route: RoutePaths.settings,
          ),
          // Optional upgrade, guests only — never a gate on play.
          if (isGuest)
            row(
              icon: Icons.verified_user_outlined,
              label: l10n.menuSignIn,
              route: RoutePaths.signIn,
            ),
          SizedBox(height: pageBottomInset(context)),
        ],
      ),
    );
  }
}
