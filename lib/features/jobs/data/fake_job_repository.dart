import '../../../core/errors/app_failure.dart';
import '../../../core/models/job_status.dart';
import '../domain/job_summary.dart';
import 'job_repository.dart';

/// In-memory [JobRepository] with the contract's job id (API_CONTRACT §7.4).
class FakeJobRepository implements JobRepository {
  FakeJobRepository({
    this.latency = const Duration(milliseconds: 300),
    List<JobSummary>? jobs,
  }) : _jobs = jobs ?? List.of(demoJobs);

  static final demoJobs = [
    JobSummary(
      id: '40000000-0000-0000-0000-000000000001',
      companyId: '20000000-0000-0000-0000-000000000001',
      title: 'Flutter Developer',
      status: JobStatus.open,
      publishedAt: DateTime.utc(2026, 10, 20, 14),
      expiresAt: DateTime.utc(2026, 12, 19, 14),
      newCount: 3,
      totalCount: 5,
    ),
    const JobSummary(
      id: '40000000-0000-0000-0000-000000000002',
      companyId: '20000000-0000-0000-0000-000000000001',
      title: 'Backend Engineer',
      status: JobStatus.draft,
    ),
  ];

  /// Allowed job transitions (API_CONTRACT §7.4).
  static const _transitions = {
    JobStatus.draft: {JobStatus.open},
    JobStatus.open: {JobStatus.paused, JobStatus.closed},
    JobStatus.paused: {JobStatus.open, JobStatus.closed},
    JobStatus.closed: <JobStatus>{},
  };

  final Duration latency;

  /// When set, the next call throws this failure instead of running.
  AppFailure? failNext;

  final List<JobSummary> _jobs;

  Future<void> _call() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final failure = failNext;
    if (failure != null) {
      failNext = null;
      throw failure;
    }
  }

  @override
  Future<List<JobSummary>> list() async {
    await _call();
    return List.unmodifiable(_jobs);
  }

  @override
  Future<JobSummary> get(String id) async {
    await _call();
    return _jobs.firstWhere(
      (j) => j.id == id,
      orElse: () => throw const AppFailure('not_found', 'Job not found.'),
    );
  }

  @override
  Future<void> setStatus(String id, JobStatus status) async {
    await _call();
    final index = _jobs.indexWhere((j) => j.id == id);
    if (index == -1) throw const AppFailure('not_owner');
    if (!_transitions[_jobs[index].status]!.contains(status)) {
      throw const AppFailure(
        'invalid_transition',
        'That status change isn\'t allowed.',
      );
    }
    _jobs[index] = _jobs[index].copyWith(status: status);
  }
}
