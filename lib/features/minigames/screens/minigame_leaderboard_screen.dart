import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/features/groups/providers/groups_providers.dart';
import 'package:samay/features/minigames/providers/minigames_providers.dart';
import 'package:samay/features/minigames/widgets/finished_leaderboard.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/core/theme/app_theme_provider.dart';
import 'package:samay/features/groups/theme/group_theme_theme.dart';
import 'package:samay/features/minigames/widgets/minigame_session_surface.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The finished-match leaderboard as its own route.
///
/// Full-bleed page whose only chrome is the floating back arrow, wrapping
/// [FinishedLeaderboard]. When [initialParticipantId] is supplied the carousel
/// opens focused on that player, so tapping a row in the finished session
/// detail lands on their card. A group partida paints the group theme.
class MinigameLeaderboardScreen extends ConsumerWidget {
  const MinigameLeaderboardScreen({
    super.key,
    required this.sessionId,
    this.initialParticipantId,
  });

  final String sessionId;
  final String? initialParticipantId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolved here (not from the ambient scope) because the scope is mounted
    // BELOW this widget by [MinigameSessionSurface].
    final groupId =
        ref.watch(sessionStatusProvider(sessionId)).valueOrNull?['group_id']
            as String?;
    final theme = groupId == null
        ? null
        : ref.watch(groupThemeProvider(groupId)).valueOrNull;
    final palette = theme == null
        ? null
        : groupSurfacePalette(theme, appPalette: ref.watch(appPaletteProvider));
    return MinigameSessionSurface(
      sessionId: sessionId,
      child: Scaffold(
        backgroundColor: palette?.background ?? context.palette.background,
        body: Stack(
          fit: StackFit.expand,
          children: [
            FinishedLeaderboard(
              sessionId: sessionId,
              initialParticipantId: initialParticipantId,
            ),
            Align(
              alignment: Alignment.topLeft,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    top:
                        VHeaderMetrics.headerOuterPad +
                        VHeaderMetrics.heroTopPad(
                          MediaQuery.paddingOf(context).top,
                        ),
                    left: AppSpacing.screenHorizontal,
                  ),
                  child: const SizedBox(
                    height: VHeaderMetrics.titleRowHeight,
                    width: double.infinity,
                    child: VHeaderTitleRow(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
