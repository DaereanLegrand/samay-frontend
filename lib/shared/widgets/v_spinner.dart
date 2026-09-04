import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';

/// Loading spinner that honors the reduced-motion contract.
///
/// Under OS-level reduced motion (`MediaQuery.disableAnimationsOf` — the
/// app-wide forced override was removed 2026-09-03), the spinner renders a
/// STATIC ring instead of the rotating [CircularProgressIndicator] — no
/// indeterminate motion.
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
