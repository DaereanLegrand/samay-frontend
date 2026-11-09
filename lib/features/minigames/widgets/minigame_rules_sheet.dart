import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/features/minigames/logic/minigame_meta.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/core/theme/app_palette_context.dart';

/// "Cómo se juega" for any minigame — the numbered-steps panel Charadas
/// carried on its starter screen, lifted out so every game has the same one.
///
/// The complaint it answers: only Verdad o Reto read clearly mid-play. The
/// others dropped you into a board with no statement of the rules, so a
/// player who had not been told the game out loud had to guess. Rather than
/// bolt a different explainer onto each screen, every play screen now shows
/// the same "?" action in its header and opens this sheet, and a new game
/// only has to add its steps to [MinigameRules.rules].
Future<void> showMinigameRules(BuildContext context, MinigameType type) {
  final l10n = AppLocalizations.of(context);
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.palette.surface,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.card)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.minigamesRulesTitle,
              style: Theme.of(sheetContext).textTheme.headlineSmall?.copyWith(
                    color: context.palette.foreground,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              type.tagline(l10n),
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: context.palette.mutedForeground,
                  ),
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final (i, step) in type.rules(l10n).indexed) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              _Step(number: i + 1, text: step),
            ],
          ],
        ),
      ),
    ),
  );
}

/// The header action that opens [showMinigameRules].
class MinigameRulesButton extends StatelessWidget {
  const MinigameRulesButton({super.key, required this.type});

  final MinigameType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return IconButton(
      icon: const Icon(Icons.help_outline, size: 22),
      color: context.palette.foreground,
      tooltip: l10n.minigamesRulesAction,
      onPressed: () => showMinigameRules(context, type),
    );
  }
}

/// One numbered step: the circled index and its sentence.
class _Step extends StatelessWidget {
  const _Step({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: context.palette.surfaceAlt,
          ),
          child: Text(
            '$number',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: context.palette.foreground,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.softGray,
                ),
          ),
        ),
      ],
    );
  }
}
