import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_gradients.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/core/services/permission_service.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/qr/providers/qr_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_spinner.dart';

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

/// LUXE v2 family for this screen — **cyan** (ORCHESTRATION-LUXE map:
/// attendance_qr + qr_scanner → cyan).
final AppGradient _family = AppGradients.familyOf('qr');

/// QRSC — promotor/co_promotor attendance QR scanner.
///
/// Full-screen camera via `mobile_scanner`, white scan-frame overlay with the
/// **cyan gradient scan line**, promotor event name and "Escanea el código QR
/// del asistente" hint (QRSC §Scanner Screen). Camera access goes through
/// [PermissionService] (`Permission.camera`) with the rationale/settings UX;
/// the torch toggle is an overlay action (mission extension of QRSC's "no
/// torch" note — phone screens don't glare, the toggle is off by default).
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

  /// The mobile_scanner `errorBuilder` panel (runtime camera failure — the
  /// camera widget itself replaces its view with this). U-25: the hand-rolled
  /// title+button column (which predated U-21's permission panels) now renders
  /// the same §5.9 [VEmptyView] the `unavailable`/`denied` states use — icon,
  /// title, body and the outlined retry — so the three camera-failure faces
  /// are one canonical widget. Static + [visibleForTesting] because the
  /// mobile_scanner plugin's errorBuilder only fires on a device; the widget
  /// test mounts the panel directly.
  @visibleForTesting
  static Widget cameraErrorPanel(AppLocalizations l10n, VoidCallback onRetry) {
    return VEmptyView(
      icon: Icons.no_photography_outlined,
      title: l10n.qrCameraUnavailable,
      description: l10n.qrCameraUnavailableBody,
      actionLabel: l10n.commonRetry,
      onAction: onRetry,
    );
  }

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
        eventAsync.valueOrNull?.name ?? l10n.qrScanEventFallback;

    return Scaffold(
      backgroundColor: AppColors.discoBlack,
      appBar: AppBar(
        title: Text(l10n.qrScannerTitle),
        actions: [
          if (_cameraStatus == _CameraStatus.granted)
            IconButton(
              tooltip: _torchOn ? l10n.qrTorchOff : l10n.qrTorchOn,
              icon: Icon(
                _torchOn ? Icons.flash_on : Icons.flash_off,
                color: AppColors.white,
              ),
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
        return const VLoadingView();
      case _CameraStatus.unavailable:
        return VEmptyView(
          icon: Icons.no_photography_outlined,
          title: l10n.qrCameraUnavailable,
          description: l10n.qrCameraUnavailableBody,
          actionLabel: l10n.commonRetry,
          onAction: _requestCamera,
        );
      case _CameraStatus.denied:
        return VEmptyView(
          icon: Icons.photo_camera_outlined,
          title: l10n.qrCameraDenied,
          actionLabel: l10n.commonRetry,
          onAction: _requestCamera,
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
                    errorBuilder: (context, error) => _cameraError(l10n),
                  ),
            // Scan frame + cyan scan line (QRSC overlay spec, LUXE restyle).
            const IgnorePointer(child: Center(child: _ScanOverlay())),
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
    return QrScannerScreen.cameraErrorPanel(l10n, _requestCamera);
  }

  Widget _resultBanner(AppLocalizations l10n, _ScanResult result) {
    return Positioned(
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      bottom: AppSpacing.xxxl,
      child: switch (result) {
        _Processing() => Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const VSpinner(size: 16),
                const SizedBox(width: AppSpacing.md),
                Text(
                  l10n.qrScanProcessing,
                  style: const TextStyle(color: AppColors.white),
                ),
              ],
            ),
          ),
        _Confirmed(attendeeName: final name) => Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // LUXE: the confirmation mark uses the family (cyan) vivid
                // end — the legacy pink is gone (2026-08-12 directive).
                const Icon(Icons.check_circle,
                    size: 48, color: AppColors.discoCyan),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.qrScanConfirmed,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (name != null && name.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.qrScanAttendee(name),
                    style: const TextStyle(color: AppColors.mutedStrong),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.qrScanReady,
                  style: const TextStyle(color: AppColors.mutedStrong),
                ),
              ],
            ),
          ),
        _ScanError(message: final message, retryable: final retryable) =>
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border.all(color: AppColors.hairline),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  textAlign: TextAlign.center,
                  // Error semantics keep the pink alias through
                  // AppColors.error (NO PINK MAINS exempts error text).
                  style: const TextStyle(
                    color: AppColors.error,
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
                    gradient: _family,
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

/// Scan-frame overlay (QRSC: white outline, corner brackets) + the **cyan
/// gradient scan line** sweeping top→bottom on the idle-safe engine (one
/// 2.4s sweep then a [SamayDurations.motionCycleRest] settle, so
/// `pumpAndSettle`-based tests land deterministically). Reduced motion →
/// static line at the frame's vertical center.
class _ScanOverlay extends StatefulWidget {
  const _ScanOverlay();

  @override
  State<_ScanOverlay> createState() => _ScanOverlayState();
}

class _ScanOverlayState extends State<_ScanOverlay>
    with SingleTickerProviderStateMixin {
  /// One sweep leg (0 → 1 across the frame height).
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  );

  Timer? _cycleTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.disableAnimationsOf(context);
    if (reduced) {
      _cycleTimer?.cancel();
      _cycleTimer = null;
      _sweep.stop();
      _sweep.value = 0.5; // static center line
    } else if (_cycleTimer == null) {
      _cycleTimer = Timer.periodic(_cyclePeriod, (_) {
        if (!_sweep.isAnimating) {
          _sweep.forward(from: 0).then((_) {
            if (mounted && !MediaQuery.disableAnimationsOf(context)) {
              _sweep.value = 0;
            }
          });
        }
      });
      if (!_sweep.isAnimating) {
        _sweep.forward(from: 0).then((_) {
          if (mounted && !MediaQuery.disableAnimationsOf(context)) {
            _sweep.value = 0;
          }
        });
      }
    }
  }

  Duration get _cyclePeriod =>
      const Duration(milliseconds: 2400) + SamayDurations.motionCycleRest;

  @override
  void dispose() {
    _cycleTimer?.cancel();
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 280,
      height: 280,
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, _) => CustomPaint(
          painter: _ScanFramePainter(progress: _sweep.value),
        ),
      ),
    );
  }
}

/// White scan-frame guide (QRSC: white outline, corner brackets) with the
/// family **cyan gradient** scan line at [progress] (0 → top edge, 1 →
/// bottom edge). The line is the only moving part; the frame is static white.
class _ScanFramePainter extends CustomPainter {
  const _ScanFramePainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = AppColors.white;
    const corner = 40.0;
    final r = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawPath(_cornerPath(r, corner), frame);

    // Cyan gradient scan line (LUXE directive #2: gradient accents only).
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..shader = _family.linear().createShader(
            Rect.fromLTWH(0, 0, size.width, 2),
          );
    final inset = corner * 0.9;
    final y = inset + (size.height - 2 * inset) * progress;
    canvas.drawLine(Offset(inset, y), Offset(size.width - inset, y), linePaint);
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
  bool shouldRepaint(_ScanFramePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
