import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Flow-scoped error state for the auth forms.
///
/// These providers hold ONLY the errors produced by the flow's own action —
/// local field validation plus the server failure captured right after the
/// awaited call. Screens render these, NEVER the global `authStateProvider`
/// error: that AsyncValue outlives individual steps, so mirroring it let a
/// stale/unrelated failure (e.g. an `otp_expired` from a redundant OTP
/// re-verification) surface as a fake red error under "Completa tu perfil"
/// the moment the screen was entered.
///
/// Multiple errors are supported on purpose: the username requirements report
/// every violated rule at once (`username_policy.dart`).

/// Error state of the signup funnel screens (contact, profile setup).
class SignupFormErrors {
  /// Field-level violations of the username requirements (may be multiple).
  final List<String> usernameErrors;

  /// Server-side failure of the flow's own last action (createProfile /
  /// sendOtp), when it failed.
  final String? serverError;

  const SignupFormErrors({
    this.usernameErrors = const [],
    this.serverError,
  });

  /// What the screen renders under the username field: all messages joined
  /// (multi-line), or null when clean.
  String? get displayText {
    final all = <String>[
      ...usernameErrors,
      ?serverError,
    ];
    if (all.isEmpty) return null;
    return all.join('\n');
  }
}

class SignupErrorsNotifier extends Notifier<SignupFormErrors> {
  @override
  SignupFormErrors build() => const SignupFormErrors();

  void setUsernameErrors(List<String> errors) {
    state = SignupFormErrors(
      usernameErrors: List.unmodifiable(errors),
      serverError: state.serverError,
    );
  }

  void setServerError(String? message) {
    state = SignupFormErrors(
      usernameErrors: state.usernameErrors,
      serverError: message,
    );
  }

  void clear() => state = const SignupFormErrors();
}

final signupErrorsProvider =
    NotifierProvider<SignupErrorsNotifier, SignupFormErrors>(
  SignupErrorsNotifier.new,
);

/// Error of the login screen's own last signIn attempt (null when clean or
/// mid-flight). Login-specific so its field never mirrors global auth state.
class LoginErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String message) => state = message;

  void clear() => state = null;
}

final loginErrorProvider = NotifierProvider<LoginErrorNotifier, String?>(
  LoginErrorNotifier.new,
);
