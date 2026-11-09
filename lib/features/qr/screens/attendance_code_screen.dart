import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart' show Ticker;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/service_providers.dart';
import 'package:samay/features/events/providers/events_providers.dart';
import 'package:samay/features/qr/logic/code.dart';
import 'package:samay/features/qr/providers/code_providers.dart';
import 'package:samay/features/qr/widgets/attendance_qr_view.dart';
import 'package:samay/features/qr/widgets/attendee_assist_animation.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/error_view.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';
import 'package:samay/shared/widgets/state_views.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show RealtimeChannel;
import 'package:samay/core/theme/app_palette_context.dart';

/// Activation-window minutes (`qr.activation_minutes_before`, seed 30) — the
/// contract used to render the pre-activation countdown.
const int _activationMinutes = 30;

/// Attendee-side rotating QR attendance code (Stage 5 pivot).
///
/// Shows the attendee's [CodeSession] as a PLAIN QR ([AttendanceQrView]) encoding
/// the current 24-hex code, regenerating every `code.window_seconds` (seed 10)
/// like an authenticator — derived LOCALLY from the per-event secret, so
/// regeneration is seamless and works without a network round-trip. The host/
/// staff scanner reads the QR's payload and validates the code via the
/// `validate_code` RPC. States:
///
/// * **ended** — event status `ended` or past `ends_at`: no code needed.
/// * **alreadyAttended** — the caller has been confirmed (host/staff scanner
///   wrote their `event_attendances` row): the terminal "Ya te registraste"
///   state replaces the QR forever. A live false → true flip observed while the
///   QR is on screen plays the assist reveal (the code dissolves in place, then
///   a check mark + "LISTO"/"DONE" condense in as the inverse); opening already
///   assisted renders it directly.
/// * **notInvited** — caller is neither host/staff nor an invited attendee.
/// * **notInWindow** — before activation (`starts_at - 30 min`): countdown,
///   then re-fetch when the window opens.
/// * **active** — white-module QR on black, framed by a thin ring (white track
///   + black 3px countdown fill over it) that fills to the next code.
///
/// **Server-clock anchoring (hardened with a monotonic clock):**
/// devices can drift tens of seconds from the server, so the screen never uses
/// the raw device epoch to pick a window. `get_my_code` returns `serverNowMs`;
/// at apply the screen records the server phase into the window
/// (`serverNowMs - counter * windowMs`) and starts a monotonic [Stopwatch].
/// Rotation and the border ring then advance from that phase plus elapsed
/// monotonic time, so both device clock skew AND mid-session NTP corrections
/// cannot move the code or the border off the server's lattice.
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

  /// This event's `event_attendances` stream while the QR is open and the
  /// caller is NOT yet assisted. The scanner's write lands
  /// here even on a deep-linked `/qr/:eventId` (no detail screen underneath),
  /// so the terminal reveal fires live. RLS (`ea_read_access`) gates delivery;
  /// owned and unsubscribed on dispose AND the moment the caller is assisted.
  RealtimeChannel? _attendanceChannel;
  bool _subscribingAttendance = false;

  /// True once an active code has actually been anchored on this mount — i.e.
  /// the QR was rendered. Gates the assist reveal: a false → true attendance
  /// transition while the QR was on screen animates; opening already assisted
  /// renders the terminal state directly (no replay).
  bool _sawLiveQr = false;

  /// Monotonic clock anchored at the last [_applySession]. After the initial
  /// server-anchored phase, all rotation and border timing comes from this —
  /// never from the device wall clock — so an Android NTP correction mid-
  /// session cannot jump the derived window.
  final Stopwatch _watch = Stopwatch();

  /// Server phase into the current window at anchor time
  /// (`serverNowMs - counter * windowMs`), 0..windowMs exclusive.
  int _phaseMs = 0;

  /// Active session + the code currently rendered (swapped at window change).
  CodeSession? _session;
  String _code = '';
  int _counter = -1;
  bool _advancing = false;
  int _advanceSeq = 0;

  /// Newest counter requested while a derive was in flight; processed once the
  /// in-flight derive completes, so a tick is queued rather than dropped.
  int? _pendingCounter;

  /// Throttle for automatic re-fetches after the activation window opens.
  DateTime _lastRefetch = DateTime.fromMillisecondsSinceEpoch(0);

  /// Milliseconds elapsed into the anchored window on the monotonic clock.
  /// Grows without bound; callers reduce modulo the window length.
  int get _elapsedInWindowMs => _phaseMs + _watch.elapsedMilliseconds;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    // Every open re-reads the authoritative assist state. A notification
    // deep-link lands here WITHOUT the detail screen, so its entry-refresh
    // never runs; and when this screen is pushed over the detail both stay
    // mounted (autoDispose keeps the cached value alive). Invalidating on
    // entry forces the fresh `event_attendances` read either way — never a
    // stale QR. Post-frame: provider writes are illegal during the widget
    // life-cycle.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.invalidate(myAttendanceProvider(widget.eventId));
      _syncAttendanceRealtime();
    });
  }

  @override
  void dispose() {
    _unsubscribeAttendance();
    _ticker?.cancel();
    _watch.stop();
    super.dispose();
  }

  /// Owns the assist seam on THIS screen: while the QR is
  /// mounted and the caller is not yet assisted, stream this event's
  /// `event_attendances` rows and re-read the authoritative own-attendance
  /// value on any change. This is what makes a deep-linked `/qr/:eventId`
  /// (no detail screen underneath) flip live when a host/staff scan confirms
  /// the caller. The same seam the detail already uses; RLS `ea_read_access`
  /// gates delivery. Best-effort — the entry-refresh still covers failure.
  void _syncAttendanceRealtime() {
    if (!mounted) return;
    final attended =
        ref.read(myAttendanceProvider(widget.eventId)).valueOrNull == true;
    if (attended) {
      _unsubscribeAttendance();
      return;
    }
    if (_attendanceChannel != null || _subscribingAttendance) return;
    _subscribingAttendance = true;
    try {
      _attendanceChannel = ref
          .read(realtimeServiceProvider)
          .subscribeToEventAttendances(widget.eventId, (_) {
            if (!mounted) return;
            ref.invalidate(myAttendanceProvider(widget.eventId));
          });
    } catch (e, st) {
      AppLogger.instance.error(
        'attendance realtime subscribe failed: $e',
        '$st',
      );
    } finally {
      _subscribingAttendance = false;
    }
  }

  void _unsubscribeAttendance() {
    _attendanceChannel?.unsubscribe();
    _attendanceChannel = null;
  }

  /// One-second heartbeat: recompute the counter from the monotonic model and
  /// swap the code if it moved. Recomputing (rather than tracking a boundary)
  /// means any late/missed tick self-corrects instantly — authenticator-style.
  /// The filling border runs its own per-frame ticker on the same clock.
  void _tick() {
    if (!mounted) return;
    final session = _session;
    if (session == null) return;
    final counter = _currentCounter(session);
    if (counter != _counter) _advanceTo(counter);
  }

  /// Counter derived from the anchored monotonic position: the server counter
  /// at apply plus the whole windows elapsed since.
  int _currentCounter(CodeSession session) {
    final windowMs = session.windowSeconds * 1000;
    return session.counter + _elapsedInWindowMs ~/ windowMs;
  }

  /// Derives the code for [counter] from the session secret (local,
  /// authenticator-style) and swaps the QR to it. A sequence token guards
  /// against a stale derive landing after a re-anchor; a newer counter
  /// requested mid-derive is queued and processed when the current derive
  /// completes (never silently dropped).
  Future<void> _advanceTo(int counter) async {
    if (_advancing) {
      _pendingCounter = counter;
      return;
    }
    final session = _session;
    if (session == null) return;
    _advancing = true;
    _pendingCounter = null;
    final seq = ++_advanceSeq;
    try {
      var target = counter;
      while (mounted && seq == _advanceSeq) {
        final nextCode = await session.codeFor(target);
        if (!mounted || seq != _advanceSeq) return;
        setState(() {
          _code = nextCode;
          _counter = target;
        });
        final pending = _pendingCounter;
        _pendingCounter = null;
        if (pending == null || pending == target) break;
        target = pending;
      }
    } catch (e, st) {
      AppLogger.instance.error('code derive failed: $e', '$st');
    } finally {
      _advancing = false;
    }
  }

  /// Session change seam: re-anchor whenever the server-issued session moves —
  /// new window boundaries, a config change in window length, OR a fresh
  /// `serverNowMs` (so a re-fetch re-syncs even within the same window).
  void _onSessionChange(
    AsyncValue<CodeFetch>? previous,
    AsyncValue<CodeFetch> next,
  ) {
    final fetch = next.valueOrNull;
    final session = fetch?.session;
    if (session == null || !mounted) return;
    if (session.windowEnd == _session?.windowEnd &&
        session.windowSeconds == _session?.windowSeconds &&
        session.serverNowMs == _session?.serverNowMs) {
      return;
    }
    setState(() => _applySession(session, fetch!.serverOffsetMs));
  }

  /// Anchors the display on [session]: records the server phase into the
  /// window and restarts the monotonic [Stopwatch] at this instant. [offsetMs]
  /// is carried from the fetch contract (serverNowMs - device midpoint);
  /// rotation and border use the monotonic phase, never the device clock.
  /// Bumps the sequence so any derive in flight from a previous session is
  /// discarded.
  void _applySession(CodeSession session, int offsetMs) {
    _session = session;
    _code = session.code;
    _counter = session.counter;
    final windowMs = session.windowSeconds * 1000;
    _phaseMs = session.serverNowMs - session.counter * windowMs;
    _pendingCounter = null;
    _watch
      ..reset()
      ..start();
    _advanceSeq++;
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
    // The assist seam: when this screen's own subscription (or the detail's)
    // flips the own-attendance read, drop the QR stream — the terminal state
    // is authoritative from here on.
    ref.listen(myAttendanceProvider(widget.eventId), (_, _) {
      _syncAttendanceRealtime();
    });
    final l10n = AppLocalizations.of(context);
    final eventAsync = ref.watch(eventDetailProvider(widget.eventId));
    final attendedAsync = ref.watch(myAttendanceProvider(widget.eventId));
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
        // Assisted users get the terminal state instead of a QR. The
        // authoritative own-attendance read gates BEFORE any code resolves,
        // so a code (in flight or cached) can never surface a QR again.
        return attendedAsync.when(
          loading: () => _scaffold(l10n, const VLoadingView()),
          error: (e, _) => _scaffold(
            l10n,
            ErrorView(
              message: l10n.codeLoadError,
              onRetry: () =>
                  ref.invalidate(myAttendanceProvider(widget.eventId)),
            ),
          ),
          data: (attended) {
            if (attended) {
              return AttendeeAssistAnimation(
                code: _code,
                title: l10n.codeAssistedDone,
                // Reveal only when the QR was live on THIS mount; a screen
                // opened already assisted renders the terminal state directly.
                animate: _sawLiveQr,
              );
            }
            return _buildCode(l10n, fetchAsync, event.startsAt);
          },
        );
      },
    );
  }

  Widget _buildCode(
    AppLocalizations l10n,
    AsyncValue<CodeFetch> fetchAsync,
    DateTime startsAt,
  ) {
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
              _applySession(fetch.session!, fetch.serverOffsetMs);
            }
            // A code is now on screen (this branch is only reached while the
            // caller is NOT assisted) — arm the assist reveal for this mount.
            _sawLiveQr = true;
            final windowSeconds = _session?.windowSeconds ?? 10;
            return _ActiveCode(
              code: _code,
              phaseMs: _phaseMs,
              windowSeconds: windowSeconds,
              watch: _watch,
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
            return _buildNotInWindow(l10n, startsAt);
        }
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
    required this.phaseMs,
    required this.windowSeconds,
    required this.watch,
  });

  final String code;

  /// Server phase into the window at anchor time (0..windowMs exclusive).
  final int phaseMs;
  final int windowSeconds;

  /// Monotonic clock anchored at `_applySession` — shared with the rotation so
  /// the border and the QR never disagree.
  final Stopwatch watch;

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
                width: kAttendanceQrSide,
                height: kAttendanceQrSide,
                child: _CountdownQr(
                  code: code,
                  phaseMs: phaseMs,
                  windowSeconds: windowSeconds,
                  watch: watch,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topLeft,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: EdgeInsets.only(
                  top:
                      VHeaderMetrics.headerOuterPad +
                      VHeaderMetrics.heroTopPad(
                        MediaQuery.paddingOf(context).top,
                      ),
                  left: AppSpacing.screenHorizontal,
                ),
                child: const SizedBox(
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

/// The QR code plus its framing ring. A per-frame [Ticker] reads the monotonic
/// [watch] plus the anchored [phaseMs] so the fill is SILKY (not one 1-s jump
/// per second) and eases in-and-out: slow right after a new code appears and
/// slow as the fill completes, fastest mid-window. The border uses the SAME
/// clock as the rotation, so they can never disagree.
class _CountdownQr extends StatefulWidget {
  const _CountdownQr({
    required this.code,
    required this.phaseMs,
    required this.windowSeconds,
    required this.watch,
  });

  final String code;
  final int phaseMs;
  final int windowSeconds;
  final Stopwatch watch;

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
    final elapsedInWindow = widget.phaseMs + widget.watch.elapsedMilliseconds;
    final progress = (elapsedInWindow % windowMs) / windowMs;
    final elapsed = progress.clamp(0.0, 1.0);
    // Eased fill (easeInOut on the elapsed fraction): the border starts empty
    // at a fresh code and slows near both the start and the completion.
    final eased = Curves.easeInOutCubic.transform(elapsed);
    if ((eased - _progress.value).abs() > 0.0005) {
      _progress.value = eased;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: kAttendanceQrSide,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: AttendanceQrView(code: widget.code)),
          CustomPaint(painter: _BorderProgressPainter(_progress)),
        ],
      ),
    );
  }
}

