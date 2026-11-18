import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/extensions/error_mapper.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/services/minigame_service.dart';
import 'package:samay/core/theme/app_palette_context.dart';
import 'package:samay/features/minigames/screens/minigames_screen.dart'
    show minigameRejectionMessage;
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// The codes a partida QR can carry.
///
/// The lobby renders `samay://join/<CODE>`; the scanner also accepts a bare
/// 6-character code so a screenshot or a handwritten code still works.
final RegExp _codePattern = RegExp(r'^[ABCDEFGHJKMNPQRSTUVWXYZ23456789]{6}$');

String? extractJoinCode(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final direct = trimmed.toUpperCase();
  if (_codePattern.hasMatch(direct)) return direct;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.scheme.isNotEmpty && uri.host.toLowerCase() == 'join') {
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      final candidate = segments.first.toUpperCase();
      if (_codePattern.hasMatch(candidate)) return candidate;
    }
  }
  return null;
}

/// QR join for a multi-device partida.
///
/// Scanning calls `join_minigame_by_code` (the same RPC the manual 6-character
/// entry uses, with its per-account rate limit) and pushes the lobby on
/// success. There is no preview and no automatic join: the scan IS the explicit
/// action.
class JoinScannerScreen extends ConsumerStatefulWidget {
  const JoinScannerScreen({super.key});

  @override
  ConsumerState<JoinScannerScreen> createState() => _JoinScannerScreenState();
}

class _JoinScannerScreenState extends ConsumerState<JoinScannerScreen> {
  bool _busy = false;

  Future<void> _onDetect(String raw) async {
    if (_busy) return;
    final code = extractJoinCode(raw);
    if (code == null) return;
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      final sessionId = await ref
          .read(minigameServiceProvider)
          .joinByCode(code);
      if (!mounted) return;
      context.pushReplacement(RoutePaths.minigameSession(sessionId));
    } on MinigameSessionRejectedException catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(minigameRejectionMessage(l10n, e.rejection))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toAppError().message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.palette.background,
      body: VHeaderBar(
        titleWidget: VDisplayText(text: l10n.minigamesJoinCodeTitle),
        child: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              onDetect: (capture) {
                for (final barcode in capture.barcodes) {
                  final raw = barcode.rawValue;
                  if (raw != null && raw.isNotEmpty) {
                    _onDetect(raw);
                    return;
                  }
                }
              },
              errorBuilder: (context, error) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text(
                    l10n.qrCameraUnavailable,
                    textAlign: TextAlign.center,
                    style: AppTypography.bodyLarge.copyWith(
                      color: context.palette.mutedForeground,
                    ),
                  ),
                ),
              ),
            ),
            if (_busy)
              ColoredBox(
                color: context.palette.background.withValues(alpha: 0.7),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
