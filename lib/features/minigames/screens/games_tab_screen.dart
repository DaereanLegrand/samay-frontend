import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/router/main_shell.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/games_deck.dart';
import 'package:samay/features/minigames/widgets/minigame_header_title.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// The Games tab: the plugged minigames as a stack of cards ([GamesDeck]).
/// The current game is centred on top; `cur - 1` sits below it and `cur + 1`
/// sits above, each with a stable random tilt + sideways shift. The header is
/// drawn OVER the deck so the upper card passes BEHIND it.
///
/// Swipe to cycle the circular deck; tap the centred card to open the game's
/// page ("Nueva partida" + ongoing partidas). A card carries the red invite
/// badge while an invited partida of that game awaits an answer.
class GamesTabScreen extends ConsumerWidget {
  const GamesTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final pendingByType = ref.watch(pendingMinigameInvitesByTypeProvider);
    final matchesByGame = ref.watch(gameTabMatchesProvider);
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
                  MainShell.navBarInset(context),
                ),
                child: GamesDeck(
                  games: MinigameType.values,
                  pendingByType: pendingByType,
                  matchesByGame: matchesByGame,
                  onOpen: (type) =>
                      context.push(RoutePaths.minigame(type.value)),
                ),
              ),
            ),
          ),
          // The header only paints glass once the page SCROLLS; this one
          // never does, so without a backdrop the card that overflows upward
          // showed through the title — on a phone the deck's repeating name
          // strip landed straight on the word "juegos". A black scrim over
          // exactly the reserved band (fading out just below it) hides the
          // card there and keeps the flat-black look.
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
              titleWidget: MinigameHeaderTitle(
                word: l10n.minigamesTitle,
                secondary: l10n.minigamesTagline,
              ),
              showBack: false,
            ),
          ),
        ],
      ),
    );
  }
}
