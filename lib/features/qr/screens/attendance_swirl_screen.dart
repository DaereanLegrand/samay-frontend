import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/qr/logic/swirl_code.dart';
import 'package:samay/features/qr/providers/swirl_providers.dart';
import 'package:samay/features/qr/widgets/swirl_pattern_view.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';

/// Activation-window minutes (`qr.activation_minutes_before`, seed 30) — the
/// contract used to render the pre-activation countdown.
const int _activationMinutes = 30;

/// Attendee-side animated swirl attendance code (Stage 4).
///
/// Shows the attendee's [SwirlSession] as an animated swirl encoding the
/// current 24-hex code, regenerating every `swirl.window_seconds` (seed 30)
/// like an authenticator — derived LOCALLY from the per-event secret, so
/// regeneration is seamless and works without a network round-trip. States:
///
/// * **ended** — event status `ended` or past `ends_at`: no code needed.
/// * **notInvited** — caller is neither host/staff nor an invited attendee.
/// * **notInWindow** — before activation (`starts_at - 30 min`): countdown,
///   then re-fetch when the window opens.
/// * **active** — the animated swirl + countdown ring to the next code; the
///   code change is morphed inside the swirl (no hard swap).
///
/// Route: `/qr/:eventId` (feature-flag gated on `AppFeatureFlag.qr`).
class AttendanceSwirlScreen extends ConsumerStatefulWidget {
  const AttendanceSwirlScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AttendanceSwirlScreen> createState() =>
      _AttendanceSwirlScreenState();
}

class _AttendanceSwirlScreenState extends ConsumerState<AttendanceSwirlScreen> {
  Timer? _ticker;

  /// Active session + the code currently rendered (morphed on window change).
  SwirlSession? _session;
  String _code = '';
  int _boundaryMs = 0;
  int _remaining = 0;
  bool _deriving = false;

