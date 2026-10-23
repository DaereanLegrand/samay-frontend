import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Data portability (Ley N° 29733): exports the caller's own data.
///
/// The server (`export_my_data`) returns everything it holds, but chat is E2EE
/// so it can only return ciphertext; readable chat history lives only on the
/// device. The document is copied to the clipboard so the user can save or send
/// it without any third party receiving it first.
class ExportDataScreen extends ConsumerStatefulWidget {
  const ExportDataScreen({super.key});

  @override
  ConsumerState<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends ConsumerState<ExportDataScreen> {
  bool _loading = false;
  String? _json;
  String? _savedPath;

  Future<void> _export() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);
    try {
      final json = await ref.read(authServiceProvider).exportMyData();
      // SEC-050: deliver a file, not clipboard-only. The JSON lives in the
      // app's documents directory where the OS share sheet/backup can reach
      // it; the clipboard copy stays as a convenience.
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
      final file = File('${dir.path}/samay-export-$stamp.json');
      await file.writeAsString(json);
      await Clipboard.setData(ClipboardData(text: json));
      if (!mounted) return;
      setState(() {
        _json = json;
        _savedPath = file.path;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileExportSuccess)));
    } catch (e, st) {
      AppLogger.instance.error('exportMyData error: $e', '$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.profileExportError)));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      body: VHeaderBar(
        title: l10n.profileExportTitle,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                l10n.profileExportBody,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.profileExportChatNote,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.mutedStrong),
              ),
              const SizedBox(height: 24),
              VButton.emphasized(
                label: l10n.profileExportCta,
                onPressed: _loading ? null : _export,
              ),
              if (_savedPath != null) ...[
                const SizedBox(height: 12),
                Text(
                  l10n.profileExportSaved,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.mutedStrong,
                  ),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  _savedPath!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (_json != null) ...[
                const SizedBox(height: 24),
                SelectableText(
                  _json!,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
