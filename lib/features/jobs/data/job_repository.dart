import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/job_status.dart';
import '../domain/job_summary.dart';
import 'fake_job_repository.dart';

/// The recruiter's jobs (RC-11). D5/D6 add drafts and requirements.
abstract interface class JobRepository {
  /// Every job in the caller's company, from `company_jobs_overview`.
  Future<List<JobSummary>> list();

  Future<JobSummary> get(String id);

  /// `rpc('set_job_status')`. Throws `invalid_transition` or
  /// `requirements_not_ready`.
  Future<void> setStatus(String id, JobStatus status);
}

/// TODO(RC-11): switch the default to `SupabaseJobRepository`.
final jobRepositoryProvider = Provider<JobRepository>(
  (ref) => FakeJobRepository(),
);
