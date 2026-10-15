import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_role.dart';

class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}

/// Thin wrapper around Supabase Auth. Callers only ever see [ApiException]
/// (translated from Supabase's [AuthException]) so existing `on ApiException
/// catch` blocks in the screens don't need to change.
class AuthApi {
  static GoTrueClient get _auth => Supabase.instance.client.auth;

  /// Runs a Supabase Auth call, turning its [AuthException] into an
  /// [ApiException] with a message that makes sense to the user.
  static Future<T> _run<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on AuthException catch (e) {
      throw ApiException(_friendlyMessage(e));
    }
  }

  static String _friendlyMessage(AuthException e) {
    // Mail delivery failures come back as a 500 whose raw JSON body ends up
    // in `message` (e.g. {"code":"unexpected_failure","message":"Error
    // sending confirmation email"}), so match on the text too.
    if (e.message.contains('Error sending')) {
      return "We couldn't send the verification email. Please try again in a few minutes.";
    }
    switch (e.code) {
      case 'over_email_send_rate_limit':
        return 'Too many emails sent. Please wait a while and try again.';
      case 'over_request_rate_limit':
        return 'Too many attempts. Please wait a minute and try again.';
      case 'email_exists':
      case 'user_already_exists':
        return 'An account with this email already exists. Please log in instead.';
      case 'invalid_credentials':
        return 'Incorrect email or password.';
      case 'email_not_confirmed':
        return 'Please verify your email first. Sign up again to get a new code.';
      case 'otp_expired':
        return 'This code is wrong or has expired. Check the code or tap "Resend code".';
      case 'weak_password':
        return 'Password is too weak. Use at least 8 characters with letters and numbers.';
      case 'same_password':
        return 'New password must be different from your old password.';
      default:
        return e.message;
    }
  }

  /// Creates the (unconfirmed) user and sends the 6-digit signup code, in
  /// one call — Supabase doesn't need a separate "register after OTP" step.
  static Future<void> signUpWithOtp({
    required String email,
    required String password,
    required String fullName,
    required String mobileNumber,
    required UserRole role,
  }) async {
    final response = await _run(() => _auth.signUp(
          email: email,
          password: password,
          data: {'full_name': fullName, 'mobile_number': mobileNumber, 'role': role.apiValue},
        ));
    // For an already-registered email, Supabase pretends sign-up succeeded
    // (so attackers can't probe which emails exist) but sends no code. The
    // tell-tale sign is a user with no identities.
    if (response.user?.identities?.isEmpty ?? false) {
      throw ApiException('An account with this email already exists. Please log in or reset your password.');
    }
  }

  static Future<void> resendSignupOtp(String email) =>
      _run(() => _auth.resend(type: OtpType.signup, email: email));

  /// Confirms the email and signs the user in, in one call.
  static Future<void> verifySignupOtp(String email, String code) =>
      _run(() => _auth.verifyOTP(email: email, token: code, type: OtpType.signup));

  static Future<void> login(String email, String password) =>
      _run(() => _auth.signInWithPassword(email: email, password: password));

  static Future<void> sendPasswordResetOtp(String email) =>
      _run(() => _auth.resetPasswordForEmail(email));

  /// Establishes a recovery-scoped session, which [setNewPassword] then acts on.
  static Future<void> verifyPasswordResetOtp(String email, String code) =>
      _run(() => _auth.verifyOTP(email: email, token: code, type: OtpType.recovery));

  /// Updates the password on the current recovery session, then signs out
  /// so the user lands back on the login screen and signs in fresh.
  static Future<void> setNewPassword(String newPassword) => _run(() async {
        await _auth.updateUser(UserAttributes(password: newPassword));
        await _auth.signOut();
      });
}
