import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/qr/logic/code.dart';
import 'package:samay/features/qr/providers/code_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';

/// Activation-window minutes (`qr.activation_minutes_before`, seed 30) — the
/// contract used to render the pre-activation countdown.
const int _activationMinutes = 30;

/// Active-state QR geometry (px): no big tile — the QR code sits directly on
/// the black page and is framed by a thin ring whose width is exactly
/// [_qrRingWidth]. The ring is a WHITE track (same path/dimension as the
/// border) drawn first; the BLACK countdown border fills over it empty → full
/// across each window. Sharp corners.
const double _qrWidgetSide = 250;
const double _qrRingWidth = 3;

/// Attendee-side rotating QR attendance code (Stage 5 pivot).
///
/// Shows the attendee's [CodeSession] as a PLAIN QR ([QrImageView]) encoding
/// the current 24-hex code, regenerating every `code.window_seconds` (seed 10)
/// like an authenticator — derived LOCALLY from the per-event secret, so
/// regeneration is seamless and works without a network round-trip. The host/
/// staff scanner reads the QR's payload and validates the code via the
/// `validate_code` RPC. States:
///
/// * **ended** — event status `ended` or past `ends_at`: no code needed.
/// * **notInvited** — caller is neither host/staff nor an invited attendee.
/// * **notInWindow** — before activation (`starts_at - 30 min`): countdown,
///   then re-fetch when the window opens.
/// * **active** — white-module QR on black, framed by a thin ring (white track
///   + black 3px countdown fill over it) that fills to the next code.
///
/// Route: `/qr/:eventId` (feature-flag gated on `AppFeatureFlag.qr`).
///
/// Privacy posture intact: the per-attendee secret is held in memory only and
/// never persisted or logged; only the rotating code string is rendered.
class AttendanceCodeScreen extends ConsumerStatefulWidget {
  const AttendanceCodeScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AttendanceCodeScreen> createState() =>
      _AttendanceCodeScreenState();
}

class _AttendanceCodeScreenState extends ConsumerState<AttendanceCodeScreen> {
  Timer? _ticker;

  /// Active session + the code currently rendered (swapped at window change).
  CodeSession? _session;
  String _code = '';
  int _boundaryMs = 0;
  bool _deriving = false;

