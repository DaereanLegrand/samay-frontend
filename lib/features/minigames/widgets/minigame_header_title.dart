import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';

/// A rich two-line title for the minigame play screen's [VHeaderBar].
///
/// Line 1 is the current-context phrase during a match — e.g. Spanish
/// "turno de {name}" or English "{name}'s turn" — rendered as ONE Playfair
/// Display line at a single size: the [prefix]/[suffix] words ("turno de",
/// "'s") in the muted grey and the [name] in full white. When there is no
/// [name] (standalone statuses like "respondiendo", "esperando…", "error",
/// "clasificación") [word] renders line 1 as a single Playfair Display word.
///
/// Line 2 ([secondary]) is the small lowercase minigame name (Inter, muted),
/// tucked tight under line 1. Both lines are LEFT-aligned to match the plain
/// title's x-position in the bar.
///
/// Everything lives INSIDE the bar's fixed-height title row — the total bar
/// height is unchanged by construction ([VHeaderBar.barHeight]); this widget
/// only sizes its own text to fit. Long content scales down ([FittedBox]) so
/// it never overflows the row or under the trailing actions.
class MinigameHeaderTitle extends StatelessWidget {
  const MinigameHeaderTitle({
    super.key,
    this.word,
    this.prefix,
    this.name,
    this.suffix,
    this.secondary,
  });

  /// A standalone word for line 1 (no [name]) — e.g. the play statuses. When
  /// [name] is given, [word] is ignored.
  final String? word;

  /// Muted words BEFORE the white [name] ("turno de " / "de ").
  final String? prefix;

  /// The white name (username/alias) — same size as the muted [prefix]/[suffix].
  final String? name;

  /// Muted words AFTER the white [name] ("'s turn").
  final String? suffix;

  /// The small line-2 text (the lowercase minigame name). Null renders a
  /// single-line title.
  final String? secondary;

  bool get _hasName => name != null && name!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final Widget line1 = _hasName
        ? _PhraseLine(prefix: prefix, name: name!, suffix: suffix)
        : _WordLine(word: word ?? '');

    final sub = secondary;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line1,
          if (sub != null && sub.isNotEmpty) ...[
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.inter,
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
                height: 1.0,
                color: AppColors.mutedStrong,
                shadows: AppTypography.legibilityShadows,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The line-1 glyph size shared by every word of the phrase and the status
/// words.
const double _lineSize = 24;

/// One line: muted [prefix] + white [name] + muted [suffix], all the SAME
/// Playfair Display size, no outline. Scale-down-fitted so it never overflows
/// the bar's Expanded title slot.
class _PhraseLine extends StatelessWidget {
  const _PhraseLine({required this.prefix, required this.name, this.suffix});

  final String? prefix;
  final String name;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final lead = prefix;
    final trail = suffix;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        maxLines: 1,
        softWrap: false,
        TextSpan(
          style: const TextStyle(
            fontFamily: AppTypography.playfair,
            fontSize: _lineSize,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
            height: 1.0,
            shadows: AppTypography.legibilityShadows,
          ),
          children: [
            if (lead != null && lead.isNotEmpty)
              TextSpan(
                text: lead,
                style: const TextStyle(color: AppColors.softGray),
              ),
            TextSpan(
              text: name,
              style: const TextStyle(color: AppColors.white),
            ),
            if (trail != null && trail.isNotEmpty)
              TextSpan(
                text: trail,
                style: const TextStyle(color: AppColors.muted),
              ),
          ],
        ),
      ),
    );
  }
}

/// A standalone display word (Playfair white) — used for the status lines and
/// the minigame-name fallback.
class _WordLine extends StatelessWidget {
  const _WordLine({required this.word});

  final String word;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        word,
        maxLines: 1,
        softWrap: false,
        style: const TextStyle(
          fontFamily: AppTypography.playfair,
          fontSize: _lineSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
          height: 1.0,
          color: AppColors.white,
          shadows: AppTypography.legibilityShadows,
        ),
      ),
    );
  }
}
