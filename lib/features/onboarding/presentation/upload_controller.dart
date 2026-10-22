import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/logging/app_log.dart';
import '../data/resume_picker.dart';
import '../data/resume_repository.dart';
import '../domain/resume_file.dart';

enum UploadPhase { idle, choosing, uploading }

class UploadState {
  const UploadState({
    this.file,
    this.phase = UploadPhase.idle,
    this.error,
    this.resumeId,
  });
  final ResumeFile? file;
  final UploadPhase phase;
  final String? error, resumeId;
  bool get busy => phase != UploadPhase.idle;
}

final uploadControllerProvider =
    NotifierProvider.autoDispose<UploadController, UploadState>(
      UploadController.new,
    );

class UploadController extends Notifier<UploadState> {
  int _operation = 0;

  @override
  UploadState build() => const UploadState();

  /// Discard this attempt; a late picker or upload result must not navigate.
  void cancel() {
    _operation++;
    state = const UploadState();
  }

  Future<void> chooseFile() async {
    if (state.busy) return;
    final operation = ++_operation;
    final previous = state.file;
    state = UploadState(file: previous, phase: UploadPhase.choosing);
    try {
      final selected = await ref.read(resumePickerProvider)();
      AppLog.event(
        'resume',
        selected == null ? 'file picker cancelled' : 'file chosen',
        selected == null
            ? null
            : {
                'name': selected.name,
                'type': selected.extension,
                'kb': (selected.bytes.length / 1024).round(),
              },
      );
      if (!ref.mounted || operation != _operation) return;
      state = UploadState(file: selected ?? previous);
    } catch (error) {
      AppLog.warn('resume', 'file rejected', error);
      if (!ref.mounted || operation != _operation) return;
      state = UploadState(
        error: error is AppFailure
            ? error.message
            : 'The file picker could not open. Try choosing a file again.',
      );
    }
  }

  Future<void> upload() async {
    final file = state.file;
    if (file == null || state.busy) return;
    final operation = ++_operation;
    state = UploadState(file: file, phase: UploadPhase.uploading);
    try {
      final resume = await ref
          .read(resumeRepositoryProvider)
          .upload(
            filename: file.name,
            bytes: file.bytes,
            fileHash: file.fileHash,
          );
      if (!ref.mounted || operation != _operation) return;
      state = UploadState(file: file, resumeId: resume.id);
    } catch (error) {
      if (!ref.mounted || operation != _operation) return;
      state = UploadState(
        file: file,
        error: error is AppFailure ? error.message : 'Your resume could not be uploaded. Check your connection and try again.',
      );
    }
  }
}
