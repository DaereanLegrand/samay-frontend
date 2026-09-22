import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// The full-bleed image presentation shared by the leaderboard answer pages and
/// the truth/dare answer editor (one implementation).
///
/// An opaque, blurred, vertically-mirrored copy of the picture fills the
/// letterbox bands its `contain` fit leaves open (over-scaled to hide the
/// blur's transparent edge fringe), and the COMPLETE picture is drawn
/// `contain` on top — never cropped, so a landscape photo stays landscape. The
/// widget fills whatever box it is handed.
///
/// [onImageLoaded] fires once the picture's first frame is ready (used by the
/// leaderboard to arm its celebration only after the image has painted).
class MinigameBleedImage extends StatelessWidget {
  const MinigameBleedImage({
    super.key,
    required this.image,
    this.onImageLoaded,
    this.blurSigma = 24,
    this.fillScale = 1.3,
  });

  /// The picture to present (e.g. `MemoryImage` for decoded bytes,
  /// `FileImage` for a picked file).
  final ImageProvider image;

  /// Fires when the picture's first frame is ready (best-effort, once).
  final VoidCallback? onImageLoaded;

  /// Blur sigma of the filling copy.
  final double blurSigma;

  /// Over-scale of the filling copy (hides the blur's transparent edge).
  final double fillScale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Opaque blurred, vertically-mirrored copy so the letterbox bands read
        // as one full-bleed surface.
        ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Transform.scale(
            scale: fillScale,
            child: Transform.flip(
              flipY: true,
              child: Image(
                image: image,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                gaplessPlayback: true,
              ),
            ),
          ),
        ),
        // The complete picture (BoxFit.contain — never cropped).
        Image(
          image: image,
          fit: BoxFit.contain,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          frameBuilder: (context, child, frame, syncLoaded) {
            if ((frame != null || syncLoaded) && onImageLoaded != null) {
              final cb = onImageLoaded!;
              WidgetsBinding.instance.addPostFrameCallback((_) => cb());
            }
            return child;
          },
        ),
      ],
    );
  }
}
