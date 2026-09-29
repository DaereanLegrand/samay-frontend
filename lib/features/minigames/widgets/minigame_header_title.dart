import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// A rich two-line title for the minigame play screen's [VHeaderBar].
///
/// Line 1 is the current-context phrase during a match — e.g. Spanish
/// "turno de {name}" or English "{name}'s turn" — rendered as ONE Playfair
/// Display line at a single size, all in the app's flat white display voice
/// with the shared legibility shadow. When there is no [name] (standalone
/// statuses like "respondiendo", "esperando…", "error", "clasificación")
/// [word] renders line 1 as a single Playfair Display word.
///
/// Line 2 ([secondary]) is the small lowercase minigame name (Inter, muted),
/// tucked tight under line 1. Both lines are LEFT-aligned to match the plain
/// title's x-position in the bar.
///
/// Everything lives INSIDE the bar's fixed-height title row — the total bar
/// height is unchanged by construction ([VHeaderBar.barHeight]); this widget
/// only sizes its own text to fit. Long content scales down ([FittedBox]) so
/// it never overflows the row or under the trailing actions.
///
/// Optical centerline: line 1's reference band is landed on [VHeaderMetrics]'
/// shared centerline (the same one the back arrow and the plain [VDisplayText]
/// title use) via [VHeaderMetrics.opticalShiftFor], with line 2 tucked directly
/// under it — so every header element reads on ONE line. Rationale:
/// `docs/history/phase-16/2026-09-11_header-optical-alignment.md`.
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
    final line1Style = VDisplayText.styleFor(
      _lineSize,
    ); // 24px Playfair w700, height 1.0 — same metrics as the rendered lines
    final shift = VHeaderMetrics.opticalShiftFor(context, line1Style);
    const double lineGap = 2;
    const double secondaryHeight = 11; // line-2 style height at fontSize 11
    final hasLine2 = sub != null && sub.isNotEmpty;
    final double ty = hasLine2 ? shift + (lineGap + secondaryHeight) / 2 : shift;
    return Transform.translate(
      offset: Offset(0, ty),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          line1,
          if (hasLine2) ...[
            const SizedBox(height: lineGap),
            Text(
              sub,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppTypography.inter,
                fontSize: 12,
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

/// One line: [prefix] + [name] + [suffix], all the SAME Playfair Display size
/// and the SAME flat white as the app's display voice ([VDisplayText] /
/// `_WordLine`), with the shared legibility shadow. Scale-down-fitted so it
/// never overflows the bar's Expanded title slot.
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
            color: AppColors.white,
            shadows: AppTypography.legibilityShadows,
          ),
          children: [
            if (lead != null && lead.isNotEmpty) TextSpan(text: lead),
            TextSpan(text: name),
            if (trail != null && trail.isNotEmpty) TextSpan(text: trail),
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
