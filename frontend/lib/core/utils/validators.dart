// Shared input checks, so sign-up, login, forgot password and Edit profile
// all accept and reject exactly the same things.

final _emailPattern = RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9\-]+(\.[A-Za-z0-9\-]+)*\.[A-Za-z]{2,}$');
final _mobilePattern = RegExp(r'^\d{10}$');

/// Null when [value] looks like a real email (name@gmail.com, name@yahoo.com…),
/// otherwise a message to show the user.
String? emailError(String value) {
  final email = value.trim();
  if (email.isEmpty) return 'Please enter your email.';
  if (!_emailPattern.hasMatch(email) || email.contains('..')) {
    return 'Please enter a valid email, e.g. name@gmail.com';
  }
  return null;
}

/// Null when [value] is a 10-digit mobile number (e.g. 98XXXXXXXX),
/// otherwise a message to show the user.
String? mobileError(String value) {
  final digits = value.replaceAll(RegExp(r'[\s-]'), '');
  if (digits.isEmpty) return 'Please enter your mobile number.';
  if (!_mobilePattern.hasMatch(digits)) return 'Mobile number must be exactly 10 digits.';
  return null;
}