  /// Throttle for automatic re-fetches after the activation window opens.
  DateTime _lastRefetch = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    // Re-issue the session on every entry: get_my_code returns the server's
    // CURRENT window (windowSeconds is config), so a stale in-memory session
    // (e.g. fetched while the window was still seeded 30) can no longer keep
    // the first QR frozen for a whole stale window.
    ref.invalidate(myCodeProvider(widget.eventId));
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// One-second heartbeat: at the window boundary, derive + render the next
  /// code seamlessly. The filling border runs its own per-frame ticker.
  void _tick() {
    if (!mounted) return;
    final session = ref.read(myCodeProvider(widget.eventId)).valueOrNull;
    if (session == null || session.session == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final active = _session;
    if (active == null) return;

    final windowMs = active.windowSeconds * 1000;
    if (nowMs >= _boundaryMs) {
      _advanceWindow(nowMs, windowMs);
    }
  }

  /// Crossed a window boundary: derive the next code from the secret (local,
  /// authenticator-style); the QR swaps to the new code on the next build.
  Future<void> _advanceWindow(int nowMs, int windowMs) async {
    if (_deriving) return;
    final session = _session;
    if (session == null) return;
    _deriving = true;
    try {
      final targetCounter = (nowMs ~/ 1000) ~/ session.windowSeconds;
      final nextCode = await session.codeFor(targetCounter);
      if (!mounted) return;
      setState(() {
        _code = nextCode;
        _boundaryMs = (targetCounter + 1) * windowMs;
      });
    } catch (e, st) {
      AppLogger.instance.error('code derive failed: $e', '$st');
    } finally {
      _deriving = false;
    }
  }

  /// Session change seam: (re)anchor the display on a fresh session.
  void _onSessionChange(
    AsyncValue<CodeFetch>? previous,
    AsyncValue<CodeFetch> next,
  ) {
    final session = next.valueOrNull?.session;
    if (session == null || !mounted) return;
    if (session.code == _code && _session != null) return;
    setState(() => _applySession(session));
  }

  /// Anchors the display state on [session] (safe to call without setState
  /// from build for the very first frame).
  void _applySession(CodeSession session) {
    _session = session;
    _code = session.code;
    _boundaryMs = session.windowEnd * 1000;
  }

  /// Re-fetch the code (retry / activation window opening). Throttled when
  /// called from the ticker so a still-closed window is not hammered.
  void _refetch() {
    ref.invalidate(myCodeProvider(widget.eventId));
    _lastRefetch = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myCodeProvider(widget.eventId), _onSessionChange);
    final l10n = AppLocalizations.of(context);
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final fetchAsync = ref.watch(myCodeProvider(widget.eventId));

    return eventAsync.when(
      loading: () => _scaffold(l10n, const VLoadingView()),
      error: (e, _) => _scaffold(
        l10n,
        ErrorView(
          message: l10n.qrEventLoadError,
          onRetry: () => ref.invalidate(eventDetailProvider(widget.eventId)),
        ),
      ),
      data: (event) {
        final now = DateTime.now();
        if (event.status == 'ended' || now.isAfter(event.endsAt)) {
          return _scaffold(
            l10n,
            _MessageState(icon: Icons.event_available, message: l10n.codeEventEnded),
          );
        }
        return fetchAsync.when(
          loading: () => _scaffold(l10n, const VLoadingView()),
          error: (e, _) => _scaffold(
            l10n,
            ErrorView(
              message: l10n.codeLoadError,
              onRetry: _refetch,
            ),
          ),
          data: (fetch) {
            switch (fetch.status) {
              case CodeFetchStatus.ok:
                if (_code.isEmpty) {
                  // First frame after the session resolves: anchor inline
                  // (the ref.listen below would fire post-frame — too late
                  // for this build).
                  _applySession(fetch.session!);
                }
                return _ActiveCode(
                  code: _code,
                  boundaryMs: _boundaryMs,
                  windowSeconds: _session?.windowSeconds ?? 10,
                );
              case CodeFetchStatus.notInvited:
                return _scaffold(
                  l10n,
                  _MessageState(
                    icon: Icons.person_off_outlined,
                    message: l10n.codeNotInvited,
                    action: VButton(
                      label: l10n.commonRetry,
                      onPressed: _refetch,
                    ),
                  ),
                );
              case CodeFetchStatus.notInWindow:
                return _buildNotInWindow(l10n, event.startsAt);
            }
          },
        );
      },
    );
  }

  Widget _buildNotInWindow(AppLocalizations l10n, DateTime startsAt) {
    final activationAt = startsAt.subtract(
      const Duration(minutes: _activationMinutes),
    );
    final now = DateTime.now();
    if (now.isBefore(activationAt)) {
      return _scaffold(
        l10n,
        _MessageState(
          icon: Icons.hourglass_bottom,
          message: l10n.codeNotReadyYet,
          caption: l10n.qrActivationCountdown(_clockString(activationAt.difference(now))),
        ),
      );
    }
    // Inside the presumed window but the server still refuses: auto-refetch
    // (throttled) or the user taps Retry.
    if (DateTime.now().difference(_lastRefetch) > const Duration(seconds: 10)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refetch();
      });
    }
    return _scaffold(
      l10n,
      _MessageState(
        icon: Icons.sync_problem,
        message: l10n.codeServerPending,
        caption: l10n.codeServerPendingBody,
        action: VButton(label: l10n.commonRetry, onPressed: _refetch),
      ),
    );
  }

  Widget _scaffold(AppLocalizations l10n, Widget body) {
    return Scaffold(body: VHeaderBar(child: body));
  }

  /// "HH:MM:SS" countdown string for the activation state.
  static String _clockString(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

/// Active state: the rotating 24-hex code as a white-module QR on the black
/// page, framed by a 3px ring (white track + black countdown fill) that FILLS
/// over the window — the only timing feedback to the next code.
///
/// Full-bleed black scaffold: the QR is centered on the WHOLE screen (the
/// floating back arrow is the only header), so vertical centering ignores any
/// header band.
class _ActiveCode extends StatelessWidget {
  const _ActiveCode({
    required this.code,
    required this.boundaryMs,
    required this.windowSeconds,
  });

  final String code;
  final int boundaryMs;
  final int windowSeconds;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.discoBlack),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: _qrWidgetSide,
                height: _qrWidgetSide,
                child: _CountdownQr(
                  code: code,
                  boundaryMs: boundaryMs,
                  windowSeconds: windowSeconds,
                ),
              ),
            ),
          ),
          const Align(
            alignment: Alignment.topLeft,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  top: VHeaderMetrics.heroTopPad,
                  left: AppSpacing.screenHorizontal,
                ),
                child: SizedBox(
                  height: VHeaderMetrics.titleRowHeight,
                  width: double.infinity,
                  child: VHeaderTitleRow(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The QR code plus its framing ring. A per-frame [Ticker] reads the wall
/// clock against [boundaryMs] so the fill is SILKY (not one 1-s jump per
/// second) and eases in-and-out: slow right after a new code appears and slow
/// as the fill completes, fastest mid-window.
class _CountdownQr extends StatefulWidget {
  const _CountdownQr({
    required this.code,
    required this.boundaryMs,
    required this.windowSeconds,
  });

  final String code;
  final int boundaryMs;
  final int windowSeconds;

  @override
  State<_CountdownQr> createState() => _CountdownQrState();
}

class _CountdownQrState extends State<_CountdownQr>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<double> _progress = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onFrame)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _progress.dispose();
    super.dispose();
  }

  void _onFrame(Duration _) {
    final windowMs = widget.windowSeconds * 1000;
    if (windowMs <= 0) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = nowMs - (widget.boundaryMs - windowMs);
    final elapsed = (elapsedMs / windowMs).clamp(0.0, 1.0);
    // Eased fill (easeInOut on the elapsed fraction): the border starts empty
    // at a fresh code and slows near both the start and the completion.
    final eased = Curves.easeInOutCubic.transform(elapsed);
    if ((eased - _progress.value).abs() > 0.0005) {
      _progress.value = eased;
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrSide = _qrWidgetSide - 2 * _qrRingWidth;
    return SizedBox.square(
      dimension: _qrWidgetSide,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: SizedBox.square(
              dimension: qrSide,
              child: QrImageView(
                data: widget.code,
                version: QrVersions.auto,
                padding: EdgeInsets.zero,
                backgroundColor: Colors.transparent,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.white,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          CustomPaint(painter: _BorderProgressPainter(_progress)),
        ],
      ),
    );
  }
}

