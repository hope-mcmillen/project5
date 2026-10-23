import 'package:flutter_riverpod/misc.dart';

import '../core/errors/app_failure.dart';

import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/fake_auth_repository.dart';
import '../features/company/data/company_repository.dart';
import '../features/company/data/fake_company_repository.dart';
import '../features/jobs/data/job_repository.dart';
import '../features/jobs/data/fake_job_repository.dart';
import '../features/board/data/board_repository.dart';
import '../features/board/data/fake_board_repository.dart';

import '../features/profile/data/profile_repository.dart';
import '../features/profile/data/fake_profile_repository.dart';
import '../features/deck/data/feed_repository.dart';
import '../features/deck/data/fake_feed_repository.dart';
import '../features/onboarding/data/resume_repository.dart';
import '../features/onboarding/data/fake_resume_repository.dart';
import '../features/pipeline/data/application_repository.dart';
import '../features/pipeline/data/fake_application_repository.dart';

/// Fresh repositories per provider scope. No backend initialization required.
List<Override> fakeRepositoryOverrides({
  Duration? latency,
  bool simulateParsing = true,
  FakeAuthRepository? auth,
  FakeCompanyRepository? companies,
  FakeJobRepository? jobs,
  FakeBoardRepository? board,
}) {
  final effectiveLatency =
      latency ?? auth?.latency ?? const Duration(milliseconds: 300);
  final fakeAuth = auth ?? FakeAuthRepository(latency: effectiveLatency);
  return [
    authRepositoryProvider.overrideWithValue(fakeAuth),
    companyRepositoryProvider.overrideWithValue(
      companies ??
          FakeCompanyRepository(auth: fakeAuth, latency: fakeAuth.latency),
    ),
    jobRepositoryProvider.overrideWithValue(
      jobs ?? FakeJobRepository(latency: fakeAuth.latency),
    ),
    boardRepositoryProvider.overrideWithValue(
      board ?? FakeBoardRepository(latency: fakeAuth.latency),
    ),
    ...candidateRepositoryOverrides(
      latency: effectiveLatency,
      simulateParsing: simulateParsing,
    ),
  ];
}

List<Override> candidateRepositoryOverrides({
  Duration latency = const Duration(milliseconds: 300),
  bool simulateParsing = true,
  bool includeApplications = true,
}) => [
  profileRepositoryProvider.overrideWith(
    (ref) => FakeProfileRepository(latency: latency),
  ),
  resumeRepositoryProvider.overrideWith((ref) {
    final repository = FakeResumeRepository(
      latency: latency,
      simulateParsing: simulateParsing,
    );
    ref.onDispose(repository.dispose);
    return repository;
  }),
  resumeSimulationProvider.overrideWithValue(true),
  ...feedAndApplicationOverrides(
    latency: latency,
    includeApplications: includeApplications,
  ),
];

/// The deck feed still runs on fakes in the Supabase build: it has no
/// Supabase repository yet. Resume parsing and profiles are real there, and
/// so are applications (C10) when [includeApplications] is false.
List<Override> feedAndApplicationOverrides({
  Duration latency = const Duration(milliseconds: 300),
  bool includeApplications = true,
}) => [
  feedRepositoryProvider.overrideWith((ref) {
    final createdApplications = <String>{};
    return FakeFeedRepository(
      latency: latency,
      preferences: () => ref.read(profileRepositoryProvider).preferences(),
      confirmedProfile: () async =>
          (await ref.read(profileRepositoryProvider).latestVersion())
              ?.confirmed ==
          true,
      onApply: (job) async {
        final version = await ref
            .read(profileRepositoryProvider)
            .latestVersion();
        final applications = ref.read(applicationRepositoryProvider);
        if (!applications.isDemo) {
          throw const AppFailure(
            'demo_job',
            'These are demo jobs. Use the fake-data preview to try applying; live job applications are not connected yet.',
          );
        }
        if (version != null && applications is FakeApplicationRepository) {
          if (applications.recordApplication(job, version.id)) {
            createdApplications.add(job.jobId);
          }
        }
      },
      onUndoApply: (jobId) async {
        final applications = ref.read(applicationRepositoryProvider);
        if (applications is FakeApplicationRepository &&
            createdApplications.remove(jobId)) {
          applications.undoApplication(jobId);
        }
      },
    );
  }),
  if (includeApplications)
    applicationRepositoryProvider.overrideWith((ref) {
      final repository = FakeApplicationRepository(latency: latency);
      ref.onDispose(repository.dispose);
      return repository;
    }),
];
