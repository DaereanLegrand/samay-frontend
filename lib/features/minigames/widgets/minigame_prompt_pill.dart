import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_radius.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/features/minigames/logic/truth_dare.dart';
import 'package:samay/l10n/app_localizations.dart';

/// The prompt's display size (slightly above the 20px `headlineSmall` base) and
/// its `5em` corner radius — larger than the pill's own height, so the
/// hug-to-text panel renders as a pill.
const double _promptPillFontSize = 22;
const double _promptPillRadius = 5 * _promptPillFontSize;

/// The prompt's soft backdrop: stacked blurs of the SAME pill, each wider and
/// fainter than the last — `(sigma, alpha)` — so the darkness is strong right
/// behind the text and diffuses progressively into the page with no boundary.
///
/// Why blurs of the shape and not `BoxShadow`: a shadow is cast by an opaque
/// silhouette, so it always keeps a visible edge no matter how large the blur
/// or spread. Feathering the shape ITSELF (each layer is a blurred pill) melts
/// the edge; the successive sigmas give the eased "strong at the start,
/// diffusing more and more" falloff.
///
/// The outer alphas are deliberately HIGH (darker tint) so the pill keeps the
/// prompt legible even over a LIGHT full-bleed picture.
const List<(double sigma, double alpha)> _promptPillLayers = [(36, 0.85)];

/// The current prompt — a Verdad question or a Reto challenge, prefixed by its
/// kind label on its own line (`Reto:\n…`) — on a soft black pill so it stays
/// legible over a full-bleed picture.
///
/// Hugs the text (centered); the pill melts into the background via
/// [_promptPillLayers]. Quicksand w600 at [_promptPillFontSize]. The ONE
/// implementation shared by the multi-device play screen and the pass-the-phone
/// round card.
class MinigamePromptPill extends StatelessWidget {
  const MinigamePromptPill({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        // The blurs bleed past the pill — never clip them.
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          for (final (sigma, alpha) in _promptPillLayers)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.palette.background.withValues(alpha: alpha),
                    borderRadius: const BorderRadius.all(
                      Radius.circular(_promptPillRadius),
                    ),
                  ),
                ),
              ),
            ),
          // The label sizes the stack; the blurred layers fill its padded box.
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Text(
              text,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontFamily: AppTypography.quicksand,
                fontSize: _promptPillFontSize,
                fontWeight: FontWeight.w600,
                // Lighter-tinted glyph shadow (a soft light halo) so the prompt
                // glows against the darker pill.
                shadows: [
                  Shadow(
                    color: context.palette.background.withValues(alpha: 1),
                    blurRadius: 50,
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

/// The pill's text for a truth-or-dare prompt: the localized kind label on its
/// own line, then the body (`Verdad:\n…` / `Reto:\n…`). A missing/unknown kind
/// renders the bare body, so a prompt-less game still uses the same pill.
String minigamePromptPillText(
  AppLocalizations l10n, {
  required String body,
  String? promptType,
}) => truthDarePromptDisplay(
  l10n,
  body: body,
  kind: truthDareKindFromWire(promptType),
);

/// The round's prompt as a card: the kind label (`VERDAD` / `RETO`) over the
/// body, on the sanctioned rounded card surface (`AppRadius.card`, the same
/// shell the 2 Lies statements use) with the play voice (Quicksand).
///
/// Use this whenever the prompt sits on a plain page (pass-the-phone play);
/// [MinigamePromptPill] is for a prompt over a full-bleed picture, where the
/// card chrome would fight the image.
class MinigamePromptCard extends StatelessWidget {
  const MinigamePromptCard({
    super.key,
    required this.body,
    this.promptType,
    this.trailing,
  });

  final String body;

  /// The wire prompt type (`verdad` / `reto`); null renders the bare body.
  final String? promptType;

  /// Optional footer inside the card (e.g. the subject's name).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final kind = truthDareKindFromWire(promptType);
    final label = kind == null ? null : truthDareKindLabel(l10n, kind);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxxl,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      decoration: BoxDecoration(
        color: context.palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: context.palette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null) ...[
            Text(
              label.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppTypography.labelSmall.copyWith(
                color: context.palette.mutedForeground,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Text(
            body,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontFamily: AppTypography.quicksand,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(height: AppSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
