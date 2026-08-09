import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';

/// Fallback screen for unrecoverable routing failures: unknown routes,
/// missing path parameters, and invalid navigation extras (findings NAV-03 /
/// NAV-04 / NAV-06 / H-03 / H-04 / M-08). Never crashes — the "Volver" button
/// pops back to the previous flow step when one exists.
class RouteErrorScreen extends StatelessWidget {
  final String? title;
  final String? message;

  const RouteErrorScreen({
    super.key,
    this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title ?? l10n.routerErrorTitle)),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 56, color: Colors.grey),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  message ?? l10n.routerErrorBody,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 200,
                  child: VButton.outlined(
                    label: l10n.commonBack,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
