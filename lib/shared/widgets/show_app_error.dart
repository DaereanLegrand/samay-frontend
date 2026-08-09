import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/l10n/app_localizations.dart';

/// One consistent error-presentation pattern.
///
/// Maps [error] through `error.toAppError()` and surfaces the user-facing
/// message as a SnackBar (transient) or an AlertDialog (blocking).
Future<void> showAppError(
  BuildContext context,
  Object error, {
  String? fallback,
  bool blocking = false,
}) async {
  final l10n = AppLocalizations.of(context);
  final mapped = error.toAppError().message.trim();
  final message = mapped.isNotEmpty ? mapped : (fallback ?? l10n.errorsGeneric);
  if (!context.mounted) return;

  if (blocking) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.discoBlack,
        title: Text(l10n.commonError, style: const TextStyle(color: AppColors.white)),
        content: Text(
          message,
          style: const TextStyle(color: AppColors.mutedStrong),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.commonOk, style: const TextStyle(color: AppColors.white)),
          ),
        ],
      ),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.discoBlack,
        behavior: SnackBarBehavior.floating,
        content: Row(
          children: [
            const Icon(Icons.error_outline, size: 18, color: AppColors.glowPink),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: AppColors.white, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// SnackBar-only variant of [showAppError] for transient contexts.
Future<void> showErrorSnackBar(
  BuildContext context,
  Object error, {
  String? fallback,
}) {
  return showAppError(context, error, fallback: fallback);
}
