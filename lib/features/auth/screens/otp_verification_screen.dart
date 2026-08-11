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
  Timer? _countdownTimer;
  int _resendSeconds = 0;
  int _failedAttempts = 0;
  bool _attemptBlocked = false;

  @override
  void initState() {
    super.initState();
    // The OTP was just sent before navigating here; start the cooldown.
    _startResendCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
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
    if (_attemptBlocked) return;
    if (cleanOtpDigits(value).length == OtpVerificationScreen.otpCodeLength &&
        !ref.read(authStateProvider).isLoading) {
      _verify();
    }
  }

  Future<void> _verify() async {
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
    // literal into the hardcoded-Spanish scan (see the U-07 log).
    AppLogger.instance.warn('OTP verification failed ($_failedAttempts/${OtpVerificationScreen.maxFailedAttempts}) for ${widget.email}');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final l10n = AppLocalizations.of(context);
    final canResend = _resendSeconds == 0 && !auth.isLoading;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.authVerifyCode)),
      // §7.3: the displayMedium header + otpInputText field grew the column —
      // pin the CTA to the bottom when the content fits, scroll when it
      // doesn't (larger text scales / small screens must never clip).
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 32),
                    // §3.2 auth big header — Playfair Display italic 40 with the glow.
                    Text(
                      l10n.authEnterVerificationCode,
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.authOtpSentTo(widget.email),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 32),
                    TextField(
                      controller: _codeController,
                      maxLength: 6,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      // §3.3 otpInputText token (30/w800/ls8 — was inline 32/ls12;
                      // U-02's handoff). White digits on black per §1 P2.
                      style: AppTypography.otpInputText.copyWith(
                        color: AppColors.white,
                      ),
                      decoration: const InputDecoration(counterText: ''),
                      onChanged: _onCodeChanged,
                    ),
                    if (auth.hasError)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          auth.errorMessage!,
                          // §5.2: glowPink — never raw red on black.
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    // U-14 R2: surface I-29's wrong-attempt budget (Juega's
                    // "N restantes" — the counter appears once a code fails
                    // and shifts to the error color at the last attempt).
                    if (_failedAttempts > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
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
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          l10n.authOtpTooManyAttempts,
                          style: const TextStyle(color: AppColors.error),
                        ),
                      ),
                    const Spacer(),
                    // §5.1 brand moment: the primary CTA is the filled glowAccent.
                    VButton.glowAccent(
                      label: l10n.authVerify,
                      loading: auth.isLoading,
                      filled: true,
                      onPressed: _attemptBlocked ? null : _verify,
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: canResend ? _resend : null,
                      child: Text(
                        _resendSeconds > 0
                            ? l10n.authResendCodeIn(_resendSeconds)
                            : l10n.authResendCode,
                      ),
                    ),
                    // U-14 R1: the funnel's escape hatch — sign out and
                    // return to login (Juega `verify_email_screen.dart:305-308`).
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _backToLogin,
                      child: Text(l10n.authBackToLogin),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
