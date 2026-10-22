/// Form validators for the auth screens. Return an error message, or null.
abstract final class AuthValidators {
  static final _email = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your email.';
    if (!_email.hasMatch(text)) return 'Enter a valid email address.';
    return null;
  }

  /// New passwords: at least 8 characters (US-01).
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password.';
    if (value.length < 8) return 'Use at least 8 characters.';
    return null;
  }

  /// Sign-in passwords are only checked for presence.
  static String? password(String? value) =>
      value == null || value.isEmpty ? 'Enter your password.' : null;
}