  /// Throttle for automatic re-fetches after the activation window opens.
  DateTime _lastRefetch = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// One-second heartbeat: drives the countdown ring and, at the window
  /// boundary, derives + renders the next code seamlessly.
  void _tick() {
    if (!mounted) return;
    final session = ref.read(mySwirlSessionProvider(widget.eventId)).valueOrNull;
    if (session == null || session.session == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final active = _session;
    if (active == null) return;

    final windowMs = active.windowSeconds * 1000;
    if (nowMs >= _boundaryMs) {
      _advanceWindow(nowMs, windowMs);
    } else {
      setState(() {
        _remaining = math.max(0, ((_boundaryMs - nowMs) / 1000).ceil());
      });
    }
  }

  /// Crossed a window boundary: derive the next code from the secret (local,
  /// authenticator-style) and hand it to the swirl for a seamless morph.
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
        _remaining = math.max(0, ((_boundaryMs - nowMs) / 1000).ceil());
      });
    } catch (e, st) {
      AppLogger.instance.error('swirl derive failed: $e', '$st');
    } finally {
      _deriving = false;
    }
  }

  /// Session change seam: (re)anchor the display on a fresh session —
  /// window/activation state, countdown to the current window's end.
  void _onSessionChange(
    AsyncValue<SwirlFetch>? previous,
    AsyncValue<SwirlFetch> next,
  ) {
    final session = next.valueOrNull?.session;
    if (session == null || !mounted) return;
    if (session.code == _code && _session != null) return;
    setState(() => _applySession(session));
  }

  /// Anchors the display state on [session] (safe to call without setState
  /// from build for the very first frame).
  void _applySession(SwirlSession session) {
    _session = session;
    _code = session.code;
    _boundaryMs = session.windowEnd * 1000;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    _remaining = math.max(0, ((_boundaryMs - nowMs) / 1000).ceil());
  }

  /// Re-fetch the swirl (retry / activation window opening). Throttled when
  /// called from the ticker so a still-closed window is not hammered.
  void _refetch() {
    ref.invalidate(mySwirlSessionProvider(widget.eventId));
    _lastRefetch = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(mySwirlSessionProvider(widget.eventId), _onSessionChange);
    final l10n = AppLocalizations.of(context);
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final fetchAsync = ref.watch(mySwirlSessionProvider(widget.eventId));

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
            _MessageState(icon: Icons.event_available, message: l10n.swirlEventEnded),
          );
        }
        return fetchAsync.when(
          loading: () => _scaffold(l10n, const VLoadingView()),
          error: (e, _) => _scaffold(
            l10n,
            ErrorView(
              message: l10n.swirlCodeLoadError,
              onRetry: _refetch,
            ),
          ),
          data: (fetch) {
            switch (fetch.status) {
              case SwirlFetchStatus.ok:
                if (_code.isEmpty) {
                  // First frame after the session resolves: anchor inline
                  // (the ref.listen below would fire post-frame — too late
                  // for this build).
                  _applySession(fetch.session!);
                }
                return _scaffold(
                  l10n,
                  _ActiveSwirl(
                    code: _code,
                    remaining: _remaining,
                    displayWindow: _session?.windowSeconds ?? 30,
                    l10n: l10n,
                  ),
                );
              case SwirlFetchStatus.notInvited:
                return _scaffold(
                  l10n,
                  _MessageState(
                    icon: Icons.person_off_outlined,
                    message: l10n.swirlNotInvited,
                    action: VButton(
                      label: l10n.commonRetry,
                      onPressed: _refetch,
                    ),
                  ),
                );
              case SwirlFetchStatus.notInWindow:
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
      final minutes = math.max(1, activationAt.difference(now).inMinutes);
      return _scaffold(
        l10n,
        _MessageState(
          icon: Icons.hourglass_bottom,
          message: l10n.swirlActivatesIn(minutes),
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
        message: l10n.swirlServerPending,
        caption: l10n.swirlServerPendingBody,
        action: VButton(label: l10n.commonRetry, onPressed: _refetch),
      ),
    );
  }

  Widget _scaffold(AppLocalizations l10n, Widget body) {
    return Scaffold(
      body: VHeaderBar(title: l10n.qrAttendanceTitle, child: body),
    );
  }

  /// "HH:MM:SS" countdown string for the activation state.
  static String _clockString(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

/// Active state: the animated swirl encoding the current 24-hex code + the
/// countdown ring to the next code + the hex code as a readout.
class _ActiveSwirl extends StatelessWidget {
  const _ActiveSwirl({
    required this.code,
    required this.remaining,
    required this.displayWindow,
    required this.l10n,
  });

  final String code;
  final int remaining;
  final int displayWindow;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.discoBlack,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.hairline),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 340),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: SwirlPatternView(code: code),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              _CountdownRing(
                remaining: remaining,
                total: displayWindow,
                label: l10n.qrNewCodeIn(remaining),
              ),
              const SizedBox(height: AppSpacing.md),
              SelectableText(
                code,
                style: const TextStyle(
                  color: AppColors.mutedStrong,
                  fontSize: 13,
                  letterSpacing: 3,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.swirlCodeCaption,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.mutedStrong),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Circular progress ring for the window countdown — functional timing
/// feedback (mirrors the pre-Stage-4 QR countdown). The seconds label swaps
/// with a [SamayDurations.fast] crossfade.
class _CountdownRing extends StatelessWidget {
  const _CountdownRing({
    required this.remaining,
    required this.total,
    required this.label,
  });

  final int remaining;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final progress = total <= 0 ? 1.0 : (remaining / total).clamp(0.0, 1.0);
    return SizedBox(
      width: 96,
      height: 96,
      child: CustomPaint(
        painter: _RingPainter(progress: progress),
        child: Center(
          child: AnimatedSwitcher(
            // ANIM-OFF (2026-08-14): zero-duration under reduced motion.
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : SamayDurations.fast,
            transitionBuilder: (child, animation) =>
                FadeTransition(opacity: animation, child: child),
            child: Text(
              label,
              key: ValueKey(remaining),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 4.0;
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide - stroke) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppColors.hairline;
    canvas.drawCircle(center, radius, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppColors.discoCyan;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
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
