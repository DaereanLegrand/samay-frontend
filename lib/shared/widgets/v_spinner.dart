import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';

/// Loading spinner that honors the app-wide reduced-motion contract.
///
/// ANIM-OFF (2026-08-14): with `disableAnimations` set (the app forces it in
/// `SamayApp`), the spinner renders a STATIC ring instead of the rotating
/// [CircularProgressIndicator] — no indeterminate motion anywhere.
///
/// Outside reduced motion it is a plain white [CircularProgressIndicator]
/// (white is the loading voice — see [VLoadingView]; the theme default
/// `progressIndicatorTheme` matches).
class VSpinner extends StatelessWidget {
  final double size;
  final double strokeWidth;
  final Color color;

  const VSpinner({
    super.key,
    this.size = 16,
    this.strokeWidth = 2,
    this.color = AppColors.white,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: strokeWidth),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: strokeWidth, color: color),
    );
  }
}
