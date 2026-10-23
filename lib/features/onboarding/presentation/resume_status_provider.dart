import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../data/resume_repository.dart';

/// A little longer than parse-resume's own 75 s deadline plus the upload.
final resumeParseTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 90),
);

/// One subscription per screen, with a hard deadline and automatic cleanup.
final resumeStatusProvider = StreamProvider.autoDispose.family<Resume, String>((
  ref,
  id,
) {
  final source = ref.watch(resumeRepositoryProvider).watchStatus(id);
  final controller = StreamController<Resume>();
  StreamSubscription<Resume>? subscription;
  final timer = Timer(ref.watch(resumeParseTimeoutProvider), () {
    controller.addError(
      const AppFailure(
        'parse_timeout',
        'Reading your resume took too long. Try another file or add your skills manually.',
      ),
    );
    subscription?.cancel();
  });
  ref.onDispose(() {
    timer.cancel();
    subscription?.cancel();
    controller.close();
  });
  subscription = source.listen(
    (resume) {
      controller.add(resume);
      if (resume.status == ResumeStatus.ready ||
          resume.status == ResumeStatus.failed) {
        timer.cancel();
      }
    },
    onError: (Object error, StackTrace stack) {
      timer.cancel();
      controller.addError(error, stack);
    },
  );
  return controller.stream;
});
