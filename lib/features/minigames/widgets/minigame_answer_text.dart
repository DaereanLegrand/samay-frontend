import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';

/// Renders an answer's text at its stored normalized [layout] inside whatever
/// canvas it is given (center-anchored, rotated, font-scaled).
///
/// The read-side counterpart of the author's floating editor label (2026-09-15
/// directive): the same [MinigameAnswerLayout] the author arranged, so every
/// participant and the finished leaderboard see the placement identically.
class MinigameAnswerText extends StatelessWidget {
  const MinigameAnswerText({
    super.key,
    required this.text,
    required this.layout,
    this.fontSize = 20,
    this.maxLines = 6,
  });

  final String text;
  final MinigameAnswerLayout layout;
  final double fontSize;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvas = Size(constraints.maxWidth, constraints.maxHeight);
        if (canvas.isEmpty) return const SizedBox.shrink();
        return Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              left: layout.x * canvas.width,
              top: layout.y * canvas.height,
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: Transform.rotate(
                  angle: layout.rotation,
                  child: Transform.scale(
                    scale: layout.scale,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: canvas.width * 0.9),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        maxLines: maxLines,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: AppTypography.quicksand,
                          fontSize: fontSize,
                          height: 1.4,
                          letterSpacing: 1.1,
                          color: AppColors.white,
                          shadows: AppTypography.legibilityShadows,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
