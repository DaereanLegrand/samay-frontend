/// OTP input formatting for `otp_verification_screen.dart`: the auto-submit
/// and manual-verify paths both run the entered
/// text through this so pasted/sms-hyphenated codes ('123-456', '123 456')
/// verify as '123456'.
///
/// [OtpVerificationScreen.otpCodeLength] is the canonical cap (6).
String cleanOtpDigits(String input) {
  final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length <= 6 ? digits : digits.substring(0, 6);
}
