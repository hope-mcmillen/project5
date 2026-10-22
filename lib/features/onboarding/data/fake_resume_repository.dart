import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/testing/candidate_fixtures.dart';
import '../../../core/testing/fake_repository.dart';
import 'resume_repository.dart';

class FakeResumeRepository extends FakeRepository implements ResumeRepository {
  FakeResumeRepository({
    super.latency,
    this.simulateParsing = false,
    this.stepDuration = const Duration(milliseconds: 900),
  });
  final bool simulateParsing;
  final Duration stepDuration;
  final Map<String, Timer> _timers = {};
  final Map<String, Resume> _resumes = {};
  final _updates = StreamController<Resume>.broadcast(sync: true);
  int _sequence = 0;

  @override
  Future<Resume> upload({
    required String filename,
    required Uint8List bytes,
    String? fileHash,
  }) async {
    await call();
    final extension = filename.split('.').last.toLowerCase();
    if (!{'pdf', 'docx'}.contains(extension) ||
        bytes.isEmpty ||
        bytes.length > 5 * 1024 * 1024) {
      throw const AppFailure(
        'invalid_file',
        'Choose a PDF or DOCX up to 5 MB.',
      );
    }
    final id = 'resume-${++_sequence}';
    final resume = Resume(
      id: id,
      candidateId: CandidateFixtures.candidateId,
      storagePath: '${CandidateFixtures.candidateId}/$id.$extension',
      status: ResumeStatus.uploaded,
      fileHash: fileHash ?? sha256.convert(bytes).toString(),
    );
    _resumes[id] = resume;
    if (simulateParsing) {
      const steps = [
        ResumeStatus.parsingLayout,
        ResumeStatus.extracting,
        ResumeStatus.normalizing,
        ResumeStatus.ready,
      ];
      var index = 0;
      _timers[id] = Timer.periodic(stepDuration, (timer) {
        setStatus(id, steps[index++]);
        if (index == steps.length) timer.cancel();
      });
    }
    return resume;
  }

  /// Explicit control lets previews show every parse state without timers or AI.
  void setStatus(String id, ResumeStatus status, {String? failureReason}) {
    final previous = _resumes[id];
    if (previous == null) throw const AppFailure('not_found');
    final resume = Resume.fromJson({
      ...previous.toJson(),
      'status': status.toDb(),
      'failure_reason': status == ResumeStatus.failed
          ? failureReason ?? 'internal'
          : null,
    });
    _resumes[id] = resume;
    if (status == ResumeStatus.ready || status == ResumeStatus.failed) {
      _timers.remove(id)?.cancel();
    }
    _updates.add(resume);
  }

  @override
  Stream<Resume> watchStatus(String resumeId) => Stream.multi((sink) {
    final subscription = _updates.stream
        .where((r) => r.id == resumeId)
        .listen(sink.add, onError: sink.addError);
    final current = _resumes[resumeId];
    if (current == null) {
      sink.addError(const AppFailure('not_found'));
    } else {
      sink.add(current);
    }
    sink.onCancel = subscription.cancel;
  });
  Future<void> dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    return _updates.close();
  }
}
