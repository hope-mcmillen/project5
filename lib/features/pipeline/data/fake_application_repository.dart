import 'dart:async';

import '../../../core/errors/app_failure.dart';
import '../../../core/models/candidate_models.dart';
import '../../../core/testing/candidate_fixtures.dart';
import '../../../core/testing/fake_repository.dart';
import 'application_repository.dart';
import '../domain/interview_contact.dart';

class FakeApplicationRepository extends FakeRepository
    implements ApplicationRepository {
  FakeApplicationRepository({super.latency, List<Application>? applications})
    : _applications = List.of(applications ?? CandidateFixtures.applications);
  final List<Application> _applications;
  final List<StatusEvent> _events = [];
  final _updates = StreamController<List<Application>>.broadcast(sync: true);
  int _sequence = 0;
  @override
  bool get isDemo => true;
  void setStatus(String id, ApplicationStatus status) {
    final index = _applications.indexWhere((a) => a.id == id);
    if (index < 0) throw const AppFailure('not_found');
    final old = _applications[index];
    final now = DateTime.now().toUtc();
    _applications[index] = Application.fromJson({
      ...old.toJson(),
      'status': status.db,
      'updated_at': now.toIso8601String(),
    });
    _events.add(
      StatusEvent(
        id: _events.length + 1,
        applicationId: id,
        fromStatus: old.status,
        toStatus: status,
        createdAt: now,
      ),
    );
    _updates.add(_snapshot);
  }

  @override
  Future<InterviewContact> contact(String id) async {
    final application = await get(id);
    if (application.status != ApplicationStatus.interviewRequested ||
        DateTime.now().toUtc().isBefore(application.committedAt)) {
      throw const AppFailure(
        'contact_not_available',
        'Contact details are only available for interview invitations.',
      );
    }
    return const InterviewContact(
      name: 'Demo Recruiter',
      email: 'recruiter@rhombus.example.test',
      note: 'Please email a few times that work for an interview.',
    );
  }

  void undoApplication(String jobId) {
    final ids = _applications
        .where((a) => a.jobId == jobId)
        .map((a) => a.id)
        .toSet();
    _applications.removeWhere((a) => ids.contains(a.id));
    _events.removeWhere((e) => ids.contains(e.applicationId));
    _updates.add(_snapshot);
  }

  bool recordApplication(JobCard job, String versionId) {
    if (_applications.any((a) => a.jobId == job.jobId)) return false;
    final now = DateTime.now().toUtc();
    final application = Application(
      id: 'demo-application-${++_sequence}',
      jobId: job.jobId,
      candidateId: CandidateFixtures.candidateId,
      profileVersionId: versionId,
      status: ApplicationStatus.applied,
      matchScore: job.matchScore,
      breakdown: job.breakdown,
      scoringVersion: 'demo',
      committedAt: now.add(const Duration(seconds: 5)),
      createdAt: now,
      updatedAt: now,
      jobTitle: job.title,
      companyName: job.company.name,
      companyVerified: job.company.verified,
    );
    _applications.insert(0, application);
    _events.add(
      StatusEvent(
        id: _events.length + 1,
        applicationId: application.id,
        toStatus: ApplicationStatus.applied,
        createdAt: now,
        actorId: CandidateFixtures.candidateId,
      ),
    );
    _updates.add(_snapshot);
    return true;
  }

  List<Application> get _snapshot => List.unmodifiable(
    List.of(_applications)..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  @override
  Stream<List<Application>> watchMine() => Stream.multi((sink) {
    final subscription = _updates.stream.listen(
      sink.add,
      onError: sink.addError,
    );
    final failure = failNext;
    failNext = null;
    if (failure != null) {
      sink.addError(failure);
    } else {
      sink.add(_snapshot);
    }
    sink.onCancel = subscription.cancel;
  });
  @override
  Future<Application> get(String id) async {
    await call();
    return _applications.firstWhere(
      (a) => a.id == id,
      orElse: () => throw const AppFailure('not_found'),
    );
  }

  @override
  Future<List<StatusEvent>> statusEvents(String applicationId) async {
    await call();
    return List.unmodifiable(
      _events.where((e) => e.applicationId == applicationId),
    );
  }

  @override
  Future<void> withdraw(String id) async {
    await call();
    final index = _applications.indexWhere((a) => a.id == id);
    if (index < 0) throw const AppFailure('not_found');
    final old = _applications[index];
    if (!{
      ApplicationStatus.applied,
      ApplicationStatus.underReview,
      ApplicationStatus.interviewRequested,
    }.contains(old.status)) {
      throw const AppFailure('invalid_transition');
    }
    final now = DateTime.now().toUtc();
    _applications[index] = Application.fromJson({
      ...old.toJson(),
      'status': 'WITHDRAWN',
      'updated_at': now.toIso8601String(),
    });
    _events.add(
      StatusEvent(
        id: _events.length + 1,
        applicationId: id,
        fromStatus: old.status,
        toStatus: ApplicationStatus.withdrawn,
        actorId: old.candidateId,
        createdAt: now,
      ),
    );
    _updates.add(_snapshot);
  }

  Future<void> dispose() => _updates.close();
}
