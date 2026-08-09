import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';

class VComingSoonScreen extends StatelessWidget {
  final String title;
  final String description;
  final bool showBackButton;
  final IconData icon;

  const VComingSoonScreen({
    super.key,
    required this.title,
    required this.description,
    this.showBackButton = true,
    this.icon = Icons.construction,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 56, color: Colors.grey[800]),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.comingSoonSoon,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[500]),
                ),
                if (showBackButton) ...[
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: 200,
                    child: VButton.outlined(
                      label: l10n.comingSoonBack,
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