/// Frames the QR with a ring of exactly [kAttendanceQrRingWidth]: a WHITE
/// track drawn along the full path (the QR's only "white padding", same
/// dimension as the border) with the BLACK countdown fill on top — empty at a
/// fresh code → full when it rotates. The fill sweeps COUNTER-clockwise from
/// the top-left corner: left edge → bottom edge → right edge → top edge.
/// [progress] drives the repaint so only this canvas redraws every frame.
/// Sharp corners, no tile.
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
      ..strokeWidth = kAttendanceQrRingWidth
      ..strokeCap = StrokeCap.butt
      ..color = AppColors.white;
    canvas.drawPath(path, track);

    if (p <= 0) return;
    // Black countdown fill over the track.
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = kAttendanceQrRingWidth
      ..strokeCap = StrokeCap.butt
      ..color = AppColors.discoBlack;
    final drawn = metric.extractPath(0, metric.length * p);
    canvas.drawPath(drawn, fill);
  }

  /// The ring hugs the QR module square: its stroke covers the outer
  /// [kAttendanceQrRingWidth] band, flush against the modules (no gap, no tile).
  Rect _ringRect(Size size) {
    final inset = kAttendanceQrRingWidth / 2;
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
            color: context.palette.surface,
            border: Border.all(color: context.palette.hairline),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 48, color: context.palette.foreground),
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
                    style: TextStyle(color: context.palette.mutedForeground),
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
