import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/show_app_error.dart';

/// Q6 report categories surfaced to the user. The wire value is the server
/// `report_category`; the immediate-response lanes (CSAM, NCII, credible
/// threat) are never hidden behind a secondary menu.
class ReportCategory {
  const ReportCategory(this.wire, this.label);

  final String wire;
  final String label;
}

List<ReportCategory> _categories(AppLocalizations l10n) => [
  ReportCategory('harassment', l10n.reportCategoryHarassment),
  ReportCategory('hate', l10n.reportCategoryHate),
  ReportCategory('spam', l10n.reportCategorySpam),
  ReportCategory('impersonation', l10n.reportCategoryImpersonation),
  ReportCategory('ncii', l10n.reportCategoryNcii),
  ReportCategory('credible_threat', l10n.reportCategoryThreat),
  ReportCategory('csam', l10n.reportCategoryCsam),
  ReportCategory('other', l10n.reportCategoryOther),
];

/// Opens the shared report sheet for any UGC target. Returns true when a
/// report was accepted by the server.
///
/// [isMessage] routes through the E2EE-specific `report_message` RPC; pass the
/// decrypted [plaintext] of the exact reported row (the E2EE disclosure
/// exception). Every other surface uses `report_content`.
Future<bool> showReportSheet(
  BuildContext context,
  WidgetRef ref, {
  required String targetType,
  required String targetId,
  String? plaintext,
  bool isMessage = false,
  String? title,
}) async {
  final l10n = AppLocalizations.of(context);
  final category = await showDialog<ReportCategory>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(title ?? l10n.reportTitle),
      children: [
        for (final option in _categories(l10n))
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, option),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(option.label),
            ),
          ),
      ],
    ),
  );
  if (category == null || !context.mounted) return false;

  try {
    final moderation = ref.read(moderationServiceProvider);
    if (isMessage) {
      await moderation.reportMessage(
        targetId,
        category.wire,
        plaintext: plaintext,
        category: category.wire,
      );
    } else {
      await moderation.reportContent(
        targetType,
        targetId,
        category.wire,
        category: category.wire,
      );
    }
    if (!context.mounted) return true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(l10n.reportSent)));
    return true;
  } catch (e) {
    if (context.mounted) showAppError(context, e);
    return false;
  }
}
