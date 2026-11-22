import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/page_insets.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/features/friends/providers/friends_providers.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/games_deck.dart';
import 'package:samay/features/notifications/providers/notifications_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_count_badge.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The slim app's only root: the games deck.
///
/// The vertical, finger-tracked deck ([GamesDeck]): the current game is the
/// centred card, the previous one sits behind and below and the next behind and
/// above. Dragging vertically cycles the circular deck; tapping the centred
/// card opens that game. The header menu is the single entry point to the
/// non-game surfaces (social, packs, notifications, profile, settings,
/// optional sign-in).
class GamesHomeScreen extends ConsumerWidget {
  const GamesHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pendingByType = ref.watch(pendingMinigameInvitesByTypeProvider);
    final statusTop = MediaQuery.paddingOf(context).top;
    // The header's total height (status inset + outer pads + title band): the
    // deck reserves it at the top so the centred card keeps its position, while
    // the header itself is painted ON TOP of the deck in the Stack below.
    final headerTotal = statusTop + VHeaderMetrics.barOuterHeight(statusTop);

    return Scaffold(
      backgroundColor: context.palette.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(top: headerTotal),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppSpacing.screenHorizontal,
                  AppSpacing.lg,
                  AppSpacing.screenHorizontal,
                  pageBottomInset(context),
                ),
                child: GamesDeck(
                  games: MinigameType.values,
                  pendingByType: pendingByType,
                  onOpen: (type) =>
                      context.push(RoutePaths.minigame(type.value)),
                  onPlay: (type) => context.push(
                    '${RoutePaths.localMatch(type.value)}?quick=1',
                  ),
                ),
              ),
            ),
          ),
          // The header never paints glass here, so without a backdrop the card
          // that overflows upward showed through the title — on a phone the
          // deck's repeating name strip landed straight on the word. A scrim
          // over exactly the reserved band (fading out just below it) hides the
          // card there and keeps the flat page colour.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerTotal + AppSpacing.xl,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.palette.background,
                      context.palette.background,
                      context.palette.background.withValues(alpha: 0),
                    ],
                    stops: const [0, 0.78, 1],
                  ),
                ),
              ),
            ),
          ),
          // Painted AFTER the deck and the scrim: any card that overflows
          // upward is hidden behind the title instead of covering it.
          Align(
            alignment: Alignment.topCenter,
            child: VHeaderBar(
              title: l10n.welcomeSamay,
              showBack: false,
              actions: const [_GamesMenuButton()],
            ),
          ),
        ],
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
