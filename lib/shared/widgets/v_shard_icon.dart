import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_icon_sizes.dart';

class VShardIcon extends StatelessWidget {
  final double size;

  const VShardIcon({super.key, this.size = AppIconSizes.sm});

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.diamond,
      color: AppColors.white,
      size: size,
    );
  }
}
