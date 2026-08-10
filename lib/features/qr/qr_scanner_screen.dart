import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/permission_service.dart';
import 'package:samay/features/events/events_providers.dart';
import 'package:samay/features/qr/qr_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';

/// Camera-widget seam for tests: `mobile_scanner` is a platform plugin that
/// cannot run in widget tests, so the screen accepts an injectable builder
/// (same thin-wrapper pattern as `CreateEventScreen`/`PermissionService`).
/// The builder receives the on-detect callback and returns the camera widget.
typedef QrScannerViewBuilder = Widget Function({
  required ValueChanged<String> onDetect,
});

enum _CameraStatus { checking, granted, denied, unavailable }

/// Result banner state after a scan attempt.
sealed class _ScanResult {
  const _ScanResult();
}

class _Processing extends _ScanResult {
  const _Processing();
}

class _Confirmed extends _ScanResult {
  const _Confirmed(this.attendeeName);

  final String? attendeeName;
}

class _ScanError extends _ScanResult {
  const _ScanError(this.message, {required this.retryable});

  final String message;

  /// Network/server failures keep the banner with a retry button; business
  /// rejections (expired/already scanned/…) auto-clear after ~2s.
  final bool retryable;
}

/// QRSC — promotor/co_promotor attendance QR scanner.
///
/// Full-screen camera via `mobile_scanner`, white scan-frame overlay,
/// promotor event name and "Escanea el código QR del asistente" hint (QRSC
/// §Scanner Screen). Camera access goes through [PermissionService]
/// (`Permission.camera`) with the rationale/settings UX; the torch toggle is
/// an overlay action (mission extension of QRSC's "no torch" note — phone
/// screens don't glare, the toggle is off by default).
///
/// On scan: `EventService.validateQrToken(eventId, token)` (the
/// `validate_qr_token` RPC — migration 20260809000005, the SQL stand-in for
/// the blocked `validate-attendance` Edge Function). Confirmed → ✓ animation
/// + attendee name, "Listo" after ~2s, scanner returns to ready. Business
/// rejections show the QRSC-spec copy and auto-clear. A missing/unreachable
/// RPC (PGRST202 — EEDG not deployed) shows a retryable network error.
///
/// Route: `/scanner/:eventId` (feature-flag gated on `AppFeatureFlag.qr`).
class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({
    super.key,
    required this.eventId,
    this.permissions,
    this.scannerBuilder,
  });

  final String eventId;

  /// Injectable for tests (SEC-07); defaults to the real service.
  final PermissionService? permissions;

  /// Injectable for tests; defaults to the real `mobile_scanner` widget.
  final QrScannerViewBuilder? scannerBuilder;

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen> {
  late final PermissionService _permissions =
      widget.permissions ?? PermissionService();

  _CameraStatus _cameraStatus = _CameraStatus.checking;
  MobileScannerController? _scannerController;
  bool _torchOn = false;
  bool _scanning = false;
  String? _lastToken;
  _ScanResult? _result;
  Timer? _resultTimer;

  @override
  void initState() {
    super.initState();
    _requestCamera();
  }

  @override
  void dispose() {
    _resultTimer?.cancel();
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _requestCamera() async {
    setState(() => _cameraStatus = _CameraStatus.checking);
    try {
      final outcome = await _permissions.ensure(Permission.camera);
      if (!mounted) return;
      if (outcome == PermissionOutcome.granted) {
        _startScanner();
        return;
      }
      // Localizations is read after the first await — never synchronously in
      // the initState path (dependOnInheritedWidget guard).
      final l10n = AppLocalizations.of(context);
      // Requestable deny → rationale snackbar; permanent deny → settings
      // dialog (PermissionService's full UX, SEC-07).
      await _permissions.ensureWithPrompt(
        context,
        permission: Permission.camera,
        rationale: l10n.permissionsCameraRationale,
        settingsTitle: l10n.qrCameraSettingsTitle,
        settingsBody: l10n.qrCameraSettingsBody,
        settingsAction: l10n.qrCameraSettingsAction,
        cancelAction: l10n.commonCancel,
      );
      if (!mounted) return;
      setState(() => _cameraStatus = _CameraStatus.denied);
    } catch (e, st) {
      // Permission plugins cannot run in every environment (tests, desktop);
      // surface the retryable unavailable panel instead of crashing.
      AppLogger.instance.error('qr scanner camera permission: $e', '$st');
      if (!mounted) return;
      setState(() => _cameraStatus = _CameraStatus.unavailable);
    }
  }

  void _startScanner() {
    final controller = MobileScannerController();
    setState(() {
      _cameraStatus = _CameraStatus.granted;
      _scannerController = controller;
    });
  }

  Future<void> _toggleTorch() async {
    final controller = _scannerController;
    if (controller == null) return;
    try {
      await controller.toggleTorch();
      if (mounted) setState(() => _torchOn = !_torchOn);
    } catch (_) {
      // Torch unsupported on this device/camera — the toggle stays off.
    }
  }

  /// Auto-return to the ready state (QRSC success flow: "Listo" after ~2s).
  void _scheduleReady() {
    _resultTimer?.cancel();
    _resultTimer = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() {
        _result = null;
        _scanning = false;
      });
    });
  }

  void _onScan(String token) {
    final l10n = AppLocalizations.of(context);
    if (_scanning) return;
    if (token.isEmpty) return;
    _lastToken = token;
    _scanning = true;
    setState(() => _result = const _Processing());

    // Fire-and-forget: the async continuation re-checks `mounted` and the
    // result state; the banner UI is driven by `_result`.
    _validate(token, l10n);
  }

  Future<void> _validate(String token, AppLocalizations l10n) async {
    try {
      final data = await ref
          .read(eventServiceProvider)
          .validateQrToken(widget.eventId, token);
      if (!mounted) return;
      final outcome = qrScanResultFromMap(data);
      switch (outcome) {
        case QrScanResult.confirmed:
          setState(() => _result = _Confirmed(data['attendeeName'] as String?));
          _scheduleReady();
        case QrScanResult.expired:
          setState(() => _result = _ScanError(l10n.qrScanExpired, retryable: false));
          _scheduleReady();
        case QrScanResult.alreadyScanned:
          setState(() => _result = _ScanError(l10n.qrScanAlreadyScanned, retryable: false));
          _scheduleReady();
        case QrScanResult.notInvited:
          setState(() => _result = _ScanError(l10n.qrScanNotInvited, retryable: false));
          _scheduleReady();
        case QrScanResult.notInWindow:
          setState(() => _result = _ScanError(l10n.qrScanNotInWindow, retryable: false));
          _scheduleReady();
        case QrScanResult.notPromotor:
          setState(() => _result = _ScanError(l10n.qrScanNotPromotor, retryable: false));
          _scheduleReady();
        case QrScanResult.invalidToken:
          setState(() => _result = _ScanError(l10n.qrScanInvalidToken, retryable: false));
          _scheduleReady();
      }
    } catch (e, st) {
      // RPC missing (PGRST202 — EEDG not deployed) or transport failure:
      // keep the retryable banner until the user retries or taps away.
      AppLogger.instance.error('validateQrToken error: $e', '$st');
      if (!mounted) return;
      setState(() {
        _scanning = false;
        _result = _ScanError(l10n.qrScanNetworkError, retryable: true);
      });
    }
  }

  void _retryLastScan() {
    final token = _lastToken;
    if (token != null) _onScan(token);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final eventName =
        eventAsync.valueOrNull?['name'] as String? ?? l10n.qrScanEventFallback;

    return Scaffold(
      backgroundColor: AppColors.discoBlack,
      appBar: AppBar(
        title: Text(l10n.qrScannerTitle),
        actions: [
          if (_cameraStatus == _CameraStatus.granted)
            IconButton(
              tooltip: _torchOn ? l10n.qrTorchOff : l10n.qrTorchOn,
              icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
              onPressed: _toggleTorch,
            ),
        ],
      ),
      body: SafeArea(child: _body(l10n, eventName)),
    );
  }

  Widget _body(AppLocalizations l10n, String eventName) {
    switch (_cameraStatus) {
      case _CameraStatus.checking:
        return const Center(child: CircularProgressIndicator());
      case _CameraStatus.unavailable:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.no_photography_outlined,
                    size: 48, color: AppColors.border),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.qrCameraUnavailable,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.qrCameraUnavailableBody,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.mutedStrong)),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 200,
                  child: VButton(
                    label: l10n.commonRetry,
                    onPressed: _requestCamera,
                  ),
                ),
              ],
            ),
          ),
        );
      case _CameraStatus.denied:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.photo_camera_outlined,
                    size: 48, color: AppColors.border),
                const SizedBox(height: AppSpacing.lg),
                Text(l10n.qrCameraDenied,
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: 200,
                  child: VButton(
                    label: l10n.commonRetry,
                    onPressed: _requestCamera,
                  ),
                ),
              ],
            ),
          ),
        );
      case _CameraStatus.granted:
        return Stack(
          fit: StackFit.expand,
          children: [
            widget.scannerBuilder != null
                ? widget.scannerBuilder!(onDetect: _onScan)
                : MobileScanner(
                    controller: _scannerController,
                    onDetect: (capture) {
                      for (final barcode in capture.barcodes) {
                        final raw = barcode.rawValue;
                        if (raw != null && raw.isNotEmpty) {
                          _onScan(raw);
                          return;
                        }
                      }
                    },
                    errorBuilder: (context, error, child) => _cameraError(l10n),
                  ),
            // Scan frame + prompts (QRSC overlay spec).
            IgnorePointer(
              child: Center(
                child: CustomPaint(
                  size: const Size(280, 280),
                  painter: const _ScanFramePainter(),
                ),
              ),
            ),
            Positioned(
              top: AppSpacing.lg,
              left: AppSpacing.lg,
              right: AppSpacing.lg,
              child: Column(
                children: [
                  Text(
                    l10n.qrScanEventName(eventName),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.qrScanPrompt,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.mutedStrong),
                  ),
                ],
              ),
            ),
            if (_result != null) _resultBanner(l10n, _result!),
          ],
        );
    }
  }

  Widget _cameraError(AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(l10n.qrCameraUnavailable,
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.lg),
            VButton(label: l10n.commonRetry, onPressed: _requestCamera),
          ],
        ),
      ),
    );
  }

  Widget _resultBanner(AppLocalizations l10n, _ScanResult result) {
    return Positioned(
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      bottom: AppSpacing.xxxl,
      child: switch (result) {
        _Processing() => Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.surfaceAlt,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(l10n.qrScanProcessing,
                    style: const TextStyle(color: AppColors.white)),
              ],
            ),
          ),
        _Confirmed(attendeeName: final name) => Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            color: AppColors.discoBlack,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle,
                    size: 48, color: AppColors.discoCyan),
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.qrScanConfirmed,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    )),
                if (name != null && name.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.qrScanAttendee(name),
                    style: const TextStyle(color: AppColors.mutedStrong),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(l10n.qrScanReady,
                    style: const TextStyle(color: AppColors.mutedStrong)),
              ],
            ),
          ),
        _ScanError(message: final message, retryable: final retryable) =>
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            color: AppColors.discoBlack,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.glowPink,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (retryable) ...[
                  const SizedBox(height: AppSpacing.md),
                  VButton(
                    // Reuses commonRetry ('Reintentar'/'Retry' — same copy
                    // the QRSC spec requires): avoids a new ARB key while the
                    // ARB pair is contended by other agents (I-60/I-61/I-62).
                    label: l10n.commonRetry,
                    onPressed: _retryLastScan,
                  ),
                ],
              ],
            ),
          ),
      },
    );
  }
}

/// White scan-frame guide (QRSC: white outline, corner brackets).
class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.white;
    const corner = 40.0;
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawPath(_cornerPath(r, corner), paint);
  }

  Path _cornerPath(Rect r, double c) {
    return Path()
      ..moveTo(r.left, r.top + c)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + c, r.top)
      ..moveTo(r.right - c, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + c)
      ..moveTo(r.right, r.bottom - c)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - c, r.bottom)
      ..moveTo(r.left + c, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - c);
  }

  @override
  bool shouldRepaint(_ScanFramePainter oldDelegate) => false;
}
