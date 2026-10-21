import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:samay/core/design_tokens/app_colors.dart';
import 'package:samay/core/design_tokens/app_spacing.dart';
import 'package:samay/core/design_tokens/app_typography.dart';
import 'package:samay/core/logging/app_logger.dart';
import 'package:samay/core/providers/auth_provider.dart';
import 'package:samay/core/router/route_extras.dart';
import 'package:samay/core/router/route_paths.dart';
import 'package:samay/core/theme/samay_durations.dart';
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

  /// Client-side cooldown before the user may request a new code. Mirrors
  /// GoTrue's `email_sent` rate limit (`supabase/config.toml`) so the user is
  /// guided instead of rejected by the server. Deliberately not in
  /// [SamayDurations] — that token set covers *animation* durations.
  static const int resendCooldownSeconds = 60;

  /// Consecutive wrong attempts after which verification is blocked until a
  /// new code is requested.
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
  /// the message would be silently lost. GoTrue answers every rejected email
  /// code with `otp_expired`, so the message is a single fixed literal — never
  /// type-split on server codes.
  String? _verifyError;

  /// Single-shot latch: once a code has been VERIFIED, no further submit may
  /// run. GoTrue answers ANY rejected email
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

  /// The pre-auth funnel's escape hatch (the reference app's `_back()` also clears the
  /// transient session). Signs out — clearing any transient OTP session — and
  /// lands on the login screen.
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

  /// The 6-digit code field as a sharp slab: a resting `border` hairline that
  /// brightens to solid white on focus. Under reduced motion the swap is
  /// instant.
  Widget _codeField() {
    final shellDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : SamayDurations.fast;
    return AnimatedContainer(
      key: const ValueKey('otpGlassShell'),
      duration: shellDuration,
      curve: SamayDurations.defaultCurve,
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border.all(
          color: _codeFocused ? AppColors.white : AppColors.border,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: TextField(
        controller: _codeController,
        focusNode: _codeFocusNode,
        maxLength: OtpVerificationScreen.otpCodeLength,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        style: AppTypography.otpInputText.copyWith(color: AppColors.white),
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          filled: false,
        ),
        onChanged: _onCodeChanged,
      ),
    );
  }

  Future<void> _verify() async {
    if (_verified) return;
    final auth = ref.read(authStateProvider);
    final code = cleanOtpDigits(_codeController.text);
    if (auth.isLoading || _attemptBlocked) return;
    final l10n = AppLocalizations.of(context);
    if (code.length != OtpVerificationScreen.otpCodeLength) {
      // Manual submit with fewer than 6 digits: explain it on the field
      // instead of silently doing nothing.
      setState(() => _verifyError = l10n.authOtpLengthError);
      return;
    }
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
    // Kept on one line on purpose: the l10n guard skips `AppLogger` lines by
    // substring, so a formatted multi-line call would leak the literal into
    // the hardcoded-Spanish scan. Also a log message, not UI text — never
    // localize, never split.
    // ignore: avoid_escaping_inner_quotes
    AppLogger.instance.warn(
      'OTP verification failed ($_failedAttempts/${OtpVerificationScreen.maxFailedAttempts}) for ${widget.email}',
    );
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
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  child: Column(
                    children: [
                      const SizedBox(height: AppSpacing.xxl),
                      VDisplayText(text: l10n.authEnterVerificationCode),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        l10n.authOtpSentTo(widget.email),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.xxl),
                      _codeField(),
                      // The failure message of THIS verify attempt (captured
                      // post-await — the global auth provider is unreliable
                      // here, see `_verifyError`).
                      if (_verifyError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.lg),
                          child: Text(
                            _verifyError!,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      // The counter appears ONLY near the limit (remaining ≤ 2);
                      // the blocked state owns the last word. It shifts to the
                      // error color at the last attempt.
                      if (_failedAttempts > 0 &&
                          _remainingAttempts <= 2 &&
                          _remainingAttempts > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.lg),
                          child: Text(
                            l10n.authOtpAttemptsRemaining(_remainingAttempts),
                            style: TextStyle(
                              color: _remainingAttempts <= 1
                                  ? AppColors.error
                                  : AppColors.mutedStrong,
                            ),
                          ),
                        ),
                      if (_attemptBlocked)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.lg),
                          child: Text(
                            l10n.authOtpTooManyAttempts,
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      const Spacer(),
                      VButton.dark(
                        label: l10n.authVerify,
                        loading: auth.isLoading,
                        onPressed: _attemptBlocked ? null : _verify,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      // Secondary links stay plain + muted so the CTA
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
                      const SizedBox(height: AppSpacing.sm),
                      TextButton(
                        onPressed: _backToLogin,
                        child: Text(
                          l10n.authBackToLogin,
                          style: const TextStyle(color: AppColors.mutedStrong),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxl),
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
