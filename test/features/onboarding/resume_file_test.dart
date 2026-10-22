import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/features/onboarding/domain/resume_file.dart';

void main() {
  final pdf = Uint8List.fromList('%PDF-1.7\nA resume'.codeUnits);
  test('valid PDF and DOCX have immutable bytes and a content hash', () {
    final picked = ResumeFile.fromBytes(name: 'Resume.PDF', bytes: pdf);
    expect(picked.extension, 'pdf');
    expect(picked.fileHash, sha256.convert(pdf).toString());
    expect(() => picked.bytes[0] = 0, throwsUnsupportedError);
    final docx = ResumeFile.fromBytes(
      name: 'resume.docx',
      bytes: Uint8List.fromList([0x50, 0x4b, 3, 4, 1, 2]),
    );
    expect(docx.extension, 'docx');
  });
  test('file type must agree with its contents', () {
    for (final name in ['resume.txt', 'resume.doc', 'resume', 'resume.docx']) {
      expect(
        () => ResumeFile.fromBytes(name: name, bytes: pdf),
        throwsA(isA<AppFailure>()),
      );
    }
    expect(
      () => ResumeFile.fromBytes(
        name: 'resume.pdf',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(
      () => ResumeFile.fromBytes(name: 'empty.pdf', bytes: Uint8List(0)),
      throwsA(isA<AppFailure>()),
    );
  });
  test('5 MiB limit is checked before reading and after bytes arrive', () {
    expect(
      () => ResumeFile.validateMetadata('resume.pdf', ResumeFile.maxBytes + 1),
      throwsA(isA<AppFailure>()),
    );
    final boundary = Uint8List(ResumeFile.maxBytes)
      ..setRange(0, 4, '%PDF'.codeUnits);
    expect(
      ResumeFile.fromBytes(name: 'resume.pdf', bytes: boundary).bytes.length,
      ResumeFile.maxBytes,
    );
    expect(
      () => ResumeFile.fromBytes(
        name: 'resume.pdf',
        bytes: Uint8List(ResumeFile.maxBytes + 1),
      ),
      throwsA(isA<AppFailure>()),
    );
  });
}
