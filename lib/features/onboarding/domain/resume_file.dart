import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/errors/app_failure.dart';

/// Validated, immutable upload payload. Extension and content must agree.
class ResumeFile {
  ResumeFile._(this.name, this.bytes, this.fileHash, this.extension);
  static const maxBytes = 5 * 1024 * 1024;
  final String name;
  final Uint8List bytes;
  final String fileHash;
  final String extension;

  static void validateMetadata(String name, int? size) {
    final extension = name.split('.').last.toLowerCase();
    if (!name.contains('.') || !{'pdf', 'docx'}.contains(extension)) {
      throw const AppFailure('invalid_type', 'Choose a PDF or DOCX resume.');
    }
    if (size != null && size > maxBytes) {
      throw const AppFailure(
        'file_too_large',
        'This file is over 5 MB. Choose a smaller resume.',
      );
    }
    if (size == 0) {
      throw const AppFailure(
        'empty_file',
        'This file is empty. Choose another resume.',
      );
    }
  }

  factory ResumeFile.fromBytes({
    required String name,
    required Uint8List bytes,
  }) {
    validateMetadata(name, bytes.length);
    final extension = name.split('.').last.toLowerCase();
    final header = extension == 'pdf'
        ? [0x25, 0x50, 0x44, 0x46]
        : [0x50, 0x4b, 0x03, 0x04];
    if (bytes.length < header.length ||
        List.generate(
          header.length,
          (i) => bytes[i] == header[i],
        ).contains(false)) {
      throw const AppFailure(
        'invalid_content',
        'The file contents do not match its type. Choose a valid PDF or DOCX.',
      );
    }
    final snapshot = Uint8List.fromList(bytes).asUnmodifiableView();
    return ResumeFile._(
      name,
      snapshot,
      sha256.convert(snapshot).toString(),
      extension,
    );
  }
}
