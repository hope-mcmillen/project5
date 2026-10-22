import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../domain/resume_file.dart';

typedef ResumePicker = Future<ResumeFile?> Function();

/// file_picker 13 reads bytes explicitly on every platform, including web.
final resumePickerProvider = Provider<ResumePicker>(
  (ref) => () async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose your resume',
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
    );
    if (file == null) return null;
    ResumeFile.validateMetadata(file.name, file.lengthSync());
    try {
      // Bound reads even when the native provider cannot report a file size.
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in file.readAsByteStream()) {
        if (chunk.isEmpty) continue;
        ResumeFile.validateMetadata(file.name, bytes.length + chunk.length);
        bytes.add(chunk);
      }
      return ResumeFile.fromBytes(name: file.name, bytes: bytes.takeBytes());
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        'file_read_failed',
        'We could not read that file. Try choosing it again.',
      );
    }
  },
);
