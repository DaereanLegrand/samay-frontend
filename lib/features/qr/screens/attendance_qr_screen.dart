import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/qr/providers/qr_providers.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';

/// Activation-window minutes (`qr.activation_minutes_before`, seed 30) — the
/// MVP-spec contract used when app_config is unreachable.
const int _activationMinutes = 30;

/// QRAT — dynamic attendance QR (attendee side).
///
/// Displays the current `event_qr_tokens` row for the user+event and rotates
/// it on the `qr.display_countdown_seconds` client countdown (QRAT §Token
/// Fetch Cycle). States:
///
/// * **inactive** — no token yet and `now < starts_at - 30 min`: "El código
///   QR se activará {X} minutos antes del evento" + countdown to activation.
/// * **serverPending** — inside the activation window but the server holds no
///   token (the EEDG/QEDG `qr-token-manager` Edge Function is not deployed):
///   retryable.
/// * **active** — white-on-black QR + "Nuevo código en: {s}" countdown ring;
///   at 0s the screen re-fetches the current token (rotation contract — the
///   server-side rotate RPC is EEDG/QEDG future work).
/// * **expired** — the row's `expires_at` passed: auto-refetch once, then a
///   retryable expired state.
/// * **ended** — event status `ended` or past `ends_at`: no QR needed.
///
/// Route: `/qr/:eventId` (feature-flag gated on `AppFeatureFlag.qr`).
class AttendanceQrScreen extends ConsumerStatefulWidget {
  const AttendanceQrScreen({super.key, required this.eventId});

  final String eventId;

  @override
  ConsumerState<AttendanceQrScreen> createState() =>
      _AttendanceQrScreenState();
}

class _AttendanceQrScreenState extends ConsumerState<AttendanceQrScreen> {
  Timer? _ticker;
  int _remaining = 0;
  bool _rotating = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tick(),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// One-second heartbeat: drives the countdown ring and the activation
  /// countdown. Rotation triggers when the ring hits 0 (QRAT step 3) OR when
  /// the current token's `expires_at` passes mid-window (the server-side
  /// rotation lagged) — whichever comes first.
  void _tick() {
    if (!mounted) return;
    final token = ref.read(myQrTokenProvider(widget.eventId)).valueOrNull;
    final expiresAt = DateTime.tryParse(token?['expires_at'] as String? ?? '');
    setState(() {
      if (_remaining > 0) _remaining--;
    });
    final serverExpired = expiresAt != null && !DateTime.now().isBefore(expiresAt);
    if ((_remaining <= 0 || serverExpired) && !_rotating) {
      unawaited(_rotate());
    }
  }

  /// Rotation seam: restarts the display window after a token change (initial
  /// load or rotation) — wired via [ref.listen] in [build].
  void _onTokenChange(
    AsyncValue<Map<String, dynamic>?>? previous,
    AsyncValue<Map<String, dynamic>?> next,
  ) {
    final prevToken = previous?.valueOrNull?['token'] as String?;
    final nextToken = next.valueOrNull?['token'] as String?;
    if (prevToken == nextToken) return;
    if (mounted) {
      setState(() {
        _remaining = ref.read(qrDisplayWindowProvider).valueOrNull ?? 15;
      });
    }
  }