/// Frames the QR with a ring of exactly [_qrRingWidth]: a WHITE track drawn
/// along the full path (the QR's only "white padding", same dimension as the
/// border) with the BLACK countdown fill on top — empty at a fresh code →
/// full when it rotates. The fill sweeps COUNTER-clockwise from the top-left
/// corner: left edge → bottom edge → right edge → top edge. [progress] drives
/// the repaint so only this canvas redraws every frame. Sharp corners, no
/// tile.
class _BorderProgressPainter extends CustomPainter {
  _BorderProgressPainter(this.progress) : super(repaint: progress);

  /// Live fill fraction (0 = empty border, 1 = about to rotate).
  final ValueListenable<double> progress;

  /// The ring's perimeter, traced from the TOP-LEFT corner down the left edge,
  /// across the bottom, up the right edge and back along the top (CCW).
  Path _ringPath(Rect rect) {
    return Path()
      ..moveTo(rect.left, rect.top)
      ..lineTo(rect.left, rect.bottom)
      ..lineTo(rect.right, rect.bottom)
      ..lineTo(rect.right, rect.top)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    final path = _ringPath(_ringRect(size));
    final metric = path.computeMetrics().first;

    // White track under the whole ring.
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _qrRingWidth
      ..strokeCap = StrokeCap.butt
      ..color = AppColors.white;
    canvas.drawPath(path, track);

    if (p <= 0) return;
    // Black countdown fill over the track.
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _qrRingWidth
      ..strokeCap = StrokeCap.butt
      ..color = AppColors.discoBlack;
    final drawn = metric.extractPath(0, metric.length * p);
    canvas.drawPath(drawn, fill);
  }

  /// The ring hugs the QR module square: its stroke covers the outer
  /// [_qrRingWidth] band, flush against the modules (no gap, no tile).
  Rect _ringRect(Size size) {
    final inset = _qrRingWidth / 2;
    return Rect.fromLTRB(
      inset,
      inset,
      size.width - inset,
      size.height - inset,
    );
  }

  @override
  bool shouldRepaint(_BorderProgressPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

/// Simple centered message state — monochrome hairline panel + icon.
class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.message,
    this.caption,
    this.action,
  });

  final IconData icon;
  final String message;
  final String? caption;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: AppColors.white),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                if (caption != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    caption!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.mutedStrong),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 320),
                    child: action,
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
