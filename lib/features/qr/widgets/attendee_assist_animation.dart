import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/features/qr/widgets/attendance_qr_view.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Peak blur (logical px) the QR dissolves into as it fades out; the terminal
/// check/word condense in FROM the same blur. Feature-local animation constant
/// — the single tuneable for the reveal's dissolve depth.
const double kAssistDissolveBlur = 10;

/// Fraction of the reveal spent dissolving the QR out (opacity 1→0, blur
/// 0→[kAssistDissolveBlur]). The terminal content starts condensing in at half
/// of this (see [_revealStart]) so the out/in motions cross-dissolve.
const double _qrOutEnd = 0.7;

/// Where the terminal check + word begin entering — half of [_qrOutEnd], so the
/// in-motion is the exact inverse of the QR's out-motion.
const double _revealStart = _qrOutEnd / 2;

/// Full-bleed terminal state shown the instant the caller's own
/// `event_attendances` row exists (2026-09-10, Task D; reworked 2026-09-11).
///
/// Played when a false → true attendance flip is observed while the QR is on
/// screen. The QR stays pinned exactly where the live code was (no horizontal
/// or vertical shift) and DISSOLVES: opacity 1→0 while blurring out. Halfway
/// through that dissolve the big white check and the terminal word [title]
/// (es "LISTO"/en "DONE") condense in at the QR's own centre as the exact
/// inverse of the dissolve (opacity 0→1, blur [kAssistDissolveBlur]→0). The
/// layout is a Stack mirroring the live screen, so nothing moves, and every
/// segment eases in AND out (`Curves.easeInOutCubic`).
///
/// **Fluidity:** the QR/check/word widgets are built once and passed as the
/// [AnimatedBuilder] `child` — only the cheap `_BlurOpacity` wrappers rebuild
/// per frame — and each is a [RepaintBoundary] so the per-frame blur re-filters
/// a cached raster instead of re-rasterizing the QR.
///
/// With [animate] false (screen opened already assisted) the final state is
/// rendered directly — no replay. OS-level reduced motion
/// (`MediaQuery.disableAnimationsOf`) likewise jumps straight to the final
/// state, matching the repo's motion contract.
class AttendeeAssistAnimation extends StatefulWidget {
  const AttendeeAssistAnimation({
    super.key,
    required this.code,
    required this.title,
    this.animate = true,
  });

  /// Last code the QR screen rendered — drawn while it dissolves.
  final String code;

  /// Terminal word under the check mark (es "LISTO"/en "DONE") — the only text.
  final String title;

  /// True plays the reveal; false renders the final state with no replay.
  final bool animate;

  @override
  State<AttendeeAssistAnimation> createState() =>
      _AttendeeAssistAnimationState();
}

class _AttendeeAssistAnimationState extends State<AttendeeAssistAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SamayDurations.assistReveal,
    value: widget.animate ? 0.0 : 1.0,
  );

  /// QR out: opacity 1→0, blur 0→max, slow at both ends.
  late final Animation<double> _qrOut = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, _qrOutEnd, curve: Curves.easeInOutCubic),
  );

  /// Terminal in: the exact inverse, starting at half the QR dissolve —
  /// opacity 0→1, blur max→0, slow at both ends.
  late final Animation<double> _revealIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(_revealStart, 1.0, curve: Curves.easeInOutCubic),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: no ticker — show the terminal state directly (§7.5).
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1.0;
    } else if (widget.animate &&
        !_controller.isAnimating &&
        _controller.value == 0.0) {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Place the terminal word BELOW the QR without letting it take part
          // in the QR's layout: a Column would centre QR + word together and
          // pull the QR off the live screen-centre position. An independent
          // overlay keeps the QR pinned.
          final wordTop = constraints.maxHeight / 2 +
              kAttendanceQrSide / 2 +
              AppSpacing.xl;
          return Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: AppColors.discoBlack),
              // The QR and the check share ONE square at the live QR's exact
              // screen position (same Center/FittedBox/SizedBox as _ActiveCode).
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: kAttendanceQrSide,
                    height: kAttendanceQrSide,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        _qrDissolve(),
                        _checkCondense(),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: wordTop,
                left: 0,
                right: 0,
                child: _wordCondense(),
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
          );
        },
      ),
    );
  }

  /// The QR square + its thin ring, dissolving: opacity 1→0 and blur 0→max.
  /// The frame is a stable [AnimatedBuilder] child so the QR is built once.
  Widget _qrDissolve() {
    return AnimatedBuilder(
      animation: _controller,
      child: RepaintBoundary(child: _qrFrame()),
      builder: (context, child) {
        final t = _qrOut.value;
        if (t >= 1.0) return const SizedBox.shrink();
        return _BlurOpacity(
          opacity: (1.0 - t).clamp(0.0, 1.0),
          blur: kAssistDissolveBlur * t,
          child: child!,
        );
      },
    );
  }

  /// The big check condensing in at the QR's exact place: opacity 0→1 and blur
  /// max→0 (the inverse of [_qrDissolve]). Built once, filtered per frame.
  Widget _checkCondense() {
    return AnimatedBuilder(
      animation: _controller,
      child: const RepaintBoundary(
        child: Icon(
          Icons.check,
          size: kAttendanceQrSide * 0.6,
          color: AppColors.white,
        ),
      ),
      builder: (context, child) {
        final t = _revealIn.value;
        return _BlurOpacity(
          opacity: t.clamp(0.0, 1.0),
          blur: kAssistDissolveBlur * (1.0 - t),
          child: child!,
        );
      },
    );
  }

  /// The terminal word under the check, condensing in with the same inverse
  /// motion (no drift). Built once, filtered per frame.
  Widget _wordCondense() {
    return AnimatedBuilder(
      animation: _controller,
      child: RepaintBoundary(
        child: Center(
          child: VDisplayText(
            text: widget.title,
            size: 40,
            textAlign: TextAlign.center,
          ),
        ),
      ),
      builder: (context, child) {
        final t = _revealIn.value;
        return _BlurOpacity(
          opacity: t.clamp(0.0, 1.0),
          blur: kAssistDissolveBlur * (1.0 - t),
          child: child!,
        );
      },
    );
  }

  /// The QR square with its thin white ring — the same geometry as the live
  /// code, so the dissolve reads as the QR itself leaving.
  Widget _qrFrame() {
    return SizedBox.square(
      dimension: kAttendanceQrSide,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(child: AttendanceQrView(code: widget.code)),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.white,
                width: kAttendanceQrRingWidth,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Applies [blur] (via [ImageFiltered]) then [opacity]. Skips the blur layer
/// entirely at zero blur so no unnecessary save-layer is allocated.
class _BlurOpacity extends StatelessWidget {
  const _BlurOpacity({
    required this.opacity,
    required this.blur,
    required this.child,
  });

  final double opacity;
  final double blur;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final blurred = blur > 0.01
        ? ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
            child: child,
          )
        : child;
    return Opacity(opacity: opacity, child: blurred);
  }
}
