import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/features/minigames/logic/minigame_engine.dart';

/// The centered `BoxFit.contain` rect an image of [imageSize] occupies inside
/// [box] — the SHARED reference space for an on-canvas [MinigameAnswerLayout].
///
/// The answer text is authored and replayed relative to the PICTURE, not to
/// whatever widget canvas happens to render it, so a placement made in the
/// editor lands on the same part of the image on every device and in every
/// surface (play reaction window + finished leaderboard). Falls back to the
/// whole [box] for text-only answers (unknown image size), which keeps them
/// viewport-relative and therefore also consistent across devices.
Rect minigameImageRect(Size? imageSize, Size box) {
  if (imageSize == null || imageSize.isEmpty || box.isEmpty) {
    return Offset.zero & box;
  }
  final fitted = applyBoxFit(BoxFit.contain, imageSize, box);
  return Alignment.center.inscribe(fitted.destination, Offset.zero & box);
}

/// Renders an answer's text at its stored normalized [layout] inside whatever
/// canvas it is given (center-anchored, rotated, font-scaled).
///
/// The read-side counterpart of the author's floating editor label (2026-09-15
/// directive): the same [MinigameAnswerLayout] the author arranged, so every
/// participant and the finished leaderboard see the placement identically.
///
/// Pass [image] for picture answers: the layout is then normalized to the
/// picture's displayed rect ([minigameImageRect]), so the placement is
/// image-aligned across devices (2026-09-17). Text escaping the canvas is
/// clipped to it.
class MinigameAnswerText extends StatefulWidget {
  const MinigameAnswerText({
    super.key,
    required this.text,
    required this.layout,
    this.image,
    this.fontSize = 20,
    this.maxLines = 6,
  });

  final String text;
  final MinigameAnswerLayout layout;

  /// The answer picture the layout is anchored to (null → text-only, anchored
  /// to the full canvas/viewport).
  final ImageProvider? image;

  final double fontSize;
  final int maxLines;

  @override
  State<MinigameAnswerText> createState() => _MinigameAnswerTextState();
}

class _MinigameAnswerTextState extends State<MinigameAnswerText> {
  ImageStream? _stream;
  ImageStreamListener? _listener;
  Size? _imageSize;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant MinigameAnswerText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image != widget.image) _resolve();
  }

  void _resolve() {
    final image = widget.image;
    final stream = image?.resolve(createLocalImageConfiguration(context));
    if (stream?.key == _stream?.key) return;
    if (_listener != null) _stream?.removeListener(_listener!);
    _stream = stream;
    _listener = null;
    if (stream == null) {
      if (_imageSize != null) setState(() => _imageSize = null);
      return;
    }
    _listener = ImageStreamListener((info, _) {
      final size = Size(
        info.image.width.toDouble(),
        info.image.height.toDouble(),
      );
      if (mounted && size != _imageSize) setState(() => _imageSize = size);
    });
    stream.addListener(_listener!);
  }

  @override
  void dispose() {
    if (_listener != null) _stream?.removeListener(_listener!);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final canvas = Size(constraints.maxWidth, constraints.maxHeight);
        if (canvas.isEmpty) return const SizedBox.shrink();
        // The picture's displayed rect is the layout's reference space.
        final ref = minigameImageRect(_imageSize, canvas);
        final layout = widget.layout;
        return ClipRect(
          child: Stack(
            // The text may be rotated/scaled past the reference rect — let it
            // paint, then clip at the canvas (the device viewport).
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              Positioned(
                left: ref.left + layout.x * ref.width,
                top: ref.top + layout.y * ref.height,
                child: FractionalTranslation(
                  translation: const Offset(-0.5, -0.5),
                  child: Transform.rotate(
                    angle: layout.rotation,
                    child: Transform.scale(
                      scale: layout.scale,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: ref.width * 0.9),
                        child: Text(
                          widget.text,
                          textAlign: TextAlign.center,
                          maxLines: widget.maxLines,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: AppTypography.quicksand,
                            fontSize: widget.fontSize,
                            fontWeight: FontWeight.w600,
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
          ),
        );
      },
    );
  }
}