  /// Rotation contract (QRAT step 3): at 0s the app requests the current
  /// token again. When the server-side `rotate_token` (QEDG/EEDG Edge
  /// Function) lands, this swaps the re-fetch for the rotate invocation —
  /// see [MyQrTokenNotifier.rotate].
  Future<void> _rotate() async {
    if (_rotating) return;
    _rotating = true;
    try {
      await ref.read(myQrTokenProvider(widget.eventId).notifier).rotate();
    } catch (_) {
      // The failure surfaces through the provider's AsyncError state; the
      // last rendered token stays visible with the countdown restarted.
    } finally {
      // Always restart the display window — even when the refetch returned
      // the SAME row (server rotation not deployed): the client keeps showing
      // the last token the server issued on a fresh cycle instead of
      // hammering the refetch every second.
      _rotating = false;
      if (mounted) {
        setState(() {
          _remaining = ref.read(qrDisplayWindowProvider).valueOrNull ?? 15;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(myQrTokenProvider(widget.eventId), _onTokenChange);
    final l10n = AppLocalizations.of(context);
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final tokenAsync = ref.watch(myQrTokenProvider(widget.eventId));
    final displayWindow = ref.watch(qrDisplayWindowProvider).valueOrNull ?? 15;

    return eventAsync.when(
      loading: () => _scaffold(l10n, const VLoadingView()),
      error: (e, _) => _scaffold(
        l10n,
        ErrorView(
          message: l10n.qrEventLoadError,
          onRetry: () => ref.invalidate(eventDetailProvider(widget.eventId)),
        ),
      ),
      data: (event) => tokenAsync.when(
        loading: () => _scaffold(l10n, const VLoadingView()),
        error: (e, _) => _scaffold(
          l10n,
          ErrorView(
            message: l10n.qrTokenLoadError,
            onRetry: () => ref.invalidate(myQrTokenProvider(widget.eventId)),
          ),
        ),
        data: (token) {
          final now = DateTime.now();
          final status = event['status'] as String? ?? 'upcoming';
          final startsAt = DateTime.tryParse(event['starts_at'] as String? ?? '');
          final endsAt = DateTime.tryParse(event['ends_at'] as String? ?? '');
          final expiresAt = DateTime.tryParse(token?['expires_at'] as String? ?? '');

          if (status == 'ended' || (endsAt != null && now.isAfter(endsAt))) {
            return _scaffold(l10n, _MessageState(
              icon: Icons.event_available,
              message: l10n.qrEventEnded,
            ));
          }
          if (token == null) {
            final activationAt = startsAt?.subtract(
              const Duration(minutes: _activationMinutes),
            );
            if (activationAt != null && now.isBefore(activationAt)) {
              final minutes = math.max(
                1,
                (activationAt.difference(now).inMinutes),
              );
              final hms = _clockString(activationAt.difference(now));
              return _scaffold(
                l10n,
                _MessageState(
                  icon: Icons.hourglass_bottom,
                  message: l10n.qrActivatesIn(minutes),
                  caption: l10n.qrActivationCountdown(hms),
                ),
              );
            }
            // Inside the activation window with no server token: the
            // EEDG/QEDG `qr-token-manager` has not issued one yet.
            return _scaffold(
              l10n,
              _MessageState(
                icon: Icons.qr_code_2,
                message: l10n.qrServerPending,
                caption: l10n.qrServerPendingBody,
                action: VButton(
                  label: l10n.commonRetry,
                  onPressed: _rotating
                      ? null
                      : () => ref.invalidate(myQrTokenProvider(widget.eventId)),
                ),
              ),
            );
          }
          if (expiresAt == null || now.isAfter(expiresAt)) {
            return _scaffold(
              l10n,
              _MessageState(
                icon: Icons.timer_off_outlined,
                message: _rotating ? l10n.qrUpdating : l10n.qrAttendeeExpired,
                caption: l10n.qrAttendeeExpiredBody,
                action: VButton(
                  label: l10n.commonRetry,
                  onPressed: _rotating ? null : _rotate,
                ),
              ),
            );
          }
          return _scaffold(
            l10n,
            _ActiveQr(
              token: token['token'] as String,
              remaining: _remaining,
              displayWindow: displayWindow,
              rotating: _rotating,
              l10n: l10n,
            ),
          );
        },
      ),
    );
  }

  Widget _scaffold(AppLocalizations l10n, Widget body) {
    return Scaffold(
      appBar: AppBar(title: Text(l10n.qrAttendanceTitle)),
      body: SafeArea(child: body),
    );
  }

  /// "HH:MM:SS" countdown string for the activation state.
  static String _clockString(Duration d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
  }
}

/// Active state: white-on-black QR (QRAT: "black background, white QR"),
/// "SAMAY" center overlay, countdown ring with "Nuevo código en: {s}".
class _ActiveQr extends StatelessWidget {
  const _ActiveQr({
    required this.token,
    required this.remaining,
    required this.displayWindow,
    required this.rotating,
    required this.l10n,
  });

  final String token;
  final int remaining;
  final int displayWindow;
  final bool rotating;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.discoBlack,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              QrImageView(
                data: token,
                version: QrVersions.auto,
                size: 280,
                backgroundColor: AppColors.discoBlack,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.white,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.white,
                ),
              ),
              Container(
                color: AppColors.discoBlack,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.xs,
                ),
                child: Text(
                  'SAMAY',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 2,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          _CountdownRing(
            remaining: remaining,
            total: displayWindow,
            label: l10n.qrNewCodeIn(remaining),
          ),
          if (rotating) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(l10n.qrUpdating, style: const TextStyle(color: AppColors.mutedStrong)),
          ],
        ],
      ),
    );
  }
}

/// Circular progress ring for the rotation countdown (white arc on a hairline
/// base, `glowPink` end cap). The seconds label swaps with a
/// [SamayDurations.fast] crossfade.
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
            duration: SamayDurations.fast,
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
      ..color = AppColors.glowPink;
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

/// Simple centered message state for inactive/serverPending/expired/ended.
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.border),
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
                  child: action),
            ],
          ],
        ),
      ),
    );
  }
}
