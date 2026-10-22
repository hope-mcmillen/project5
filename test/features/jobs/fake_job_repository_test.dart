import 'package:flutter_test/flutter_test.dart';
import 'package:project5/core/errors/app_failure.dart';
import 'package:project5/core/models/job_status.dart';
import 'package:project5/features/jobs/data/fake_job_repository.dart';
import 'package:project5/features/jobs/domain/job_summary.dart';

void main() {
  test('parses a company_jobs_overview row', () {
    final job = JobSummary.fromJson(const {
      'id': '40000000-0000-0000-0000-000000000001',
      'company_id': '20000000-0000-0000-0000-000000000001',
      'title': 'Flutter Developer',
      'status': 'PAUSED',
      'published_at': '2026-10-20T14:00:00Z',
      'expires_at': null,
      'new_count': 2,
      'total_count': 7,
    });
    expect(job.status, JobStatus.paused);
    expect(job.newCount, 2);
    expect(job.totalCount, 7);
    expect(job.publishedAt, DateTime.utc(2026, 10, 20, 14));
  });

  test('follows the allowed status transitions', () async {
    final jobs = FakeJobRepository(latency: Duration.zero);
    final open = FakeJobRepository.demoJobs.first.id;

    await jobs.setStatus(open, JobStatus.paused);
    expect((await jobs.get(open)).status, JobStatus.paused);
    await jobs.setStatus(open, JobStatus.closed);
    await expectLater(
      jobs.setStatus(open, JobStatus.open),
      throwsA(
        isA<AppFailure>().having((f) => f.code, 'code', 'invalid_transition'),
      ),
    );
  });

  test('deletes drafts only', () async {
    final jobs = FakeJobRepository(latency: Duration.zero);
    final open = FakeJobRepository.demoJobs.first.id;
    final draft = FakeJobRepository.demoJobs.last.id;
    Matcher fails(String code) =>
        throwsA(isA<AppFailure>().having((f) => f.code, 'code', code));

    await expectLater(jobs.deleteDraft(open), fails('job_not_draft'));
    await jobs.deleteDraft(draft);
    expect((await jobs.list()).map((j) => j.id), [open]);
    await expectLater(jobs.get(draft), fails('job_not_found'));
    await expectLater(jobs.requirements(draft), fails('job_not_found'));
    await expectLater(jobs.deleteDraft(draft), fails('job_not_found'));
  });

  test('enums round-trip their Postgres values', () {
    for (final status in JobStatus.values) {
      expect(JobStatus.fromDb(status.toDb()), status);
    }
  });
}
