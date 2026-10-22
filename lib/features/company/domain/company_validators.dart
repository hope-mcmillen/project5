/// Form validators for company onboarding (API_CONTRACT §7.1 limits).
abstract final class CompanyValidators {
  static String? name(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Enter your company\'s name.';
    if (text.length > 120) return 'Keep the name under 120 characters.';
    return null;
  }

  /// Optional; when given, an http(s) URL with a host.
  static String? website(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return null;
    final uri = Uri.tryParse(text);
    final ok =
        uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.contains('.') &&
        text.length <= 2048;
    return ok ? null : 'Enter a full URL, like https://example.com';
  }

  /// Invite codes: 8 characters from the unambiguous alphabet.
  static final _code = RegExp(r'^[A-HJKMNP-Z2-9]{8}$');

  static String? inviteCode(String? value) {
    final text = value?.trim().toUpperCase() ?? '';
    if (text.length != 8) return 'Codes are 8 characters.';
    if (!_code.hasMatch(text)) {
      return 'Codes use letters and digits without I, L, O, 0 or 1.';
    }
    return null;
  }
}
