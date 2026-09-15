import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_network_image.dart';

/// Full-screen image viewer — the shared "pop to visualize" surface
/// (2026-09-15, abstracted from the truth-dare answer preview so every feature
/// reuses one viewer).
///
/// Supply exactly one of [url] (network) or [bytes] (in-memory/local).
/// Pinch and scroll to zoom ([InteractiveViewer]); tap the image anywhere or
/// the close button to dismiss, and the system back gesture closes it too.
Future<void> showFullScreenImage(
  BuildContext context, {
  String? url,
  Uint8List? bytes,
}) {
  assert(url != null || bytes != null, 'showFullScreenImage needs url or bytes');
  return showDialog<void>(
    context: context,
    barrierColor: AppColors.discoBlack,
    builder: (dialogContext) => Dialog(
      backgroundColor: AppColors.discoBlack,
      insetPadding: EdgeInsets.zero,
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            InteractiveViewer(
              minScale: 0.8,
              maxScale: 5,
              child: GestureDetector(
                // A plain tap dismisses; zoom/pan gestures are owned by the
                // InteractiveViewer above.
                onTap: () => Navigator.of(dialogContext).pop(),
                child: url != null
                    ? VNetworkImage(imageUrl: url, fit: BoxFit.contain)
                    : Image.memory(
                        bytes!,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    tooltip: AppLocalizations.of(dialogContext).commonClose,
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
