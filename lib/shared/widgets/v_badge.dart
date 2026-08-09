import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';

class VBadge extends StatelessWidget {
  final String label;
  final Color? color;

  const VBadge({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color ?? AppColors.white,
        border: Border.all(color: AppColors.white),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color != null ? AppColors.discoBlack : AppColors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
