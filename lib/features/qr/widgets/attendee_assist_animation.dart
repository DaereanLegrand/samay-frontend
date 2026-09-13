import 'package:flutter/material.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/theme/samay_durations.dart';
import 'package:samay/features/qr/widgets/attendance_qr_view.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

/// Full-bleed terminal state shown the instant the caller's own
/// `event_attendances` row exists (2026-09-10, Task D).
///
/// Played when a false → true attendance flip is observed while the QR is on
/// screen: the QR (and its ring) scales up while fading out, a big WHITE check
/// mark appears where the QR was (the inverse motion, from nothing into place),
/// and the terminal word [title] (es "LISTO"/en "DONE") eases in below — the
/// only text under the check. Every segment eases in AND out
/// (`Curves.easeInOut*`) so each starts and ends slowly. The Regresar button is
/// armed only once the sequence completes, so a mid-animation tap can never
/// fire.
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
    required this.returnLabel,
    required this.onReturn,
    this.animate = true,
  });

  /// Last code the QR screen rendered — drawn while it expands and fades.
  final String code;

  /// Terminal word under the check mark (es "LISTO"/en "DONE") — the only text.
  final String title;

  final String returnLabel;
  final VoidCallback onReturn;

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

  /// QR out: slow at the start AND end while it expands + fades.
  late final Animation<double> _qrOut = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.55, curve: Curves.easeInOutCubic),
  );

  /// Check in: from nothing into place, slow at both ends, with a gentle pop.
  late final Animation<double> _checkScale = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.42, 0.85, curve: Curves.easeInOutBack),
  );

  /// Check opacity — clamped companion (easeInOutBack overshoots past 1).
  late final Animation<double> _checkFade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.42, 0.78, curve: Curves.easeInOutCubic),
  );

  /// Word in: settle into place, slow at both ends.
  late final Animation<double> _textIn = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.62, 1.0, curve: Curves.easeInOutCubic),
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.discoBlack),
          Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _content(),
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

  Widget _content() {
    final qrOpacity = (1.0 - _qrOut.value).clamp(0.0, 1.0);
    final qrScale = 1.0 + 0.35 * _qrOut.value;
    final checkOpacity = _checkFade.value.clamp(0.0, 1.0);
    final checkScale = 0.3 + 0.7 * _checkScale.value;
    final textOpacity = _textIn.value.clamp(0.0, 1.0);
    final done = _controller.value >= 1.0;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              dimension: kAttendanceQrSide,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_qrOut.value < 1.0)
                    Opacity(
                      opacity: qrOpacity,
                      child: Transform.scale(scale: qrScale, child: _qrFrame()),
                    ),
                  Opacity(
                    opacity: checkOpacity,
                    child: Transform.scale(
                      scale: checkScale,
                      child: const Icon(
                        Icons.check,
                        size: kAttendanceQrSide * 0.6,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            Opacity(
              opacity: textOpacity,
              child: Transform.translate(
                offset: Offset(0, AppSpacing.lg * (1.0 - textOpacity)),
                child: VDisplayText(
                  text: widget.title,
                  size: 40,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            IgnorePointer(
              ignoring: !done,
              child: Opacity(
                opacity: textOpacity,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: VButton.outlined(
                    label: widget.returnLabel,
                    onPressed: widget.onReturn,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The QR square with its thin white ring — the same geometry as the live
  /// code, so the expand+fade reads as the QR itself leaving.
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
