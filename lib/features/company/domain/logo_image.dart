import 'dart:typed_data';

/// Checks for company logo files: the `company-logos` bucket takes PNG,
/// JPEG or WebP up to 5 MB.
abstract final class LogoImage {
  static const maxBytes = 5 * 1024 * 1024;
  static const extensions = ['png', 'jpg', 'jpeg', 'webp'];

  /// The MIME type from the file's magic bytes, or null if unsupported.
  static String? contentTypeOf(Uint8List bytes) {
    if (_matches(bytes, const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
    if (_matches(bytes, const [0xFF, 0xD8, 0xFF])) return 'image/jpeg';
    if (_matches(bytes, const [0x52, 0x49, 0x46, 0x46]) &&
        _matches(bytes, const [0x57, 0x45, 0x42, 0x50], 8)) {
      return 'image/webp';
    }
    return null;
  }

  static bool _matches(Uint8List bytes, List<int> magic, [int offset = 0]) {
    if (bytes.length < offset + magic.length) return false;
    for (var i = 0; i < magic.length; i++) {
      if (bytes[offset + i] != magic[i]) return false;
    }
    return true;
  }

  /// An error message for an unusable logo, or null if it's fine.
  static String? validate(Uint8List bytes) {
    if (bytes.length > maxBytes) return 'The logo must be 5 MB or smaller.';
    if (contentTypeOf(bytes) == null) {
      return 'Use a PNG, JPEG or WebP image.';
    }
    return null;
  }
}
