import 'package:flutter/material.dart';
import 'package:samay/core/theme/samay_durations.dart';

/// One-shot `fast` (150ms) easeOutCubic fade-in for shell tab switches
/// (DISCO-DESIGN-SYSTEM.md §6.1 "subtle, fast"; promoted from U-17's
/// `_ShellTabFade` — R19, the shell flow alignment).
///
/// Key the instance on the tab index (`VTabFade(key: ValueKey(index), …)`)
/// so every switch restarts the fade from opacity 0. Deliberately NOT an
/// `AnimatedSwitcher`: the switcher keeps the outgoing tab in the tree
/// during the transition, and the go_router nested Navigator carries
/// GlobalKey'd route entries — two live Navigators collide (duplicate
/// GlobalKeys, U-17's documented crash hazard). A fade-in disposes the old
/// tab immediately (Juega's `fadeIn(...)` semantics).
///
/// Reduced motion (`MediaQuery.disableAnimationsOf(context)`) → static child
/// at full opacity, no ticker (§7.5).
class VTabFade extends StatefulWidget {
  final Widget child;

  const VTabFade({super.key, required this.child});

  @override
  State<VTabFade> createState() => _VTabFadeState();
}

class _VTabFadeState extends State<VTabFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SamayDurations.fast,
  );

  /// The fade plays once per mount (a new key restarts it via a fresh
  /// State); dependency changes after completion must not re-fade.
  bool _hasPlayed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 1.0;
      _hasPlayed = true;
    } else if (!_hasPlayed) {
      _controller.forward();
      _hasPlayed = true;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: CurvedAnimation(
        parent: _controller,
        curve: SamayDurations.defaultCurve,
      ),
      child: widget.child,
    );
  }
}
