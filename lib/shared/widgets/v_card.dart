import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';

class VCard extends StatelessWidget {
  final Widget child;

  const VCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.discoBlack,
        border: Border.symmetric(
          horizontal: BorderSide(color: AppColors.border),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      child: child,
    );
  }
}
