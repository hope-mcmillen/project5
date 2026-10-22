import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/job_status.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/job.dart';
import '../domain/job_summary.dart';
import '../domain/requirement.dart';
import 'supabase_job_repository.dart';

/// The recruiter's jobs (RC-11). The only jobs code that calls Supabase.
abstract interface class JobRepository {
  /// Every job in the caller's company, from `company_jobs_overview`.
  Future<List<JobSummary>> list();

  Future<Job> get(String id);

  /// Inserts a DRAFT job with [rawDescription] and returns its id.
  Future<String> createDraft(String rawDescription);

  /// Invokes `parse-job`; it also sets `jobs.parse_status`.
  Future<ParseJobResult> parse(String jobId);

  /// The job now, then every update to it (Realtime).
  Stream<Job> watch(String jobId);

  /// The job's saved requirements, required first.
  Future<List<RequirementDraft>> requirements(String jobId);

  /// `rpc('save_requirements')`: replaces the job's requirements.
  Future<void> saveRequirements(String jobId, List<RequirementDraft> items);

  /// Updates the editable job fields (RC-10).
  Future<void> update(String jobId, JobDetailsInput details);

  /// `rpc('set_job_status')`. Throws `invalid_transition` or
  /// `requirements_not_ready`.
  Future<void> setStatus(String id, JobStatus status);

  /// Taxonomy search by name or alias, for "Add skill".
  Future<List<SkillRef>> searchSkills(String query);
}

final jobRepositoryProvider = Provider<JobRepository>(
  (ref) => SupabaseJobRepository(ref.watch(supabaseClientProvider)),
);

/// The company's jobs, for the jobs list. Invalidate after changes.
final jobsProvider = FutureProvider<List<JobSummary>>((ref) async {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) return const [];
  return ref.watch(jobRepositoryProvider).list();
});

/// One job, for the details and requirements screens.
final jobProvider = FutureProvider.family<Job, String>(
  (ref, id) => ref.watch(jobRepositoryProvider).get(id),
);

/// The status changes a recruiter can make from [status] (API_CONTRACT §7.4).
Set<JobStatus> allowedTransitions(JobStatus status) => switch (status) {
  JobStatus.draft => {JobStatus.open},
  JobStatus.open => {JobStatus.paused, JobStatus.closed},
  JobStatus.paused => {JobStatus.open, JobStatus.closed},
  JobStatus.closed => const {},
};
