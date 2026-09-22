import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/features/minigames/widgets/finished_leaderboard.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The finished-match leaderboard as its own route.
///
/// Full-bleed page whose only chrome is the floating back arrow, wrapping
/// [FinishedLeaderboard]. When [initialParticipantId] is supplied the carousel
/// opens focused on that player, so tapping a row in the finished session
/// detail lands on their card.
class MinigameLeaderboardScreen extends StatelessWidget {
  const MinigameLeaderboardScreen({
    super.key,
    required this.sessionId,
    this.initialParticipantId,
  });

  final String sessionId;
  final String? initialParticipantId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.discoBlack,
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
                  top: VHeaderMetrics.heroTopPad(
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
    );
  }
}
