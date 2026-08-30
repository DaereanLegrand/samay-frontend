import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/utils/otp_format.dart';
import 'package:samay/l10n/app_localizations.dart';
import 'package:samay/shared/widgets/v_button.dart';
import 'package:samay/shared/widgets/v_display_text.dart';
import 'package:samay/shared/widgets/v_header_bar.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String password;
  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.password,
  });

  /// Client-side cooldown before the user may request a new code (SEC-05/H-23).
  /// Mirrors GoTrue's `email_sent` rate limit (`supabase/config.toml`) so the
  /// user is guided instead of rejected by the server. Deliberately not in
  /// [SamayDurations] — that token set covers *animation* durations.
  static const int resendCooldownSeconds = 60;

  /// Consecutive wrong attempts after which verification is blocked until a
  /// new code is requested (server-side caps are S-10/I-31's scope).
  static const int maxFailedAttempts = 5;

  static const int otpCodeLength = 6;

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _codeController = TextEditingController();
  final FocusNode _codeFocusNode = FocusNode();
  bool _codeFocused = false;
  Timer? _countdownTimer;
  int _resendSeconds = 0;
  int _failedAttempts = 0;
  bool _attemptBlocked = false;

  /// The failure message of THIS attempt, captured right after the awaited
  /// `verifyOtp`. It must NOT mirror the global `authStateProvider` error:
  /// the notifier signs out in its failure path and the `signedOut` listener
  /// rewrites the global provider to `AsyncData` before the next frame, so
  /// the message would be silently lost (2026-08-26 user report). GoTrue
  /// answers every rejected email code with `otp_expired`, so the message is
  /// a single fixed literal — never type-split on server codes.
  String? _verifyError;

  /// Single-shot latch (2026-08-24 fake-OTP-error fix): once a code has been
  /// VERIFIED, no further submit may run. GoTrue answers ANY rejected email
  /// code with `otp_expired` — including one already consumed by the
  /// successful verification — so a duplicate submit (late tap, autofill
  /// event; this screen stays mounted offstage under the pushed routes)
  /// produced a FAKE "código expirado" AND its failure path signed out the
  /// just-created session.
  bool _verified = false;

  @override
  void initState() {
    super.initState();
    // The OTP was just sent before navigating here; start the cooldown.
    _startResendCountdown();
    _codeFocusNode.addListener(_onCodeFocusChange);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeFocusNode.removeListener(_onCodeFocusChange);
    _codeFocusNode.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onCodeFocusChange() {
    final hasFocus = _codeFocusNode.hasFocus;
    if (_codeFocused != hasFocus) {
      setState(() => _codeFocused = hasFocus);
    }
  }

  void _startResendCountdown() {
    _countdownTimer?.cancel();
    _resendSeconds = OtpVerificationScreen.resendCooldownSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_resendSeconds <= 1) {
        _countdownTimer?.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  Future<void> _resend() async {
    await ref.read(authStateProvider.notifier).sendOtp(widget.email);
    if (!mounted) return;
    // A new code grants a fresh attempt budget.
    _startResendCountdown();
    setState(() {
      _failedAttempts = 0;
      _attemptBlocked = false;
      _verifyError = null;
      _codeController.clear();
    });
  }

  /// U-14 R1: the pre-auth funnel's escape hatch (Juega's `_back()` also
  /// clears the transient session). Signs out — clearing any transient OTP
  /// session — and lands on the login screen.
  Future<void> _backToLogin() async {
    await ref.read(authStateProvider.notifier).signOut();
    if (!mounted) return;
    context.go(RoutePaths.login);
  }

  int get _remainingAttempts =>
      OtpVerificationScreen.maxFailedAttempts - _failedAttempts;

  void _onCodeChanged(String value) {
    if (_verified || _attemptBlocked) return;
    if (value.isNotEmpty && _verifyError != null) {
      setState(() => _verifyError = null);
    }
    if (cleanOtpDigits(value).length == OtpVerificationScreen.otpCodeLength &&
        !ref.read(authStateProvider).isLoading) {
      _verify();
    }
  }

  /// The 6-digit code field as a liquid-glass slab. Resting: 1px white α0.25
  /// ring on `surfaceAlt` α0.5 fill with the neumorphic top highlight — the
  /// shared [VInput] recipe. Focused: the ring brightens to solid white
  /// (monochrome 2026-08-26 — the gold gradient ring + halo are gone).
  Widget _codeField() {
    // ANIM-OFF (2026-08-14): zero-duration under reduced motion — the glass
    // ring swaps instantly instead of animating.
    final shellDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return AnimatedContainer(
      key: const ValueKey('otpGlassShell'),
      duration: shellDuration,
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _codeFocused
              ? [
                  AppColors.white.withValues(alpha: 1),
                  AppColors.white.withValues(alpha: 1),
                ]
              : [
                  AppColors.white.withValues(alpha: 0.25),
                  AppColors.white.withValues(alpha: 0.25),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(1),
      child: AnimatedContainer(
        duration: shellDuration,
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(15),
        ),
        // Neumorphic top highlight: a hairline of light falling on the rim.
        foregroundDecoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.white.withValues(alpha: 0.04),
              AppColors.white.withValues(alpha: 0.0),
            ],
            stops: const [0.0, 0.4],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        child: TextField(
          controller: _codeController,
          focusNode: _codeFocusNode,
          maxLength: OtpVerificationScreen.otpCodeLength,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          // §3.3 otpInputText token (30/w800/ls8 — was inline 32/ls12;
          // U-02's handoff). White digits on black per §1 P2.
          style: AppTypography.otpInputText.copyWith(color: AppColors.white),
          decoration: const InputDecoration(
            counterText: '',
            // The glass shell draws the border — no decoration border.
            border: InputBorder.none,
            filled: false,
          ),
          onChanged: _onCodeChanged,
        ),
      ),
    );
  }

  Future<void> _verify() async {
    if (_verified) return;
    final auth = ref.read(authStateProvider);
    final code = cleanOtpDigits(_codeController.text);
    if (auth.isLoading ||
        code.length != OtpVerificationScreen.otpCodeLength ||
        _attemptBlocked) {
      return;
    }
    final l10n = AppLocalizations.of(context);
    await ref
        .read(authStateProvider.notifier)
        .verifyOtp(widget.email, code, widget.password);
    if (!mounted) return;
    if (ref.read(authStateProvider).hasError) {
      // Capture the failure NOW: the notifier's failure path signs out and
      // the signedOut listener rewrites the global provider before the next
      // frame, so reading `authStateProvider.errorMessage` at build time is
      // unreliable. Render the fixed single message (the server returns
      // `otp_expired` for every rejected code).
      setState(() => _verifyError = l10n.errorsOtpInvalid);
      _registerFailedAttempt();
      return;
    }
    if (ref.read(authStateProvider).valueOrNull?.authenticated != true) {
      return;
    }
    final authState = ref.read(authStateProvider).valueOrNull;
    if (authState?.hasProfile == true) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(l10n.authEmailAlreadyRegistered),
          content: Text(l10n.authEmailAlreadyRegisteredBody),
          actions: [
            TextButton(
              onPressed: () {
                ref.read(authStateProvider.notifier).signOut();
                Navigator.pop(context);
              },
              child: Text(l10n.commonOk),
            ),
          ],
        ),
      );
      return;
    }
    // Verified: latch + consume the field BEFORE navigating so no queued
    // submit can re-send the now-consumed code.
    setState(() {
      _verified = true;
      _codeController.clear();
    });
    context.push(RoutePaths.ageGate, extra: AgeGateExtra(email: widget.email));
  }

  void _registerFailedAttempt() {
    setState(() {
      _failedAttempts++;
      _codeController.clear();
      if (_failedAttempts >= OtpVerificationScreen.maxFailedAttempts) {
        _attemptBlocked = true;
      }
    });
    // Kept on one line on purpose: the I-15 l10n guard skips `AppLogger`
    // lines by substring, so a formatted multi-line call would leak the
    // literal into the hardcoded-Spanish scan (see the U-07 log). Also a
    // log message, not UI text — never localize, never split.
    // ignore: avoid_escaping_inner_quotes
    AppLogger.instance.warn('OTP verification failed ($_failedAttempts/${OtpVerificationScreen.maxFailedAttempts}) for ${widget.email}');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final l10n = AppLocalizations.of(context);
    final canResend = _resendSeconds == 0 && !auth.isLoading;

    return Scaffold(
      body: VHeaderBar(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 32),
                      // §3.2 auth big header — monochrome VDisplayText.
                      VDisplayText(text: l10n.authEnterVerificationCode),
                      const SizedBox(height: 8),
                      Text(
                        l10n.authOtpSentTo(widget.email),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      // XL-16 (03_signup density verdict): hint → field
                      // breathes at 40.
                      const SizedBox(height: 40),
                      // The 6-digit code field is the star — a liquid-glass
                      // slab whose 1px border ring brightens to solid white on
                      // focus (monochrome). The digits keep the §3.3
                      // otpInputText voice (30/w800/ls8, white).
                      _codeField(),
                      // The failure message of THIS verify attempt (captured
                      // post-await — the global auth provider is unreliable
                      // here, see `_verifyError`). §5.2: glowPink — never raw
                      // red on black.
                      if (_verifyError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            _verifyError!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      // U-14 R2: surface I-29's wrong-attempt budget. XL-18
                      // (Gemma 04_otp "pedestrian form" — remove helper
                      // duplication): the counter appears ONLY near the limit
                      // (remaining ≤ 2) — early failures read through the
                      // error text alone; the blocked state owns the last
                      // word. Shifts to the error color at the last attempt.
                      if (_failedAttempts > 0 &&
                          _remainingAttempts <= 2 &&
                          _remainingAttempts > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            l10n.authOtpAttemptsRemaining(_remainingAttempts),
                            // §2.4 AA text (mutedStrong) normally; §5.2
                            // glowPink at ≤ 1 attempt left.
                            style: TextStyle(
                              color: _remainingAttempts <= 1
                                  ? AppColors.error
                                  : AppColors.mutedStrong,
                            ),
                          ),
                        ),
                      if (_attemptBlocked)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            l10n.authOtpTooManyAttempts,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      const Spacer(),
                      // §5.1 primary CTA — the black button voice
                      // (user directive 2026-08-14).
                      VButton.dark(
                        label: l10n.authVerify,
                        loading: auth.isLoading,
                        onPressed: _attemptBlocked ? null : _verify,
                      ),
                      const SizedBox(height: 8),
                      // XL-16: secondary links are plain + muted so the CTA
                      // dominates the bottom edge.
                      TextButton(
                        onPressed: canResend ? _resend : null,
                        child: Text(
                          _resendSeconds > 0
                              ? l10n.authResendCodeIn(_resendSeconds)
                              : l10n.authResendCode,
                          style: const TextStyle(color: AppColors.mutedStrong),
                        ),
                      ),
                      // U-14 R1: the funnel's escape hatch — sign out and
                      // return to login (Juega `verify_email_screen.dart:305-308`).
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _backToLogin,
                        child: Text(
                          l10n.authBackToLogin,
                          style: const TextStyle(color: AppColors.mutedStrong),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
